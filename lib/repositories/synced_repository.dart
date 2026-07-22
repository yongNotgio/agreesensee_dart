import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/cache/local_cache.dart';

/// Base class implementing the offline-first sync strategy shared by every
/// entity repository.
///
/// * **Live mode** (a [SupabaseClient] is supplied): reads/writes hit Supabase
///   and are mirrored into the [CollectionStore] so the last-known working set
///   survives connectivity loss. If a network call throws, reads fall back to
///   the cached mirror.
/// * **Demo mode** (no client): the [CollectionStore] is the system of record;
///   all CRUD runs against on-device storage seeded at first launch.
///
/// The cache holds the *current accessible working set* (e.g. the signed-in
/// farmer's own rows), which is the correct granularity for an offline-first
/// single-session mobile client.
/// A write the server understood and refused — a missing column, an unknown
/// enum value, a constraint violation.
///
/// Distinct from being offline: there is no point retrying locally, because the
/// row will never be accepted in its current shape. Callers surface this to the
/// user rather than reporting a success that will silently disappear.
class RepositoryWriteException implements Exception {
  const RepositoryWriteException({required this.table, required this.cause});

  final String table;
  final PostgrestException cause;

  /// True when the row references a column or type the database does not have —
  /// almost always a pending migration.
  bool get looksLikeSchemaDrift {
    final code = cause.code ?? '';
    // 42703 undefined_column · 42P01 undefined_table · 22P02 invalid_text_representation
    return code == '42703' || code == '42P01' || code == '22P02';
  }

  String get userMessage => looksLikeSchemaDrift
      ? 'The database is missing an update this version of the app needs '
          '($table). Apply supabase/migrations/002_adviser_revisions.sql, then '
          'try again.'
      : 'The server rejected this change: ${cause.message}';

  @override
  String toString() => 'RepositoryWriteException($table): ${cause.message}';
}

abstract class SyncedRepository<T> {
  SyncedRepository({
    required this.client,
    required CollectionStore<T> store,
    required this.table,
  }) : _store = store;

  final SupabaseClient? client;
  final CollectionStore<T> _store;
  final String table;

  bool get isDemo => client == null;

  Map<String, dynamic> toMap(T item) => _store.toMap(item);
  T fromMap(Map<String, dynamic> map) => _store.fromMap(map);
  String idOf(T item) => _store.idOf(item);

  CollectionStore<T> get store => _store;

  List<T> _localFilter(List<T> items, String? column, Object? equals) {
    if (column == null) return items;
    return items.where((e) => toMap(e)[column] == equals).toList();
  }

  /// Fetch rows, optionally filtered by `column == equals` and ordered.
  Future<List<T>> fetchAll({
    String? column,
    Object? equals,
    String? orderBy,
    bool ascending = false,
  }) async {
    if (isDemo) {
      final items = _localFilter(_store.all(), column, equals);
      return _sortLocal(items, orderBy, ascending);
    }
    try {
      var query = client!.from(table).select();
      if (column != null && equals != null) {
        query = query.eq(column, equals);
      }
      final data = orderBy != null
          ? await query.order(orderBy, ascending: ascending)
          : await query;
      final items = (data as List)
          .map((e) => fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
      await _store.replaceAll(items); // mirror working set for offline use
      return items;
    } on Object {
      // Offline / transient failure → serve last-synced cache.
      final items = _localFilter(_store.all(), column, equals);
      return _sortLocal(items, orderBy, ascending);
    }
  }

  /// Insert or update a row, keeping the local mirror in sync.
  ///
  /// A **network** failure falls back to an optimistic local write, so a farmer
  /// in the field is never blocked. A **server rejection** does not: if Postgres
  /// understood the request and refused it — a missing column, a bad enum value,
  /// a constraint — writing locally and reporting success is a lie. The row
  /// would then be wiped by the next [fetchAll], which mirrors the server over
  /// the cache, and the farmer would watch their work vanish with no
  /// explanation. Those surface as [RepositoryWriteException].
  Future<T> save(T item) async {
    if (isDemo) {
      await _store.upsert(item);
      return item;
    }
    try {
      final data =
          await client!.from(table).upsert(toMap(item)).select().single();
      final saved = fromMap(Map<String, dynamic>.from(data));
      await _store.upsert(saved);
      return saved;
    } on PostgrestException catch (e) {
      throw RepositoryWriteException(table: table, cause: e);
    } on Object {
      // Offline / transient → optimistic local write.
      await _store.upsert(item);
      return item;
    }
  }

  Future<void> remove(String id) async {
    if (isDemo) {
      await _store.delete(id);
      return;
    }
    try {
      await client!.from(table).delete().eq('id', id);
    } on PostgrestException catch (e) {
      // The server refused. Leave the local mirror alone — hiding a row that
      // still exists upstream would make it reappear on the next sync.
      throw RepositoryWriteException(table: table, cause: e);
    } on Object {
      // Offline: fall through to an optimistic local delete.
    }
    await _store.delete(id);
  }

  /// Realtime stream of the table (live mode) or a one-shot snapshot of the
  /// cached working set (demo mode).
  Stream<List<T>> watch({String? column, Object? equals}) {
    if (isDemo) {
      return Stream.value(_localFilter(_store.all(), column, equals));
    }
    final base = client!.from(table).stream(primaryKey: ['id']);
    final Stream<List<Map<String, dynamic>>> rows =
        (column != null && equals != null)
            ? base.eq(column, equals)
            : base;
    return rows.map((event) {
      final items =
          event.map((e) => fromMap(Map<String, dynamic>.from(e))).toList();
      // Best-effort cache refresh from the realtime feed.
      _store.replaceAll(items);
      return items;
    });
  }

  List<T> _sortLocal(List<T> items, String? orderBy, bool ascending) {
    if (orderBy == null) return items;
    Comparable<Object> key(T item) {
      final v = toMap(item)[orderBy];
      if (v is Comparable) return v as Comparable<Object>;
      return (v?.toString() ?? '');
    }

    final sorted = [...items]..sort((a, b) {
        final cmp = Comparable.compare(key(a), key(b));
        return ascending ? cmp : -cmp;
      });
    return sorted;
  }
}

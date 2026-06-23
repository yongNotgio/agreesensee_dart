import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight persistent key/value cache backing the offline-first layer.
///
/// Stores JSON documents in [SharedPreferences]. In **live mode** repositories
/// write Supabase results through here so the last-known state survives loss of
/// connectivity. In **demo mode** this is the system of record — repositories
/// perform full CRUD against it, seeded once on first launch.
class LocalCache {
  LocalCache(this._prefs);

  final SharedPreferences _prefs;

  static const String _prefix = 'agrisense.';

  String _k(String key) => '$_prefix$key';

  /// Read a single JSON object.
  Map<String, dynamic>? readObject(String key) {
    final raw = _prefs.getString(_k(key));
    if (raw == null) return null;
    final decoded = jsonDecode(raw);
    return decoded is Map<String, dynamic> ? decoded : null;
  }

  Future<void> writeObject(String key, Map<String, dynamic> value) =>
      _prefs.setString(_k(key), jsonEncode(value));

  /// Read a JSON array as a list of maps.
  List<Map<String, dynamic>> readList(String key) {
    final raw = _prefs.getString(_k(key));
    if (raw == null) return [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    return decoded
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<void> writeList(String key, List<Map<String, dynamic>> value) =>
      _prefs.setString(_k(key), jsonEncode(value));

  bool has(String key) => _prefs.containsKey(_k(key));

  Future<void> remove(String key) => _prefs.remove(_k(key));

  Future<void> clearAll() async {
    final keys = _prefs.getKeys().where((k) => k.startsWith(_prefix)).toList();
    for (final k in keys) {
      await _prefs.remove(k);
    }
  }
}

/// A typed collection backed by [LocalCache], modeling one Supabase table.
///
/// Used by repositories for the local mirror (live mode) and as the primary
/// store (demo mode). Operations are id-keyed and persisted atomically.
class CollectionStore<T> {
  CollectionStore({
    required this.cache,
    required this.key,
    required this.toMap,
    required this.fromMap,
    required this.idOf,
  });

  final LocalCache cache;
  final String key;
  final Map<String, dynamic> Function(T) toMap;
  final T Function(Map<String, dynamic>) fromMap;
  final String Function(T) idOf;

  List<T> all() => cache.readList(key).map(fromMap).toList();

  List<T> where(bool Function(T) test) => all().where(test).toList();

  T? findById(String id) {
    for (final item in all()) {
      if (idOf(item) == id) return item;
    }
    return null;
  }

  Future<void> replaceAll(List<T> items) =>
      cache.writeList(key, items.map(toMap).toList());

  /// Insert or update a single item by id; returns the persisted collection.
  Future<List<T>> upsert(T item) async {
    final items = all();
    final id = idOf(item);
    final index = items.indexWhere((e) => idOf(e) == id);
    if (index >= 0) {
      items[index] = item;
    } else {
      items.add(item);
    }
    await replaceAll(items);
    return items;
  }

  Future<List<T>> delete(String id) async {
    final items = all()..removeWhere((e) => idOf(e) == id);
    await replaceAll(items);
    return items;
  }

  bool get isSeeded => cache.has(key);

  Future<void> seedIfEmpty(List<T> items) async {
    if (!isSeeded) await replaceAll(items);
  }
}

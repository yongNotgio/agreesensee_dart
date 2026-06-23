import '../core/cache/local_cache.dart';
import '../models/calamity_report.dart';
import '../models/cooperative.dart';
import '../models/crop_declaration.dart';
import '../models/expense.dart';
import '../models/farm.dart';
import '../models/logbook_entry.dart';
import '../models/production_report.dart';
import 'synced_repository.dart';

/// Farms (`farms` table) owned by farmers.
class FarmRepository extends SyncedRepository<Farm> {
  FarmRepository({required super.client, required LocalCache cache})
      : super(
          table: 'farms',
          store: CollectionStore<Farm>(
            cache: cache,
            key: 'farms',
            toMap: (f) => f.toMap(),
            fromMap: Farm.fromMap,
            idOf: (f) => f.id,
          ),
        );

  Future<List<Farm>> forOwner(String ownerId) =>
      fetchAll(column: 'owner_id', equals: ownerId, orderBy: 'created_at');
}

/// Crop declarations (`crop_declarations` table).
class DeclarationRepository extends SyncedRepository<CropDeclaration> {
  DeclarationRepository({required super.client, required LocalCache cache})
      : super(
          table: 'crop_declarations',
          store: CollectionStore<CropDeclaration>(
            cache: cache,
            key: 'crop_declarations',
            toMap: (d) => d.toMap(),
            fromMap: CropDeclaration.fromMap,
            idOf: (d) => d.id,
          ),
        );

  Future<List<CropDeclaration>> forFarmer(String farmerId) =>
      fetchAll(column: 'farmer_id', equals: farmerId, orderBy: 'created_at');

  /// All active declarations across farmers — used by the cooperative supply
  /// dashboard and the municipal saturation analysis.
  Future<List<CropDeclaration>> all() => fetchAll(orderBy: 'planting_date');

  /// Declarations within a barangay (cooperative scope).
  Future<List<CropDeclaration>> forBarangay(String barangay) =>
      fetchAll(column: 'barangay', equals: barangay, orderBy: 'planting_date');
}

/// Expenses (`expenses` table) feeding the P&L ledger.
class ExpenseRepository extends SyncedRepository<Expense> {
  ExpenseRepository({required super.client, required LocalCache cache})
      : super(
          table: 'expenses',
          store: CollectionStore<Expense>(
            cache: cache,
            key: 'expenses',
            toMap: (e) => e.toMap(),
            fromMap: Expense.fromMap,
            idOf: (e) => e.id,
          ),
        );

  Future<List<Expense>> forDeclaration(String declarationId) => fetchAll(
      column: 'declaration_id', equals: declarationId, orderBy: 'incurred_on');

  Future<List<Expense>> forFarmer(String farmerId) =>
      fetchAll(column: 'farmer_id', equals: farmerId, orderBy: 'incurred_on');
}

/// Production reports (`production_reports` table) — realized harvest results.
class ProductionRepository extends SyncedRepository<ProductionReport> {
  ProductionRepository({required super.client, required LocalCache cache})
      : super(
          table: 'production_reports',
          store: CollectionStore<ProductionReport>(
            cache: cache,
            key: 'production_reports',
            toMap: (p) => p.toMap(),
            fromMap: ProductionReport.fromMap,
            idOf: (p) => p.id,
          ),
        );

  Future<List<ProductionReport>> forFarmer(String farmerId) =>
      fetchAll(column: 'farmer_id', equals: farmerId, orderBy: 'harvested_on');

  Future<ProductionReport?> forDeclaration(String declarationId) async {
    final list =
        await fetchAll(column: 'declaration_id', equals: declarationId);
    return list.isEmpty ? null : list.first;
  }
}

/// Logbook entries (`logbook_entries` table) — agronomic events.
class LogbookRepository extends SyncedRepository<LogbookEntry> {
  LogbookRepository({required super.client, required LocalCache cache})
      : super(
          table: 'logbook_entries',
          store: CollectionStore<LogbookEntry>(
            cache: cache,
            key: 'logbook_entries',
            toMap: (e) => e.toMap(),
            fromMap: LogbookEntry.fromMap,
            idOf: (e) => e.id,
          ),
        );

  Future<List<LogbookEntry>> forFarmer(String farmerId) =>
      fetchAll(column: 'farmer_id', equals: farmerId, orderBy: 'performed_on');
}

/// Calamity reports (`calamity_reports` table) — incident reporting.
class CalamityRepository extends SyncedRepository<CalamityReport> {
  CalamityRepository({required super.client, required LocalCache cache})
      : super(
          table: 'calamity_reports',
          store: CollectionStore<CalamityReport>(
            cache: cache,
            key: 'calamity_reports',
            toMap: (c) => c.toMap(),
            fromMap: CalamityReport.fromMap,
            idOf: (c) => c.id,
          ),
        );

  Future<List<CalamityReport>> forFarmer(String farmerId) =>
      fetchAll(column: 'farmer_id', equals: farmerId, orderBy: 'occurred_on');

  Future<List<CalamityReport>> forBarangay(String barangay) =>
      fetchAll(column: 'barangay', equals: barangay, orderBy: 'occurred_on');
}

/// Cooperatives (`cooperatives` table).
class CooperativeRepository extends SyncedRepository<Cooperative> {
  CooperativeRepository({required super.client, required LocalCache cache})
      : super(
          table: 'cooperatives',
          store: CollectionStore<Cooperative>(
            cache: cache,
            key: 'cooperatives',
            toMap: (c) => c.toMap(),
            fromMap: Cooperative.fromMap,
            idOf: (c) => c.id,
          ),
        );

  Future<Cooperative?> byId(String id) async {
    final list = await fetchAll();
    for (final c in list) {
      if (c.id == id) return c;
    }
    return null;
  }
}

/// Market channels / buy-back programs (`market_channels` table).
class MarketChannelRepository extends SyncedRepository<MarketChannel> {
  MarketChannelRepository({required super.client, required LocalCache cache})
      : super(
          table: 'market_channels',
          store: CollectionStore<MarketChannel>(
            cache: cache,
            key: 'market_channels',
            toMap: (c) => c.toMap(),
            fromMap: MarketChannel.fromMap,
            idOf: (c) => c.id,
          ),
        );

  Future<List<MarketChannel>> forCooperative(String cooperativeId) =>
      fetchAll(column: 'cooperative_id', equals: cooperativeId);
}

import 'package:equatable/equatable.dart';

import '../core/utils/parsing.dart';

/// Post-harvest production report capturing actual yield and sale price for a
/// declaration (Supabase `production_reports` table). Combined with logged
/// [Expense]s this produces the realized Profit & Loss (Objective 2).
class ProductionReport extends Equatable {
  const ProductionReport({
    required this.id,
    required this.declarationId,
    required this.farmerId,
    required this.actualYieldKg,
    required this.actualPricePerKg,
    required this.harvestedOn,
    this.lossKg = 0,
    this.notes,
    this.createdAt,
  });

  final String id;
  final String declarationId;
  final String farmerId;
  final double actualYieldKg;
  final double actualPricePerKg;
  final DateTime harvestedOn;

  /// Quantity lost (spoilage, rejects, calamity) — informational for P&L notes.
  final double lossKg;
  final String? notes;
  final DateTime? createdAt;

  factory ProductionReport.fromMap(Map<String, dynamic> map) =>
      ProductionReport(
        id: asString(map['id']),
        declarationId: asString(map['declaration_id']),
        farmerId: asString(map['farmer_id']),
        actualYieldKg: asDouble(map['actual_yield_kg']),
        actualPricePerKg: asDouble(map['actual_price_per_kg']),
        harvestedOn: asDateOr(map['harvested_on'], DateTime.now()),
        lossKg: asDouble(map['loss_kg']),
        notes: asStringOrNull(map['notes']),
        createdAt: asDate(map['created_at']),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'declaration_id': declarationId,
        'farmer_id': farmerId,
        'actual_yield_kg': actualYieldKg,
        'actual_price_per_kg': actualPricePerKg,
        'harvested_on': dateToWire(harvestedOn),
        'loss_kg': lossKg,
        'notes': notes,
        'created_at': dateToWire(createdAt),
      };

  double get actualRevenue => actualYieldKg * actualPricePerKg;

  @override
  List<Object?> get props =>
      [id, declarationId, actualYieldKg, actualPricePerKg, harvestedOn, lossKg];
}

import 'package:equatable/equatable.dart';

import '../core/utils/parsing.dart';
import 'enums.dart';

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
    this.soldToChannel = SalesChannel.bagsakan,
    this.buyerName,
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

  /// Where the harvest actually went. Without this the municipality can see
  /// what was planted but not where the supply ended up — the gap behind the
  /// "ay diin nagkadto ang supply?" question the MAO portal has to answer.
  final SalesChannel soldToChannel;

  /// Name of the buyer/trader, when the farmer knows it.
  final String? buyerName;

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
        soldToChannel:
            SalesChannel.fromWire(asStringOrNull(map['sold_to_channel'])),
        buyerName: asStringOrNull(map['buyer_name']),
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
        'sold_to_channel': soldToChannel.wire,
        'buyer_name': buyerName,
        'notes': notes,
        'created_at': dateToWire(createdAt),
      };

  double get actualRevenue => actualYieldKg * actualPricePerKg;

  /// True when this harvest left the municipality's monitored supply chain.
  bool get leftMunicipality => soldToChannel.leavesMunicipality;

  @override
  List<Object?> get props => [
        id,
        declarationId,
        actualYieldKg,
        actualPricePerKg,
        harvestedOn,
        lossKg,
        soldToChannel,
        buyerName,
      ];
}

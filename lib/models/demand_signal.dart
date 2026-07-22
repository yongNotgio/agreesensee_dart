import 'package:equatable/equatable.dart';

import '../core/constants/app_constants.dart';
import '../core/utils/parsing.dart';
import 'enums.dart';

/// Demand a cooperative declares it can absorb for a crop over a period
/// (Supabase `demand_signals` table).
///
/// The Market Saturation Index divides projected supply by demand, and demand
/// used to be a single hardcoded annual constant per crop — unverifiable, and
/// impossible for anyone on the ground to correct. This is the mechanism that
/// lets demand be *measured from the cooperatives* who actually buy the produce,
/// so the oversupply signal rests on something defensible.
class DemandSignal extends Equatable {
  const DemandSignal({
    required this.id,
    required this.cooperativeId,
    required this.cropId,
    required this.periodStart,
    required this.periodEnd,
    required this.demandTons,
    required this.buyerType,
    this.pricePerKg,
    this.buyerName,
    this.notes,
    this.createdAt,
  });

  final String id;
  final String cooperativeId;
  final String cropId;
  final DateTime periodStart;
  final DateTime periodEnd;

  /// Volume the cooperative commits to absorbing over the period.
  final double demandTons;

  final BuyerType buyerType;

  /// Indicative buying price, when the cooperative can commit to one.
  final double? pricePerKg;
  final String? buyerName;
  final String? notes;
  final DateTime? createdAt;

  factory DemandSignal.fromMap(Map<String, dynamic> map) => DemandSignal(
        id: asString(map['id']),
        cooperativeId: asString(map['cooperative_id']),
        cropId: asString(map['crop_id']),
        periodStart: asDateOr(map['period_start'], DateTime.now()),
        periodEnd: asDateOr(map['period_end'], DateTime.now()),
        demandTons: asDouble(map['demand_tons']),
        buyerType: BuyerType.fromWire(asStringOrNull(map['buyer_type'])),
        pricePerKg: asDoubleOrNull(map['price_per_kg']),
        buyerName: asStringOrNull(map['buyer_name']),
        notes: asStringOrNull(map['notes']),
        createdAt: asDate(map['created_at']),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'cooperative_id': cooperativeId,
        'crop_id': cropId,
        'period_start': dateOnlyToWire(periodStart),
        'period_end': dateOnlyToWire(periodEnd),
        'demand_tons': demandTons,
        'buyer_type': buyerType.wire,
        'price_per_kg': pricePerKg,
        'buyer_name': buyerName,
        'notes': notes,
        'created_at': dateToWire(createdAt),
      };

  String get cropName => CropCatalog.nameFor(cropId);

  /// Whether this commitment is in force on [day].
  bool coversDate(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    final start = DateTime(periodStart.year, periodStart.month, periodStart.day);
    final end = DateTime(periodEnd.year, periodEnd.month, periodEnd.day);
    return !d.isBefore(start) && !d.isAfter(end);
  }

  bool get isActive => coversDate(DateTime.now());

  int get durationDays => periodEnd.difference(periodStart).inDays.abs() + 1;

  /// Demand normalized to a per-month rate, for comparison against monthly
  /// baselines regardless of the period the cooperative declared.
  double get monthlyEquivalentTons =>
      durationDays == 0 ? demandTons : demandTons * 30.0 / durationDays;

  @override
  List<Object?> get props => [
        id,
        cooperativeId,
        cropId,
        periodStart,
        periodEnd,
        demandTons,
        buyerType,
        pricePerKg,
      ];
}

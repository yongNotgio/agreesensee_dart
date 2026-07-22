import 'package:equatable/equatable.dart';

import '../core/constants/app_constants.dart';
import '../core/utils/parsing.dart';
import 'enums.dart';

/// A crop declaration — a farmer's record of what they are planting, where, and
/// when (Supabase `crop_declarations` table).
///
/// It is a **record, not an application**: it saves as [DeclarationStatus.active]
/// immediately, with no approval queue. AgriSense advises before planting (see
/// the risk verdict captured in [riskAtDeclaration]) and records afterwards.
///
/// [expectedYieldKg] and [projectedPricePerKg] are **system-derived**, not
/// farmer-entered — computed from the calibrated dataset and the barangay's
/// suitability index at save time. A farmer cannot know these numbers, so the
/// app no longer asks them to guess.
class CropDeclaration extends Equatable {
  const CropDeclaration({
    required this.id,
    required this.farmerId,
    required this.farmId,
    required this.cropId,
    required this.variety,
    required this.areaHa,
    required this.plantingDate,
    required this.expectedHarvestDate,
    required this.expectedYieldKg,
    required this.barangay,
    required this.status,
    this.seedlingSowingDate,
    this.companionCropIds = const [],
    this.projectedPricePerKg,
    this.riskAtDeclaration,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String farmerId;
  final String farmId;
  final String cropId;
  final String variety;
  final double areaHa;

  /// Transplanting date for nursery-raised crops, or the direct-sowing date.
  /// This is day 0 of the crop calendar.
  final DateTime plantingDate;

  /// When seed went into the seedbed, for crops raised from seedlings. Null for
  /// direct-seeded crops. Precedes [plantingDate] by the crop's nursery period.
  final DateTime? seedlingSowingDate;

  final DateTime expectedHarvestDate;

  /// System-derived expected yield (kg) — calibrated mean yield × area ×
  /// barangay suitability index.
  final double expectedYieldKg;

  final String barangay;
  final DeclarationStatus status;

  /// Intercropping (mix-and-match) companion crops planted with the main crop.
  final List<String> companionCropIds;

  /// System-derived baseline farmgate price (₱/kg) at declaration time.
  final double? projectedPricePerKg;

  /// The oversupply/suitability verdict the app showed *before* the farmer
  /// committed — `low` / `caution` / `high`. Retained so the study can report
  /// whether farmers acted on the advice they were given.
  final String? riskAtDeclaration;

  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory CropDeclaration.fromMap(Map<String, dynamic> map) => CropDeclaration(
        id: asString(map['id']),
        farmerId: asString(map['farmer_id']),
        farmId: asString(map['farm_id']),
        cropId: asString(map['crop_id']),
        variety: asString(map['variety']),
        areaHa: asDouble(map['area_ha']),
        plantingDate: asDateOr(map['planting_date'], DateTime.now()),
        seedlingSowingDate: asDate(map['seedling_sowing_date']),
        expectedHarvestDate:
            asDateOr(map['expected_harvest_date'], DateTime.now()),
        expectedYieldKg: asDouble(map['expected_yield_kg']),
        barangay: asString(map['barangay']),
        status: DeclarationStatus.fromWire(asStringOrNull(map['status'])),
        companionCropIds: asStringList(map['companion_crop_ids']),
        projectedPricePerKg: asDoubleOrNull(map['projected_price_per_kg']),
        riskAtDeclaration: asStringOrNull(map['risk_at_declaration']),
        notes: asStringOrNull(map['notes']),
        createdAt: asDate(map['created_at']),
        updatedAt: asDate(map['updated_at']),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'farmer_id': farmerId,
        'farm_id': farmId,
        'crop_id': cropId,
        'variety': variety,
        'area_ha': areaHa,
        'planting_date': dateToWire(plantingDate),
        'seedling_sowing_date': dateToWire(seedlingSowingDate),
        'expected_harvest_date': dateToWire(expectedHarvestDate),
        'expected_yield_kg': expectedYieldKg,
        'barangay': barangay,
        'status': status.wire,
        'companion_crop_ids': companionCropIds,
        'projected_price_per_kg': projectedPricePerKg,
        'risk_at_declaration': riskAtDeclaration,
        'notes': notes,
        'created_at': dateToWire(createdAt),
        'updated_at': dateToWire(updatedAt),
      };

  CropDeclaration copyWith({
    String? cropId,
    String? variety,
    double? areaHa,
    DateTime? plantingDate,
    DateTime? seedlingSowingDate,
    DateTime? expectedHarvestDate,
    double? expectedYieldKg,
    String? barangay,
    DeclarationStatus? status,
    List<String>? companionCropIds,
    double? projectedPricePerKg,
    String? riskAtDeclaration,
    String? notes,
    DateTime? updatedAt,
  }) =>
      CropDeclaration(
        id: id,
        farmerId: farmerId,
        farmId: farmId,
        cropId: cropId ?? this.cropId,
        variety: variety ?? this.variety,
        areaHa: areaHa ?? this.areaHa,
        plantingDate: plantingDate ?? this.plantingDate,
        seedlingSowingDate: seedlingSowingDate ?? this.seedlingSowingDate,
        expectedHarvestDate: expectedHarvestDate ?? this.expectedHarvestDate,
        expectedYieldKg: expectedYieldKg ?? this.expectedYieldKg,
        barangay: barangay ?? this.barangay,
        status: status ?? this.status,
        companionCropIds: companionCropIds ?? this.companionCropIds,
        projectedPricePerKg: projectedPricePerKg ?? this.projectedPricePerKg,
        riskAtDeclaration: riskAtDeclaration ?? this.riskAtDeclaration,
        notes: notes ?? this.notes,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  String get cropName => CropCatalog.nameFor(cropId);

  /// Expected yield expressed in metric tons (for supply aggregation).
  double get expectedYieldTons => expectedYieldKg / 1000.0;

  /// Resolved price/kg: the price captured at declaration, or the catalog
  /// baseline if this row predates price capture.
  double get effectivePricePerKg =>
      projectedPricePerKg ?? CropCatalog.byIdOrFirst(cropId).baselinePricePerKg;

  double get projectedRevenue => expectedYieldKg * effectivePricePerKg;

  /// Day 0 of the crop calendar — the seedbed date when the crop is raised from
  /// seedlings, otherwise the direct-sowing date.
  DateTime get cycleStartDate => seedlingSowingDate ?? plantingDate;

  bool get raisedFromSeedlings => seedlingSowingDate != null;

  @override
  List<Object?> get props => [
        id,
        farmerId,
        farmId,
        cropId,
        variety,
        areaHa,
        plantingDate,
        seedlingSowingDate,
        expectedHarvestDate,
        expectedYieldKg,
        status,
        companionCropIds,
      ];
}

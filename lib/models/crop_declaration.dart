import 'package:equatable/equatable.dart';

import '../core/constants/app_constants.dart';
import '../core/utils/parsing.dart';
import 'enums.dart';

/// A pre-planting crop declaration / farming project (Supabase
/// `crop_declarations` table). Phase 2 of the workflow; defaults to
/// [DeclarationStatus.pending] on submission.
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
    this.companionCropIds = const [],
    this.projectedPricePerKg,
    this.notes,
    this.reviewerNote,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String farmerId;
  final String farmId;
  final String cropId;
  final String variety;
  final double areaHa;
  final DateTime plantingDate;
  final DateTime expectedHarvestDate;
  final double expectedYieldKg;
  final String barangay;
  final DeclarationStatus status;

  /// Intercropping (mix-and-match) companion crops planted with the main crop.
  final List<String> companionCropIds;
  final double? projectedPricePerKg;
  final String? notes;

  /// Free-text feedback from BAW/Technician/MAO during validation.
  final String? reviewerNote;
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
        expectedHarvestDate:
            asDateOr(map['expected_harvest_date'], DateTime.now()),
        expectedYieldKg: asDouble(map['expected_yield_kg']),
        barangay: asString(map['barangay']),
        status: DeclarationStatus.fromWire(asStringOrNull(map['status'])),
        companionCropIds: asStringList(map['companion_crop_ids']),
        projectedPricePerKg: asDoubleOrNull(map['projected_price_per_kg']),
        notes: asStringOrNull(map['notes']),
        reviewerNote: asStringOrNull(map['reviewer_note']),
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
        'expected_harvest_date': dateToWire(expectedHarvestDate),
        'expected_yield_kg': expectedYieldKg,
        'barangay': barangay,
        'status': status.wire,
        'companion_crop_ids': companionCropIds,
        'projected_price_per_kg': projectedPricePerKg,
        'notes': notes,
        'reviewer_note': reviewerNote,
        'created_at': dateToWire(createdAt),
        'updated_at': dateToWire(updatedAt),
      };

  CropDeclaration copyWith({
    String? cropId,
    String? variety,
    double? areaHa,
    DateTime? plantingDate,
    DateTime? expectedHarvestDate,
    double? expectedYieldKg,
    String? barangay,
    DeclarationStatus? status,
    List<String>? companionCropIds,
    double? projectedPricePerKg,
    String? notes,
    String? reviewerNote,
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
        expectedHarvestDate: expectedHarvestDate ?? this.expectedHarvestDate,
        expectedYieldKg: expectedYieldKg ?? this.expectedYieldKg,
        barangay: barangay ?? this.barangay,
        status: status ?? this.status,
        companionCropIds: companionCropIds ?? this.companionCropIds,
        projectedPricePerKg: projectedPricePerKg ?? this.projectedPricePerKg,
        notes: notes ?? this.notes,
        reviewerNote: reviewerNote ?? this.reviewerNote,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  String get cropName => CropCatalog.nameFor(cropId);

  /// Expected yield expressed in metric tons (for supply aggregation).
  double get expectedYieldTons => expectedYieldKg / 1000.0;

  /// Resolved price/kg: explicit projection or the crop's baseline.
  double get effectivePricePerKg =>
      projectedPricePerKg ?? CropCatalog.byIdOrFirst(cropId).baselinePricePerKg;

  double get projectedRevenue => expectedYieldKg * effectivePricePerKg;

  @override
  List<Object?> get props => [
        id,
        farmerId,
        farmId,
        cropId,
        variety,
        areaHa,
        plantingDate,
        expectedHarvestDate,
        expectedYieldKg,
        status,
        companionCropIds,
      ];
}

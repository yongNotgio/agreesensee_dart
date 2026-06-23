import 'package:equatable/equatable.dart';

import '../core/utils/parsing.dart';
import 'enums.dart';

/// A calamity / incident report (Supabase `calamity_reports` table).
/// Objective 4 — incident reporting that streamlines subsidy verification.
class CalamityReport extends Equatable {
  const CalamityReport({
    required this.id,
    required this.farmerId,
    required this.barangay,
    required this.type,
    required this.occurredOn,
    required this.affectedAreaHa,
    required this.lossPercent,
    required this.status,
    this.declarationId,
    this.cropId,
    this.estimatedLossValue,
    this.description,
    this.photoUrls = const [],
    this.verifierNote,
    this.createdAt,
  });

  final String id;
  final String farmerId;
  final String barangay;
  final CalamityType type;
  final DateTime occurredOn;
  final double affectedAreaHa;

  /// Estimated crop loss as a percentage (0–100) — the key damage marker.
  final double lossPercent;
  final VerificationStatus status;
  final String? declarationId;
  final String? cropId;
  final double? estimatedLossValue;
  final String? description;
  final List<String> photoUrls;
  final String? verifierNote;
  final DateTime? createdAt;

  factory CalamityReport.fromMap(Map<String, dynamic> map) => CalamityReport(
        id: asString(map['id']),
        farmerId: asString(map['farmer_id']),
        barangay: asString(map['barangay']),
        type: CalamityType.fromWire(asStringOrNull(map['type'])),
        occurredOn: asDateOr(map['occurred_on'], DateTime.now()),
        affectedAreaHa: asDouble(map['affected_area_ha']),
        lossPercent: asDouble(map['loss_percent']),
        status: VerificationStatus.fromWire(asStringOrNull(map['status'])),
        declarationId: asStringOrNull(map['declaration_id']),
        cropId: asStringOrNull(map['crop_id']),
        estimatedLossValue: asDoubleOrNull(map['estimated_loss_value']),
        description: asStringOrNull(map['description']),
        photoUrls: asStringList(map['photo_urls']),
        verifierNote: asStringOrNull(map['verifier_note']),
        createdAt: asDate(map['created_at']),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'farmer_id': farmerId,
        'barangay': barangay,
        'type': type.wire,
        'occurred_on': dateToWire(occurredOn),
        'affected_area_ha': affectedAreaHa,
        'loss_percent': lossPercent,
        'status': status.wire,
        'declaration_id': declarationId,
        'crop_id': cropId,
        'estimated_loss_value': estimatedLossValue,
        'description': description,
        'photo_urls': photoUrls,
        'verifier_note': verifierNote,
        'created_at': dateToWire(createdAt),
      };

  CalamityReport copyWith({
    VerificationStatus? status,
    String? verifierNote,
  }) =>
      CalamityReport(
        id: id,
        farmerId: farmerId,
        barangay: barangay,
        type: type,
        occurredOn: occurredOn,
        affectedAreaHa: affectedAreaHa,
        lossPercent: lossPercent,
        status: status ?? this.status,
        declarationId: declarationId,
        cropId: cropId,
        estimatedLossValue: estimatedLossValue,
        description: description,
        photoUrls: photoUrls,
        verifierNote: verifierNote ?? this.verifierNote,
        createdAt: createdAt,
      );

  @override
  List<Object?> get props => [
        id,
        farmerId,
        barangay,
        type,
        occurredOn,
        affectedAreaHa,
        lossPercent,
        status,
      ];
}

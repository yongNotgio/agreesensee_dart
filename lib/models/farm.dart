import 'package:equatable/equatable.dart';

import '../core/utils/parsing.dart';
import 'enums.dart';

/// A farmer's farm/parcel profile (Supabase `farms` table). Created in
/// Phase 1 (Farmer Registration & Farm Profiling).
class Farm extends Equatable {
  const Farm({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.barangay,
    required this.totalAreaHa,
    this.latitude,
    this.longitude,
    this.soilType,
    this.previousCrops = const [],
    this.previousActivities,
    this.photoUrls = const [],
    this.createdAt,
  });

  final String id;
  final String ownerId;
  final String name;
  final String barangay;
  final double totalAreaHa;
  final double? latitude;
  final double? longitude;
  final String? soilType;

  /// Crop ids previously planted on this farm (history for the recommender).
  final List<String> previousCrops;
  final String? previousActivities;
  final List<String> photoUrls;
  final DateTime? createdAt;

  factory Farm.fromMap(Map<String, dynamic> map) => Farm(
        id: asString(map['id']),
        ownerId: asString(map['owner_id']),
        name: asString(map['name'], 'My Farm'),
        barangay: asString(map['barangay']),
        totalAreaHa: asDouble(map['total_area_ha']),
        latitude: asDoubleOrNull(map['latitude']),
        longitude: asDoubleOrNull(map['longitude']),
        soilType: asStringOrNull(map['soil_type']),
        previousCrops: asStringList(map['previous_crops']),
        previousActivities: asStringOrNull(map['previous_activities']),
        photoUrls: asStringList(map['photo_urls']),
        createdAt: asDate(map['created_at']),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'owner_id': ownerId,
        'name': name,
        'barangay': barangay,
        'total_area_ha': totalAreaHa,
        'latitude': latitude,
        'longitude': longitude,
        'soil_type': soilType,
        'previous_crops': previousCrops,
        'previous_activities': previousActivities,
        'photo_urls': photoUrls,
        'created_at': dateToWire(createdAt),
      };

  Farm copyWith({
    String? name,
    String? barangay,
    double? totalAreaHa,
    double? latitude,
    double? longitude,
    String? soilType,
    List<String>? previousCrops,
    String? previousActivities,
    List<String>? photoUrls,
  }) =>
      Farm(
        id: id,
        ownerId: ownerId,
        name: name ?? this.name,
        barangay: barangay ?? this.barangay,
        totalAreaHa: totalAreaHa ?? this.totalAreaHa,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        soilType: soilType ?? this.soilType,
        previousCrops: previousCrops ?? this.previousCrops,
        previousActivities: previousActivities ?? this.previousActivities,
        photoUrls: photoUrls ?? this.photoUrls,
        createdAt: createdAt,
      );

  bool get hasGeo => latitude != null && longitude != null;

  @override
  List<Object?> get props =>
      [id, ownerId, name, barangay, totalAreaHa, soilType, previousCrops];
}

/// Convenience extension to surface the active season at a point in time.
extension FarmSeason on Farm {
  Season seasonNow() => Season.forMonth(DateTime.now().month);
}

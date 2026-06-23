import 'package:equatable/equatable.dart';

import '../core/utils/parsing.dart';

/// A farmers' association / cooperative (Supabase `cooperatives` table). The
/// Cooperative portal administers buy-back programs and monitors member supply
/// (Objective 3).
class Cooperative extends Equatable {
  const Cooperative({
    required this.id,
    required this.name,
    required this.barangay,
    this.contactPerson,
    this.contactNumber,
    this.memberCount = 0,
    this.buyBackCapacityTons,
    this.createdAt,
  });

  final String id;
  final String name;
  final String barangay;
  final String? contactPerson;
  final String? contactNumber;
  final int memberCount;

  /// Tons of surplus the cooperative can absorb through buy-back programs.
  final double? buyBackCapacityTons;
  final DateTime? createdAt;

  factory Cooperative.fromMap(Map<String, dynamic> map) => Cooperative(
        id: asString(map['id']),
        name: asString(map['name'], 'Cooperative'),
        barangay: asString(map['barangay']),
        contactPerson: asStringOrNull(map['contact_person']),
        contactNumber: asStringOrNull(map['contact_number']),
        memberCount: asInt(map['member_count']),
        buyBackCapacityTons: asDoubleOrNull(map['buy_back_capacity_tons']),
        createdAt: asDate(map['created_at']),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'barangay': barangay,
        'contact_person': contactPerson,
        'contact_number': contactNumber,
        'member_count': memberCount,
        'buy_back_capacity_tons': buyBackCapacityTons,
        'created_at': dateToWire(createdAt),
      };

  @override
  List<Object?> get props =>
      [id, name, barangay, memberCount, buyBackCapacityTons];
}

/// An alternative market channel or buy-back program a cooperative can route
/// predicted surplus into (Supabase `market_channels` table).
class MarketChannel extends Equatable {
  const MarketChannel({
    required this.id,
    required this.cooperativeId,
    required this.name,
    required this.type,
    required this.capacityTons,
    this.cropIds = const [],
    this.pricePerKg,
    this.contact,
    this.notes,
  });

  final String id;
  final String cooperativeId;
  final String name;

  /// e.g. "buy_back", "institutional_buyer", "processor", "neighboring_market".
  final String type;
  final double capacityTons;
  final List<String> cropIds;
  final double? pricePerKg;
  final String? contact;
  final String? notes;

  factory MarketChannel.fromMap(Map<String, dynamic> map) => MarketChannel(
        id: asString(map['id']),
        cooperativeId: asString(map['cooperative_id']),
        name: asString(map['name']),
        type: asString(map['type'], 'buy_back'),
        capacityTons: asDouble(map['capacity_tons']),
        cropIds: asStringList(map['crop_ids']),
        pricePerKg: asDoubleOrNull(map['price_per_kg']),
        contact: asStringOrNull(map['contact']),
        notes: asStringOrNull(map['notes']),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'cooperative_id': cooperativeId,
        'name': name,
        'type': type,
        'capacity_tons': capacityTons,
        'crop_ids': cropIds,
        'price_per_kg': pricePerKg,
        'contact': contact,
        'notes': notes,
      };

  String get typeLabel => switch (type) {
        'buy_back' => 'Association Buy-back',
        'institutional_buyer' => 'Institutional Buyer',
        'processor' => 'Processor / Agri-business',
        'neighboring_market' => 'Neighboring Market',
        _ => 'Market Channel',
      };

  @override
  List<Object?> get props =>
      [id, cooperativeId, name, type, capacityTons, cropIds, pricePerKg];
}

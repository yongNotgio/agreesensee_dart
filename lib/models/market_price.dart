import 'package:equatable/equatable.dart';

import '../core/utils/parsing.dart';

/// A historical/observed market price point for a crop (Supabase
/// `market_prices` table). Used by the financial and scenario engines.
class MarketPrice extends Equatable {
  const MarketPrice({
    required this.id,
    required this.cropId,
    required this.pricePerKg,
    required this.recordedOn,
    this.market,
  });

  final String id;
  final String cropId;
  final double pricePerKg;
  final DateTime recordedOn;
  final String? market;

  factory MarketPrice.fromMap(Map<String, dynamic> map) => MarketPrice(
        id: asString(map['id']),
        cropId: asString(map['crop_id']),
        pricePerKg: asDouble(map['price_per_kg']),
        recordedOn: asDateOr(map['recorded_on'], DateTime.now()),
        market: asStringOrNull(map['market']),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'crop_id': cropId,
        'price_per_kg': pricePerKg,
        'recorded_on': dateToWire(recordedOn),
        'market': market,
      };

  @override
  List<Object?> get props => [id, cropId, pricePerKg, recordedOn, market];
}

import 'package:equatable/equatable.dart';

import '../core/utils/parsing.dart';
import 'enums.dart';

/// A dated agronomic logbook entry (Supabase `logbook_entries` table).
/// Objective 4 — digital logbook for agronomic events such as fertilizer
/// application.
class LogbookEntry extends Equatable {
  const LogbookEntry({
    required this.id,
    required this.farmerId,
    required this.activity,
    required this.title,
    required this.performedOn,
    this.declarationId,
    this.details,
    this.inputUsed,
    this.quantity,
    this.unit,
    this.cost,
    this.createdAt,
  });

  final String id;
  final String farmerId;
  final ActivityType activity;
  final String title;
  final DateTime performedOn;
  final String? declarationId;
  final String? details;

  /// e.g. the specific fertilizer / pesticide product applied.
  final String? inputUsed;
  final double? quantity;
  final String? unit;
  final double? cost;
  final DateTime? createdAt;

  factory LogbookEntry.fromMap(Map<String, dynamic> map) => LogbookEntry(
        id: asString(map['id']),
        farmerId: asString(map['farmer_id']),
        activity: ActivityType.fromWire(asStringOrNull(map['activity'])),
        title: asString(map['title']),
        performedOn: asDateOr(map['performed_on'], DateTime.now()),
        declarationId: asStringOrNull(map['declaration_id']),
        details: asStringOrNull(map['details']),
        inputUsed: asStringOrNull(map['input_used']),
        quantity: asDoubleOrNull(map['quantity']),
        unit: asStringOrNull(map['unit']),
        cost: asDoubleOrNull(map['cost']),
        createdAt: asDate(map['created_at']),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'farmer_id': farmerId,
        'activity': activity.wire,
        'title': title,
        'performed_on': dateToWire(performedOn),
        'declaration_id': declarationId,
        'details': details,
        'input_used': inputUsed,
        'quantity': quantity,
        'unit': unit,
        'cost': cost,
        'created_at': dateToWire(createdAt),
      };

  @override
  List<Object?> get props =>
      [id, farmerId, activity, title, performedOn, declarationId, inputUsed];
}

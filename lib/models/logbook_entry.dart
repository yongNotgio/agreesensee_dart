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
    this.expenseId,
    this.plannedActivityId,
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

  /// Cost incurred performing this activity. When non-null this entry has a
  /// paired [Expense] (see [expenseId]) so the cost reaches the P&L — a logged
  /// activity and the money it cost are one record, entered once.
  final double? cost;

  /// The [Expense] created alongside this entry, if a cost was captured.
  final String? expenseId;

  /// The scheduled crop-calendar operation this entry fulfils, if the farmer
  /// logged it by confirming a recommended activity.
  final String? plannedActivityId;

  final DateTime? createdAt;

  bool get hasCost => cost != null && cost! > 0;

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
        expenseId: asStringOrNull(map['expense_id']),
        plannedActivityId: asStringOrNull(map['planned_activity_id']),
        createdAt: asDate(map['created_at']),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'farmer_id': farmerId,
        'activity': activity.wire,
        'title': title,
        'performed_on': dateOnlyToWire(performedOn),
        'declaration_id': declarationId,
        'details': details,
        'input_used': inputUsed,
        'quantity': quantity,
        'unit': unit,
        'cost': cost,
        'expense_id': expenseId,
        'planned_activity_id': plannedActivityId,
        'created_at': dateToWire(createdAt),
      };

  /// [clearCostLink] drops both [cost] and [expenseId] — needed when the paired
  /// expense is deleted, since passing null through the `??` fallbacks below
  /// would silently keep the old values.
  LogbookEntry copyWith({
    String? declarationId,
    String? details,
    String? inputUsed,
    double? quantity,
    String? unit,
    double? cost,
    String? expenseId,
    String? plannedActivityId,
    bool clearCostLink = false,
  }) =>
      LogbookEntry(
        id: id,
        farmerId: farmerId,
        activity: activity,
        title: title,
        performedOn: performedOn,
        declarationId: declarationId ?? this.declarationId,
        details: details ?? this.details,
        inputUsed: inputUsed ?? this.inputUsed,
        quantity: quantity ?? this.quantity,
        unit: unit ?? this.unit,
        cost: clearCostLink ? null : (cost ?? this.cost),
        expenseId: clearCostLink ? null : (expenseId ?? this.expenseId),
        plannedActivityId: plannedActivityId ?? this.plannedActivityId,
        createdAt: createdAt,
      );

  @override
  List<Object?> get props => [
        id,
        farmerId,
        activity,
        title,
        performedOn,
        declarationId,
        inputUsed,
        cost,
        expenseId,
      ];
}

import 'package:equatable/equatable.dart';

import '../core/utils/parsing.dart';
import 'enums.dart';

/// A single recorded farm expense tied to a declaration (Supabase `expenses`
/// table). Feeds the P&L / ROI ledger (Phase 7 — Financial Forecasting).
class Expense extends Equatable {
  const Expense({
    required this.id,
    required this.declarationId,
    required this.farmerId,
    required this.category,
    required this.description,
    required this.amount,
    required this.incurredOn,
    this.logbookEntryId,
    this.createdAt,
  });

  final String id;
  final String declarationId;
  final String farmerId;
  final ExpenseCategory category;
  final String description;
  final double amount;
  final DateTime incurredOn;

  /// The logbook entry that incurred this cost, when it was captured alongside
  /// a farm activity rather than entered standalone. Costs almost always come
  /// from doing something in the field, so this is the common case.
  final String? logbookEntryId;

  final DateTime? createdAt;

  /// True when this cost was recorded as part of logging a farm activity.
  bool get fromActivity => logbookEntryId != null;

  factory Expense.fromMap(Map<String, dynamic> map) => Expense(
        id: asString(map['id']),
        declarationId: asString(map['declaration_id']),
        farmerId: asString(map['farmer_id']),
        category: ExpenseCategory.fromWire(asStringOrNull(map['category'])),
        description: asString(map['description']),
        amount: asDouble(map['amount']),
        incurredOn: asDateOr(map['incurred_on'], DateTime.now()),
        logbookEntryId: asStringOrNull(map['logbook_entry_id']),
        createdAt: asDate(map['created_at']),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'declaration_id': declarationId,
        'farmer_id': farmerId,
        'category': category.wire,
        'description': description,
        'amount': amount,
        'incurred_on': dateOnlyToWire(incurredOn),
        'logbook_entry_id': logbookEntryId,
        'created_at': dateToWire(createdAt),
      };

  Expense copyWith({
    ExpenseCategory? category,
    String? description,
    double? amount,
    DateTime? incurredOn,
    String? logbookEntryId,
  }) =>
      Expense(
        id: id,
        declarationId: declarationId,
        farmerId: farmerId,
        category: category ?? this.category,
        description: description ?? this.description,
        amount: amount ?? this.amount,
        incurredOn: incurredOn ?? this.incurredOn,
        logbookEntryId: logbookEntryId ?? this.logbookEntryId,
        createdAt: createdAt,
      );

  @override
  List<Object?> get props => [
        id,
        declarationId,
        category,
        description,
        amount,
        incurredOn,
        logbookEntryId,
      ];
}

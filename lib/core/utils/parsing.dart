/// Defensive JSON coercion helpers shared by every model's `fromMap`.
///
/// Supabase/Postgres can return `numeric` as `String`, `int` as `num`, ISO
/// timestamps as `String`, etc. These keep model factories small and resilient.
double asDouble(dynamic value, [double fallback = 0]) {
  if (value == null) return fallback;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? fallback;
}

double? asDoubleOrNull(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

int asInt(dynamic value, [int fallback = 0]) {
  if (value == null) return fallback;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString()) ?? fallback;
}

bool asBool(dynamic value, [bool fallback = false]) {
  if (value == null) return fallback;
  if (value is bool) return value;
  final s = value.toString().toLowerCase();
  return s == 'true' || s == 't' || s == '1' || s == 'yes';
}

String asString(dynamic value, [String fallback = '']) {
  if (value == null) return fallback;
  return value.toString();
}

String? asStringOrNull(dynamic value) => value?.toString();

DateTime? asDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString());
}

DateTime asDateOr(dynamic value, DateTime fallback) =>
    asDate(value) ?? fallback;

List<String> asStringList(dynamic value) {
  if (value == null) return const [];
  if (value is List) return value.map((e) => e.toString()).toList();
  return const [];
}

/// Serialize a [DateTime] instant to a UTC ISO string (or null) for
/// `timestamptz` columns (`created_at`, `updated_at`, `verified_at`, …).
String? dateToWire(DateTime? value) => value?.toUtc().toIso8601String();

/// Serialize a **civil date** — year, month, day only — for Postgres `date`
/// columns (`planting_date`, `scheduled_on`, `incurred_on`, …).
///
/// Deliberately does not call [DateTime.toUtc]. A planting date or a scheduled
/// activity is the day the farmer means, not an instant in time; converting to
/// UTC first shifts it backward for any timezone ahead of UTC — which includes
/// the Philippines (UTC+8), the one timezone this app actually ships in. A
/// farmer picking "June 1" would otherwise have it silently stored as May 31.
String? dateOnlyToWire(DateTime? value) {
  if (value == null) return null;
  final y = value.year.toString().padLeft(4, '0');
  final m = value.month.toString().padLeft(2, '0');
  final d = value.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

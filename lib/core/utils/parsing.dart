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

/// Serialize a [DateTime] to an ISO string (or null) for upserts.
String? dateToWire(DateTime? value) => value?.toUtc().toIso8601String();

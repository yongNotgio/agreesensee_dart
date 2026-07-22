// One-off backfill for declarations whose crop calendar was never generated —
// either because they predate the `planned_activities` table (pre-migration
// 002) or because an earlier app version swallowed the generation failure
// silently.
//
// Deliberately self-contained (no `package:agrisense` imports): the real
// models pull in `package:flutter/material.dart` for icon fields, which the
// standalone Dart VM used by `dart run` cannot resolve outside a Flutter app.
// This replicates the plan-expansion step of `CropCalendarEngine.plan()`
// exactly — day 0 = planting date, each row offset by `days_after_planting` —
// straight against the same bundled `crop_activity_schedule.json` the app
// reads, so the output matches what the app would have produced at declare
// time.
//
// Reads declarations from a local JSON snapshot (fetched via the Supabase
// REST API) and writes the computed activities to a JSON file for a bulk
// INSERT via curl; makes no network calls itself.
//
// Run with:
//   dart run tool/backfill_calendars.dart <declarations.json> <out.json>

import 'dart:convert';
import 'dart:io';
import 'dart:math';

String _uuid() {
  final rng = Random.secure();
  final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  String hex(int start, int end) {
    final sb = StringBuffer();
    for (var i = start; i < end; i++) {
      sb.write(bytes[i].toRadixString(16).padLeft(2, '0'));
    }
    return sb.toString();
  }

  return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
}

String _dateOnly(DateTime d) {
  final y = d.year.toString().padLeft(4, '0');
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '$y-$m-$day';
}

void main(List<String> args) {
  if (args.length != 2) {
    stderr.writeln(
        'Usage: dart run tool/backfill_calendars.dart <declarations.json> <out.json>');
    exit(1);
  }

  final scheduleRaw = jsonDecode(
      File('assets/data/crop_activity_schedule.json').readAsStringSync()) as List;
  final scheduleByCrop = <String, List<Map<String, dynamic>>>{};
  for (final r in scheduleRaw.cast<Map<String, dynamic>>()) {
    scheduleByCrop.putIfAbsent(r['crop_id'] as String, () => []).add(r);
  }

  final declarationsRaw =
      jsonDecode(File(args[0]).readAsStringSync()) as List;
  final now = DateTime.now().toUtc().toIso8601String();

  final output = <Map<String, dynamic>>[];
  for (final raw in declarationsRaw.cast<Map<String, dynamic>>()) {
    final declarationId = raw['id'] as String;
    final farmerId = raw['farmer_id'] as String;
    final cropId = raw['crop_id'] as String;
    final plantingDate = DateTime.parse(raw['planting_date'] as String);
    final day0 = DateTime(plantingDate.year, plantingDate.month, plantingDate.day);

    final ops = scheduleByCrop[cropId] ?? const [];
    for (final op in ops) {
      final offset = op['days_after_planting'] as int;
      final input = (op['typical_input'] as String?) ?? '';
      final qty = (op['typical_qty_per_ha'] as num?)?.toDouble() ?? 0;
      final unit = (op['unit'] as String?) ?? '';

      output.add({
        'id': _uuid(),
        'declaration_id': declarationId,
        'farmer_id': farmerId,
        'activity': op['activity_type'],
        'title': op['title'],
        'scheduled_on': _dateOnly(day0.add(Duration(days: offset))),
        'days_after_planting': offset,
        'suggested_input': input.isEmpty ? null : input,
        'suggested_qty_per_ha': qty == 0 ? null : qty,
        'unit': unit.isEmpty ? null : unit,
        'status': 'pending',
        'logbook_entry_id': null,
        'completed_on': null,
        'created_at': now,
      });
    }
    stdout.writeln('$declarationId ($cropId): ${ops.length} activities');
  }

  File(args[1]).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(output));
  stdout.writeln('\nWrote ${output.length} activities across '
      '${declarationsRaw.length} declarations to ${args[1]}');
}

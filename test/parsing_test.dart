import 'package:agrisense/core/utils/parsing.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the date-only wire format used for Postgres `date` columns
/// (`planting_date`, `scheduled_on`, `incurred_on`, …).
///
/// `dateOnlyToWire` used to be `dateToWire`, which calls `.toUtc()` before
/// serializing. For a local-midnight `DateTime` on any machine east of UTC —
/// which includes the Philippines (UTC+8), the one timezone this app actually
/// ships in — that conversion silently rolls the date back to the previous
/// day before it ever reaches the database. A farmer picking June 1st would
/// have it stored as May 31st with no error anywhere.
void main() {
  group('dateOnlyToWire', () {
    test('serializes the calendar date exactly as given', () {
      expect(dateOnlyToWire(DateTime(2026, 6, 1)), '2026-06-01');
      expect(dateOnlyToWire(DateTime(2026, 12, 31)), '2026-12-31');
      expect(dateOnlyToWire(DateTime(2026, 1, 1)), '2026-01-01');
    });

    test('pads single-digit month and day', () {
      expect(dateOnlyToWire(DateTime(2026, 3, 5)), '2026-03-05');
    });

    test('null passes through', () {
      expect(dateOnlyToWire(null), isNull);
    });

    test('does not shift with time-of-day set', () {
      // A midnight-local DateTime and a late-evening one on the same day must
      // serialize to the same calendar date — the old dateToWire behaviour
      // would push the evening one into the next UTC day for timezones west
      // of UTC, or the midnight one into the previous day for timezones east
      // of it.
      expect(dateOnlyToWire(DateTime(2026, 6, 1, 0, 0)), '2026-06-01');
      expect(dateOnlyToWire(DateTime(2026, 6, 1, 23, 59)), '2026-06-01');
    });

    test('is independent of the host timezone', () {
      // The whole point of the fix: unlike dateToWire, this must never involve
      // .toUtc(). Constructing the same local date and reading back year/month
      // /day should round-trip regardless of what timezone the test runs in.
      final d = DateTime(2026, 6, 1);
      expect(dateOnlyToWire(d), '${d.year}-06-01');
    });
  });

  group('dateToWire (unchanged — for timestamptz columns)', () {
    test('still converts to UTC for true instants', () {
      final utcNoon = DateTime.utc(2026, 6, 1, 12);
      final local = utcNoon.toLocal();
      expect(dateToWire(local), utcNoon.toIso8601String());
    });

    test('null passes through', () {
      expect(dateToWire(null), isNull);
    });
  });
}

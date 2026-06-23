import 'dart:math';

/// Generates RFC-4122-ish v4 UUID strings without a third-party dependency.
///
/// Postgres `uuid` columns accept these directly, so client-generated ids let
/// the app create rows optimistically (offline-first) and upsert them later.
class IdGen {
  IdGen._();

  static final Random _rng = Random.secure();

  static String uuid() {
    final bytes = List<int>.generate(16, (_) => _rng.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant 10
    String hex(int start, int end) {
      final sb = StringBuffer();
      for (var i = start; i < end; i++) {
        sb.write(bytes[i].toRadixString(16).padLeft(2, '0'));
      }
      return sb.toString();
    }

    return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
  }
}

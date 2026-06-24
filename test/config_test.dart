import 'dart:io';

import 'package:agrisense/core/config/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

/// Verifies the Supabase credential-resolution path (dart-define → .env →
/// demo). Does not hit the network; it only confirms the app will boot in the
/// correct mode for the credentials present.
void main() {
  test('hydrateFromEnv toggles demo mode correctly', () {
    AppConfig.hydrateFromEnv(url: '', anonKey: '');
    expect(AppConfig.isDemoMode, isTrue,
        reason: 'empty credentials → demo mode');

    AppConfig.hydrateFromEnv(
        url: 'https://demo.supabase.co', anonKey: 'eyJtest');
    expect(AppConfig.isDemoMode, isFalse,
        reason: 'non-empty credentials → live mode');
    expect(AppConfig.supabaseUrl, 'https://demo.supabase.co');
  });

  test('the real .env (if present) yields a live Supabase connection', () {
    final file = File('.env');
    if (!file.existsSync()) {
      // No .env on this machine (e.g. CI) — app would run in demo mode. OK.
      return;
    }
    final values = <String, String>{};
    for (final line in file.readAsLinesSync()) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      final i = trimmed.indexOf('=');
      if (i <= 0) continue;
      values[trimmed.substring(0, i).trim()] =
          trimmed.substring(i + 1).trim().replaceAll('"', '');
    }

    AppConfig.hydrateFromEnv(
      url: values['SUPABASE_URL'] ?? '',
      anonKey: values['SUPABASE_ANON_KEY'] ?? '',
    );

    expect(AppConfig.supabaseUrl, startsWith('https://'),
        reason: 'SUPABASE_URL should be a valid https URL');
    expect(AppConfig.supabaseUrl, contains('supabase.co'));
    expect(AppConfig.supabaseAnonKey, isNotEmpty);
    expect(AppConfig.isDemoMode, isFalse,
        reason: 'with a real .env the app boots against the live backend');
  });
}

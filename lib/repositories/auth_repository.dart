import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/cache/local_cache.dart';
import '../models/enums.dart';
import '../models/profile.dart';

/// Authentication + current-profile gateway.
///
/// Custom auth: credentials are a plain-text email/password column in the
/// `profiles` table. Supabase Auth (JWT sessions) is NOT used. All
/// communication with Supabase uses the anon key against RLS-disabled tables.
///
/// Session persistence (both demo and live): the signed-in profile id is
/// stored in SharedPreferences under [_sessionKey] so the session survives
/// hot-restarts and cold boots without a network call.
class AuthRepository {
  AuthRepository({
    required this.client,
    required this.cache,
  });

  final SupabaseClient? client;
  final LocalCache cache;

  static const _sessionKey = 'session_profile_id';
  static const _profilesKey = 'profiles';

  bool get isDemo => client == null;

  /// The currently signed-in user id, resolved from the local session store.
  String? get currentUserId =>
      cache.readObject(_sessionKey)?['id'] as String?;

  /// Emits the current auth state. Used only for initial bootstrap; the router
  /// watches the Riverpod [AuthController] state directly.
  Stream<bool> authStateChanges() => Stream.value(currentUserId != null);

  /// Resolve the profile row for the active session.
  Future<Profile?> currentProfile() async {
    final id = currentUserId;
    if (id == null) return null;

    if (isDemo) {
      final map = _localProfiles().firstWhere(
        (p) => p['id'] == id,
        orElse: () => <String, dynamic>{},
      );
      return map.isEmpty ? null : Profile.fromMap(map);
    }

    try {
      final data = await client!
          .from('profiles')
          .select()
          .eq('id', id)
          .maybeSingle();
      return data == null ? null : Profile.fromMap(Map<String, dynamic>.from(data));
    } on Object {
      // Network failure — try the local mirror.
      final map = _localProfiles().firstWhere(
        (p) => p['id'] == id,
        orElse: () => <String, dynamic>{},
      );
      return map.isEmpty ? null : Profile.fromMap(map);
    }
  }

  /// Sign in with email + plain-text password.
  ///
  /// Live mode: queries `profiles WHERE lower(email)=? AND password=?`.
  /// Demo mode: matches against the local seeded profile list (any password
  /// is accepted so the demo can be explored without remembering credentials).
  Future<Profile> signIn({
    required String email,
    required String password,
  }) async {
    if (isDemo) {
      final match = _localProfiles().firstWhere(
        (p) => (p['email'] as String?)?.toLowerCase() == email.toLowerCase(),
        orElse: () => throw const AuthFailure(
            'No demo account for that email. Try farmer@agrisense.ph or coop@agrisense.ph.'),
      );
      await cache.writeObject(_sessionKey, {'id': match['id']});
      return Profile.fromMap(match);
    }

    final data = await client!
        .from('profiles')
        .select()
        .eq('email', email.trim().toLowerCase())
        .eq('password', password)
        .maybeSingle();

    if (data == null) {
      throw const AuthFailure('Invalid email or password.');
    }

    final profile = Profile.fromMap(Map<String, dynamic>.from(data));
    await cache.writeObject(_sessionKey, {'id': profile.id});
    // Mirror locally for offline resilience.
    final profiles = _localProfiles();
    final idx = profiles.indexWhere((p) => p['id'] == profile.id);
    final profileMap = Map<String, dynamic>.from(data);
    if (idx >= 0) { profiles[idx] = profileMap; } else { profiles.add(profileMap); }
    await cache.writeList(_profilesKey, profiles);
    return profile;
  }

  /// Register a new account + profile row.
  ///
  /// Farmers register with an RSBSA number and barangay and land in
  /// [AccountVerification.pending] — residency is confirmed against the MAO
  /// roster by a cooperative officer or technician, not asserted by the person
  /// signing up. Accounts without an RSBSA number stay `unverified`.
  Future<Profile> signUp({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required UserRole role,
    String? middleName,
    String? username,
    String? contactNumber,
    String? barangay,
    String? cooperativeId,
    String? rsbsaNumber,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final handle = username?.trim().toLowerCase();
    final verification = (rsbsaNumber ?? '').trim().isEmpty
        ? AccountVerification.unverified
        : AccountVerification.pending;

    if (isDemo) {
      final profiles = _localProfiles();
      if (profiles.any((p) =>
          (p['email'] as String?)?.toLowerCase() == normalizedEmail)) {
        throw const AuthFailure('An account with that email already exists.');
      }
      if (handle != null &&
          profiles.any(
              (p) => (p['username'] as String?)?.toLowerCase() == handle)) {
        throw const AuthFailure('That username is already taken.');
      }
      final id = 'demo-${DateTime.now().millisecondsSinceEpoch}';
      final profile = Profile(
        id: id,
        firstName: firstName,
        lastName: lastName,
        middleName: middleName,
        username: handle,
        role: role,
        email: normalizedEmail,
        contactNumber: contactNumber,
        barangay: barangay,
        cooperativeId: cooperativeId,
        rsbsaNumber: rsbsaNumber,
        verification: verification,
        createdAt: DateTime.now(),
      );
      profiles.add(profile.toMap());
      await cache.writeList(_profilesKey, profiles);
      await cache.writeObject(_sessionKey, {'id': id});
      return profile;
    }

    // Check uniqueness before inserting.
    final existing = await client!
        .from('profiles')
        .select('id')
        .eq('email', normalizedEmail)
        .maybeSingle();
    if (existing != null) {
      throw const AuthFailure('An account with that email already exists.');
    }
    if (handle != null) {
      final taken = await client!
          .from('profiles')
          .select('id')
          .eq('username', handle)
          .maybeSingle();
      if (taken != null) {
        throw const AuthFailure('That username is already taken.');
      }
    }

    // Insert; let the DB generate the UUID via DEFAULT gen_random_uuid().
    final inserted = await client!.from('profiles').insert({
      'email': normalizedEmail,
      'password': password,
      'first_name': firstName,
      'last_name': lastName,
      'middle_name': middleName,
      'username': handle,
      'role': role.wire,
      'contact_number': contactNumber,
      'barangay': barangay,
      'cooperative_id': cooperativeId,
      'rsbsa_number': rsbsaNumber,
      'verification': verification.wire,
      'created_at': DateTime.now().toIso8601String(),
    }).select().single();

    final profile = Profile.fromMap(Map<String, dynamic>.from(inserted));
    await cache.writeObject(_sessionKey, {'id': profile.id});
    return profile;
  }

  Future<void> signOut() async {
    await cache.remove(_sessionKey);
  }

  Future<Profile> updateProfile(Profile profile) async {
    if (isDemo) {
      final profiles = _localProfiles();
      final i = profiles.indexWhere((p) => p['id'] == profile.id);
      if (i >= 0) {
        profiles[i] = profile.toMap();
      } else {
        profiles.add(profile.toMap());
      }
      await cache.writeList(_profilesKey, profiles);
      return profile;
    }
    // Upsert everything except password (password changes handled separately).
    await client!.from('profiles').upsert(profile.toMap());
    return profile;
  }

  List<Map<String, dynamic>> _localProfiles() => cache.readList(_profilesKey);
}

/// A user-facing authentication error.
class AuthFailure implements Exception {
  const AuthFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

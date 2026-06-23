import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/cache/local_cache.dart';
import '../models/enums.dart';
import '../models/profile.dart';

/// Authentication + current-profile gateway.
///
/// In live mode this wraps Supabase Auth (email/password) and the `profiles`
/// table. In demo mode it performs a local sign-in against the seeded profile
/// store so the role-based routing and portals are fully navigable offline.
class AuthRepository {
  AuthRepository({
    required this.client,
    required this.cache,
  });

  final SupabaseClient? client;
  final LocalCache cache;

  static const _sessionKey = 'demo_session_profile_id';
  static const _profilesKey = 'profiles';

  bool get isDemo => client == null;

  /// The currently authenticated user id, if any.
  String? get currentUserId {
    if (isDemo) return cache.readObject(_sessionKey)?['id'] as String?;
    return client!.auth.currentUser?.id;
  }

  /// Emits on every auth state change (sign-in / sign-out / token refresh).
  Stream<bool> authStateChanges() {
    if (isDemo) {
      // Demo sessions change only via explicit sign-in/out calls below; emit a
      // single current value. The notifier re-reads after each call.
      return Stream.value(currentUserId != null);
    }
    return client!.auth.onAuthStateChange
        .map((event) => event.session != null);
  }

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
    final data =
        await client!.from('profiles').select().eq('id', id).maybeSingle();
    return data == null ? null : Profile.fromMap(Map<String, dynamic>.from(data));
  }

  /// Sign in with email/password. Returns the resolved [Profile].
  Future<Profile> signIn({
    required String email,
    required String password,
  }) async {
    if (isDemo) {
      final match = _localProfiles().firstWhere(
        (p) => (p['email'] as String?)?.toLowerCase() == email.toLowerCase(),
        orElse: () => throw const AuthFailure(
            'No demo account for that email. Try a seeded account or register.'),
      );
      await cache.writeObject(_sessionKey, {'id': match['id']});
      return Profile.fromMap(match);
    }
    final res = await client!.auth
        .signInWithPassword(email: email, password: password);
    if (res.user == null) {
      throw const AuthFailure('Invalid email or password.');
    }
    final profile = await currentProfile();
    if (profile == null) {
      throw const AuthFailure('Account has no profile. Contact your MAO.');
    }
    return profile;
  }

  /// Register a new account + profile.
  Future<Profile> signUp({
    required String email,
    required String password,
    required String fullName,
    required UserRole role,
    String? contactNumber,
    String? barangay,
    String? cooperativeId,
  }) async {
    if (isDemo) {
      final profiles = _localProfiles();
      if (profiles.any(
          (p) => (p['email'] as String?)?.toLowerCase() == email.toLowerCase())) {
        throw const AuthFailure('An account with that email already exists.');
      }
      final id = 'demo-${DateTime.now().millisecondsSinceEpoch}';
      final profile = Profile(
        id: id,
        fullName: fullName,
        role: role,
        email: email,
        contactNumber: contactNumber,
        barangay: barangay,
        cooperativeId: cooperativeId,
        createdAt: DateTime.now(),
      );
      profiles.add(profile.toMap());
      await cache.writeList(_profilesKey, profiles);
      await cache.writeObject(_sessionKey, {'id': id});
      return profile;
    }

    final res = await client!.auth.signUp(email: email, password: password);
    final user = res.user;
    if (user == null) {
      throw const AuthFailure('Registration failed. Please try again.');
    }
    final profile = Profile(
      id: user.id,
      fullName: fullName,
      role: role,
      email: email,
      contactNumber: contactNumber,
      barangay: barangay,
      cooperativeId: cooperativeId,
      createdAt: DateTime.now(),
    );
    await client!.from('profiles').upsert(profile.toMap());
    return profile;
  }

  Future<void> signOut() async {
    if (isDemo) {
      await cache.remove(_sessionKey);
      return;
    }
    await client!.auth.signOut();
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

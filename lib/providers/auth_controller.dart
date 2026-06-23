import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/enums.dart';
import '../models/profile.dart';
import '../repositories/auth_repository.dart';
import 'core_providers.dart';

/// Authentication session state exposed to the router and UI.
class AuthState {
  const AuthState({this.profile, this.isLoading = false});

  final Profile? profile;
  final bool isLoading;

  bool get isAuthenticated => profile != null;
  UserRole? get role => profile?.role;

  AuthState copyWith({Profile? profile, bool? isLoading, bool clearProfile = false}) =>
      AuthState(
        profile: clearProfile ? null : (profile ?? this.profile),
        isLoading: isLoading ?? this.isLoading,
      );
}

/// Owns the authentication lifecycle: bootstraps the existing session, performs
/// sign-in / sign-up / sign-out, and notifies the router (via `redirect`) so the
/// user lands on the correct portal for their role.
class AuthController extends Notifier<AuthState> {
  AuthRepository get _repo => ref.read(authRepositoryProvider);

  @override
  AuthState build() {
    // Resolve any persisted session on startup.
    _restore();
    return const AuthState(isLoading: true);
  }

  Future<void> _restore() async {
    try {
      final profile = await _repo.currentProfile();
      state = AuthState(profile: profile, isLoading: false);
    } on Object {
      state = const AuthState(isLoading: false);
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    state = state.copyWith(isLoading: true);
    try {
      final profile = await _repo.signIn(email: email, password: password);
      state = AuthState(profile: profile, isLoading: false);
    } finally {
      if (state.isLoading) state = state.copyWith(isLoading: false);
    }
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
    required UserRole role,
    String? contactNumber,
    String? barangay,
    String? cooperativeId,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      final profile = await _repo.signUp(
        email: email,
        password: password,
        fullName: fullName,
        role: role,
        contactNumber: contactNumber,
        barangay: barangay,
        cooperativeId: cooperativeId,
      );
      state = AuthState(profile: profile, isLoading: false);
    } finally {
      if (state.isLoading) state = state.copyWith(isLoading: false);
    }
  }

  Future<void> updateProfile(Profile updated) async {
    final saved = await _repo.updateProfile(updated);
    state = state.copyWith(profile: saved);
  }

  Future<void> signOut() async {
    await _repo.signOut();
    state = const AuthState(isLoading: false);
  }
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);

/// Convenience: the signed-in profile (or null).
final currentProfileProvider =
    Provider<Profile?>((ref) => ref.watch(authControllerProvider).profile);

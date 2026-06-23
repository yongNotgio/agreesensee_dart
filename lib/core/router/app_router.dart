import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/login_screen.dart';
import '../../features/auth/register_screen.dart';
import '../../features/auth/splash_screen.dart';
import '../../features/auth/unsupported_role_screen.dart';
import '../../features/cooperative/coop_shell.dart';
import '../../features/farmer/farmer_shell.dart';
import '../../models/enums.dart';
import '../../providers/auth_controller.dart';

/// Named route paths.
class Routes {
  const Routes._();
  static const splash = '/splash';
  static const login = '/login';
  static const register = '/register';
  static const farmer = '/farmer';
  static const coop = '/coop';
  static const unsupported = '/unsupported';
}

/// Builds the [GoRouter] and keeps it reactive to auth-state changes so users
/// are redirected to the correct portal the moment they sign in / out.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.onDispose(refresh.dispose);
  // Re-run redirects whenever the auth session changes.
  ref.listen(authControllerProvider, (_, _) => refresh.value++);

  return GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    routes: [
      GoRoute(path: Routes.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(path: Routes.login, builder: (_, _) => const LoginScreen()),
      GoRoute(
          path: Routes.register, builder: (_, _) => const RegisterScreen()),
      GoRoute(path: Routes.farmer, builder: (_, _) => const FarmerShell()),
      GoRoute(path: Routes.coop, builder: (_, _) => const CoopShell()),
      GoRoute(
          path: Routes.unsupported,
          builder: (_, _) => const UnsupportedRoleScreen()),
    ],
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final loc = state.matchedLocation;

      if (auth.isLoading) {
        return loc == Routes.splash ? null : Routes.splash;
      }

      final loggedIn = auth.isAuthenticated;
      final authPages = loc == Routes.login || loc == Routes.register;

      if (!loggedIn) {
        return authPages ? null : Routes.login;
      }

      final home = _homeFor(auth.role);
      if (loc == Routes.splash || authPages) return home;
      return null;
    },
  );
});

String _homeFor(UserRole? role) => switch (role) {
      UserRole.farmer => Routes.farmer,
      UserRole.cooperative => Routes.coop,
      _ => Routes.unsupported,
    };

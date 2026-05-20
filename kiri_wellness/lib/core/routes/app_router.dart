import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/auth/auth_repository.dart';
import '../../core/config/environment.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/booking/presentation/booking_page.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/services/presentation/services_screen.dart';
import '../../features/packages/presentation/packages_screen.dart';
import '../../features/promotions/presentation/promotions_screen.dart';
import '../../features/raffles/presentation/raffles_screen.dart';
import '../../features/clients/presentation/clients_screen.dart';
import '../../features/appointments/presentation/appointments_screen.dart';
import '../../features/appointments/presentation/my_appointments_screen.dart';
import '../../features/schedule/presentation/schedule_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import 'app_shell.dart';

/// A [ChangeNotifier] that notifies GoRouter whenever the auth state changes.
class _AuthNotifier extends ChangeNotifier {
  _AuthNotifier(this._ref) {
    _ref.listen(authStateProvider, (_, __) => notifyListeners());
  }
  final Ref _ref;
}

final _authNotifierProvider = Provider<_AuthNotifier>(
  (ref) => _AuthNotifier(ref),
);

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(_authNotifierProvider);

  // Client site only exposes public booking routes
  if (Environment.isClientSite) {
    return GoRouter(
      initialLocation: '/book',
      debugLogDiagnostics: Environment.isQA,
      routes: [
        GoRoute(
          path: '/book',
          builder: (context, state) => const BookingPage(),
        ),
        GoRoute(
          path: '/my-appointments',
          builder: (context, state) => MyAppointmentsScreen(
            token: state.uri.queryParameters['token'],
          ),
        ),
      ],
    );
  }

  return GoRouter(
    initialLocation: '/appointments',
    debugLogDiagnostics: Environment.isQA,
    refreshListenable: notifier,
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);
      final isLoggedIn = authState.valueOrNull != null;
      final isLoading = authState.isLoading;
      final goingToLogin = state.matchedLocation == '/login';
      final goingToBook = state.matchedLocation.startsWith('/book');
      final goingToMyApts = state.matchedLocation.startsWith('/my-appointments');

      // Wait while Firebase resolves auth state
      if (isLoading) return null;

      // Public routes — always allowed
      if (goingToBook || goingToMyApts) return null;

      // Not logged in → send to login
      if (!isLoggedIn && !goingToLogin) return '/login';

      // Already logged in → don't show login page
      if (isLoggedIn && goingToLogin) return '/dashboard';

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/book',
        builder: (context, state) => const BookingPage(),
      ),
      GoRoute(
          path: '/my-appointments',
          builder: (context, state) => MyAppointmentsScreen(
            token: state.uri.queryParameters['token'],
          ),
        ),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: DashboardScreen(),
            ),
          ),
          GoRoute(
            path: '/appointments',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: AppointmentsScreen(),
            ),
          ),
          GoRoute(
            path: '/services',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ServicesScreen(),
            ),
          ),
          GoRoute(
            path: '/packages',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: PackagesScreen(),
            ),
          ),
          GoRoute(
            path: '/promotions',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: PromotionsScreen(),
            ),
          ),
          GoRoute(
            path: '/raffles',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: RafflesScreen(),
            ),
          ),
          GoRoute(
            path: '/clients',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ClientsScreen(),
            ),
          ),
          GoRoute(
            path: '/schedule',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ScheduleScreen(),
            ),
          ),
          GoRoute(
            path: '/settings',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: SettingsScreen(),
            ),
          ),
        ],
      ),
    ],
  );
});

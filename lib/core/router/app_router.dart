import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/home/screens/onboarding_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/signup_screen.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/booking/screens/charger_detail_screen.dart';
import '../../features/booking/screens/renter_bookings_screen.dart';
import '../../features/booking/screens/host_dashboard_screen.dart';
import '../../features/booking/screens/live_session_screen.dart';
import '../../features/charger/screens/my_chargers_screen.dart';
import '../../features/charger/screens/add_charger_screen.dart';
import '../../features/charger/models/charger_model.dart';
import '../../features/booking/models/booking_model.dart';

final routerProvider = Provider((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) async {
      // 1. Onboarding check
      final prefs = await SharedPreferences.getInstance();
      final hasSeenOnboarding = prefs.getBool('has_seen_onboarding') ?? false;

      if (!hasSeenOnboarding && state.matchedLocation != '/onboarding') {
        return '/onboarding';
      }

      // 2. Auth check with proper AsyncValue handling
      final isAuthenticated = authState.whenData((user) => user != null).value ?? false;
      
      // Handle error state - go to error screen  
      if (authState.hasError && state.matchedLocation != '/error') {
        return '/error';
      }

      // If not authenticated, redirect to login (unless already on auth pages)
      if (!isAuthenticated) {
        if (state.matchedLocation == '/login' ||
            state.matchedLocation == '/signup' ||
            state.matchedLocation == '/onboarding') {
          return null;
        }
        return '/login';
      }

      if (state.matchedLocation == '/login' ||
          state.matchedLocation == '/signup' ||
          state.matchedLocation == '/onboarding') {
        return '/';
      }

      return null; // Allow navigation
    },
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        name: 'signup',
        builder: (context, state) => const SignUpScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/charger/:id',
        builder: (context, state) {
          final charger = state.extra as ChargerModel;
          return ChargerDetailScreen(charger: charger);
        },
      ),
      GoRoute(
        path: '/bookings',
        builder: (context, state) => const RenterBookingsScreen(),
      ),
      GoRoute(
        path: '/host-dashboard',
        builder: (context, state) => const HostDashboardScreen(),
      ),
      GoRoute(
        path: '/my-chargers',
        builder: (context, state) => const MyChargersScreen(),
      ),
      GoRoute(
        path: '/add-charger',
        builder: (context, state) => const AddChargerScreen(),
      ),
      GoRoute(
        path: '/live-session',
        builder: (context, state) {
          final booking = state.extra as BookingModel;
          return LiveSessionScreen(booking: booking);
        },
      ),
    ],
  );
});

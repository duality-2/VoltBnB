import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/home/screens/role_wrapper_screen.dart';
import '../../features/home/screens/onboarding_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/signup_screen.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/auth/screens/forgot_password_screen.dart';
import '../../features/auth/screens/phone_otp_screen.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/booking/screens/charger_detail_screen.dart';
import '../../features/booking/screens/charger_reviews_screen.dart';
import '../../features/booking/screens/renter_bookings_screen.dart';
import '../../features/booking/screens/host_dashboard_screen.dart';
import '../../features/booking/screens/live_session_screen.dart';
import '../../features/booking/screens/booking_success_screen.dart';
import '../../features/charger/screens/my_chargers_screen.dart';
import '../../features/charger/screens/add_charger_screen.dart';
import '../../features/charger/models/charger_model.dart';
import '../../features/booking/models/booking_model.dart';
import '../../features/notifications/screens/notifications_screen.dart';
import '../widgets/error_screen.dart';

final routerProvider = Provider((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) async {
      // 1. Onboarding check
      final prefs = await SharedPreferences.getInstance();
      final hasSeenOnboarding = prefs.getBool('has_seen_onboarding') ?? false;

      if (!hasSeenOnboarding && state.matchedLocation != '/onboarding') {
        return '/onboarding';
      }

      // 2. Auth check with proper AsyncValue handling
      if (authState.isLoading) {
        return state.matchedLocation == '/splash' ? null : '/splash';
      }

      final isAuthenticated = authState.value != null;

      // Handle error state - go to error screen
      if (authState.hasError && state.matchedLocation != '/error') {
        return '/error';
      }

      // If not authenticated, redirect to login (unless already on auth pages)
      if (!isAuthenticated) {
        if (state.matchedLocation == '/login' ||
            state.matchedLocation == '/signup' ||
            state.matchedLocation == '/forgot-password' ||
            state.matchedLocation == '/phone-otp' ||
            state.matchedLocation == '/onboarding') {
          return null;
        }
        return '/login';
      }

      if (state.matchedLocation == '/login' ||
          state.matchedLocation == '/signup' ||
          state.matchedLocation == '/forgot-password' ||
          state.matchedLocation == '/phone-otp' ||
          state.matchedLocation == '/splash' ||
          state.matchedLocation == '/onboarding') {
        return '/';
      }

      return null; // Allow navigation
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) => const RoleWrapperScreen(),
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
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/phone-otp',
        builder: (context, state) => const PhoneOtpScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/charger/:id',
        builder: (context, state) {
          final charger = state.extra as ChargerModel;
          return ChargerDetailScreen(charger: charger);
        },
      ),
      GoRoute(
        path: '/charger/:id/reviews',
        builder: (context, state) {
          final chargerId = state.pathParameters['id'] ?? '';
          return ChargerReviewsScreen(chargerId: chargerId);
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
      GoRoute(
        path: '/booking-success',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          final booking = extra['booking'] as BookingModel;
          final charger = extra['charger'] as ChargerModel;
          return BookingSuccessScreen(booking: booking, charger: charger);
        },
      ),
      GoRoute(
        path: '/error',
        builder: (context, state) {
          final message = authState.error?.toString() ?? 'Unknown error.';
          return ErrorScreen(message: message);
        },
      ),
    ],
  );
});

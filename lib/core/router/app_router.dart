import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/signup_screen.dart';
import '../../features/auth/screens/forgot_password_screen.dart';
import '../../features/auth/screens/phone_otp_screen.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/charger/screens/home_screen.dart';
import '../../features/charger/screens/add_charger_screen.dart';
import '../../features/charger/screens/my_chargers_screen.dart';
import '../../features/profile/screens/profile_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      if (authState is AsyncLoading) return null;
      
      final isAuthenticated = authState.value != null;
      final isSplash = state.matchedLocation == '/splash';
      final isAuthRoute = state.matchedLocation == '/login' ||
                          state.matchedLocation == '/signup' ||
                          state.matchedLocation == '/forgot-password' ||
                          state.matchedLocation == '/phone-otp';

      if (isSplash) {
        return isAuthenticated ? '/home' : '/login';
      }

      if (!isAuthenticated) {
        return isAuthRoute ? null : '/login';
      }

      if (isAuthenticated && isAuthRoute) {
        return '/home';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignupScreen(),
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
        path: '/home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/add-charger',
        builder: (context, state) => const AddChargerScreen(),
      ),
      GoRoute(
        path: '/my-chargers',
        builder: (context, state) => const MyChargersScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
    ],
  );
});

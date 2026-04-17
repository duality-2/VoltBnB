import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/signup_screen.dart';
import '../../features/auth/providers/auth_provider.dart';

final routerProvider = Provider((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      // Check if user is authenticated
      final isAuthenticated = authState.value != null;

      // If not authenticated, redirect to login (unless already on auth pages)
      if (!isAuthenticated) {
        if (state.matchedLocation == '/login' ||
            state.matchedLocation == '/signup') {
          return null; // Stay on current page
        }
        return '/login';
      }

      // If authenticated but on login/signup, go to home
      if (state.matchedLocation == '/login' ||
          state.matchedLocation == '/signup') {
        return '/';
      }

      return null; // Allow navigation
    },
    routes: [
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
    ],
  );
});

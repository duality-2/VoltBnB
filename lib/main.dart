import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase (Assuming firebase_options.dart is generated later)
  // For now, catching exception to allow UI run if not configured.
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase init error: \$e');
  }

  runApp(
    const ProviderScope(
      child: VoltBnBApp(),
    ),
  );
}

class VoltBnBApp extends ConsumerWidget {
  const VoltBnBApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'VoltBnB',
      theme: AppTheme.lightTheme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}

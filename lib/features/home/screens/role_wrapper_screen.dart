import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/user_provider.dart';
import 'renter_main_screen.dart';
import 'host_main_screen.dart';

class RoleWrapperScreen extends ConsumerWidget {
  const RoleWrapperScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserModelProvider);

    return userAsync.when(
      data: (user) {
        if (user == null) return const Scaffold(body: Center(child: Text('User not found')));
        
        if (user.role == 'host') {
          return const HostMainScreen();
        } else {
          return const RenterMainScreen();
        }
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, stack) => Scaffold(body: Center(child: Text('Error loading user role: $err'))),
    );
  }
}

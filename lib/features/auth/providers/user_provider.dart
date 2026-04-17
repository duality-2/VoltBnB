import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import 'auth_provider.dart';
import '../../../core/providers/firebase_service_provider.dart';

/// Shared provider for the current user's Firestore model.
/// Used by RoleWrapperScreen, ProfileScreen, and anywhere else
/// that needs the full UserModel.
final currentUserModelProvider = FutureProvider<UserModel?>((ref) async {
  final user = ref.watch(userProvider);
  if (user == null) return null;
  return ref.read(userServiceProvider).getUser(user.uid);
});

/// Provider to fetch current user data from Firestore
final currentUserDataProvider = FutureProvider<UserModel?>((ref) async {
  final authUser = ref.watch(userProvider);
  if (authUser == null) return null;

  final userService = ref.watch(userServiceProvider);
  return userService.getUser(authUser.uid);
});

/// Provider for user stream (real-time updates)
final userStreamProvider = StreamProvider<UserModel?>((ref) {
  final authUser = ref.watch(userProvider);
  if (authUser == null) return const Stream.empty();

  return ref
      .watch(firebaseFirestoreProvider)
      .collection('users')
      .doc(authUser.uid)
      .snapshots()
      .map((snapshot) {
        if (!snapshot.exists || snapshot.data() == null) return null;
        return UserModel.fromMap(snapshot.data()!, snapshot.id);
      });
});


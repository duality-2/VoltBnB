import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/charger_service.dart';
import '../models/charger_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/services/user_service.dart';
import '../../../core/providers/firebase_service_provider.dart';

final chargerServiceProvider = Provider<ChargerService>((ref) {
  return ChargerService(ref.watch(firebaseFirestoreProvider));
});

final userServiceProvider = Provider<UserService>((ref) {
  return UserService(ref.watch(firebaseFirestoreProvider));
});

final hostChargersProvider = StreamProvider<List<ChargerModel>>((ref) {
  final user = ref.watch(userProvider);
  if (user == null) return const Stream.empty();

  final service = ref.watch(chargerServiceProvider);
  return service.getHostChargers(user.uid);
});

final availableChargersProvider = StreamProvider<List<ChargerModel>>((ref) {
  return ref.watch(chargerServiceProvider).getAvailableChargers();
});

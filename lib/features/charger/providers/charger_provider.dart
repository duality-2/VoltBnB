import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/charger_service.dart';
import '../models/charger_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/providers/firebase_service_provider.dart';
import 'charger_filter_provider.dart';

final chargerServiceProvider = Provider<ChargerService>((ref) {
  return ChargerService(ref.watch(firebaseFirestoreProvider));
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

final chargerByIdProvider = StreamProvider.family<ChargerModel?, String>((
  ref,
  id,
) {
  return ref.watch(chargerServiceProvider).getChargerStream(id);
});

final filteredChargersProvider = StreamProvider<List<ChargerModel>>((ref) {
  final filter = ref.watch(chargerFilterProvider);
  return ref.watch(chargerServiceProvider).getFilteredChargers(filter);
});

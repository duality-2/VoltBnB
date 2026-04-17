import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/booking_service.dart';
import '../models/booking_model.dart';
import '../../auth/providers/auth_provider.dart';

final bookingServiceProvider = Provider<BookingService>((ref) {
  return BookingService(FirebaseFirestore.instance);
});

final renterBookingsProvider = StreamProvider<List<BookingModel>>((ref) {
  final user = ref.watch(userProvider);
  if (user == null) return const Stream.empty();
  return ref.watch(bookingServiceProvider).getRenterBookings(user.uid);
});

final hostBookingsProvider = StreamProvider<List<BookingModel>>((ref) {
  final user = ref.watch(userProvider);
  if (user == null) return const Stream.empty();
  return ref.watch(bookingServiceProvider).getHostBookings(user.uid);
});

final chargerBookingsProvider =
    StreamProvider.family<List<BookingModel>, String>((ref, chargerId) {
      return ref.watch(bookingServiceProvider).getChargerBookings(chargerId);
    });

class BookingNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() {
    return const AsyncValue.data(null);
  }

  Future<void> createPendingBooking(BookingModel booking) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await ref.read(bookingServiceProvider).createBooking(booking);
    });
  }

  Future<void> confirmBooking(String bookingId, String paymentId) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(bookingServiceProvider)
          .updateBookingStatus(bookingId, 'confirmed', paymentId: paymentId);
    });
  }

  Future<void> updateBookingStatus(String bookingId, String status) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(bookingServiceProvider)
          .updateBookingStatus(bookingId, status);
    });
  }

  Future<void> cancelPendingBooking(String bookingId) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await ref.read(bookingServiceProvider).deleteBooking(bookingId);
    });
  }
}

final bookingNotifierProvider =
    NotifierProvider<BookingNotifier, AsyncValue<void>>(BookingNotifier.new);

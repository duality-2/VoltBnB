import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A provider that emits the current [DateTime] every minute.
/// Useful for triggering UI rebuilds for time-sensitive status transitions
/// (e.g., Upcoming -> Active) without requiring Firestore updates.
final currentTimeProvider = StreamProvider<DateTime>((ref) {
  // Emit the first value immediately
  final controller = StreamController<DateTime>();
  controller.add(DateTime.now());

  // Update every 60 seconds
  final timer = Timer.periodic(const Duration(seconds: 60), (timer) {
    controller.add(DateTime.now());
  });

  ref.onDispose(() {
    timer.cancel();
    controller.close();
  });

  return controller.stream;
});

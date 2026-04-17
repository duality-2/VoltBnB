import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:skeletonizer/skeletonizer.dart';
import '../providers/booking_provider.dart';
import '../models/booking_model.dart';
import '../../charger/providers/charger_provider.dart';

class RenterBookingsScreen extends ConsumerWidget {
  const RenterBookingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsAsync = ref.watch(renterBookingsProvider);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Bookings'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Upcoming'),
              Tab(text: 'Active'),
              Tab(text: 'Past'),
            ],
          ),
        ),
        body: bookingsAsync.when(
          data: (bookings) {
            final now = DateTime.now();
            final upcoming = bookings
                .where(
                  (b) => b.startTime.isAfter(now) && b.status != 'cancelled',
                )
                .toList();
            final active = bookings
                .where(
                  (b) =>
                      b.startTime.isBefore(now) &&
                      b.endTime.isAfter(now) &&
                      b.status != 'cancelled',
                )
                .toList();
            final past = bookings
                .where(
                  (b) => b.endTime.isBefore(now) || b.status == 'cancelled',
                )
                .toList();

            return TabBarView(
              children: [
                _BookingList(bookings: upcoming),
                _BookingList(bookings: active),
                _BookingList(bookings: past),
              ],
            );
          },
          loading: () => Skeletonizer(
            enabled: true,
            child: ListView.builder(
              itemCount: 3,
              padding: const EdgeInsets.all(16),
              itemBuilder: (context, index) => const Card(
                margin: EdgeInsets.only(bottom: 12),
                child: SizedBox(height: 120),
              ),
            ),
          ),
          error: (err, stack) =>
              Center(child: Text('Error loading bookings: $err')),
        ),
      ),
    );
  }
}

class _BookingList extends StatelessWidget {
  final List<BookingModel> bookings;
  const _BookingList({required this.bookings});

  @override
  Widget build(BuildContext context) {
    if (bookings.isEmpty)
      return const Center(child: Text('No bookings found.'));

    return ListView.builder(
      itemCount: bookings.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final booking = bookings[index];

        Color statusColor = Colors.grey;
        if (booking.status == 'confirmed' || booking.status == 'completed') {
          statusColor = const Color(0xFF1DB954);
        }
        if (booking.status == 'active') {
          statusColor = Colors.blue;
        }
        if (booking.status == 'cancelled') {
          statusColor = Colors.red;
        }

        return BookingCard(booking: booking, statusColor: statusColor);
      },
    );
  }
}

class BookingCard extends ConsumerWidget {
  final BookingModel booking;
  final Color statusColor;

  const BookingCard({
    super.key,
    required this.booking,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chargerAsync = ref.watch(chargerByIdProvider(booking.chargerUid));

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('MMM dd, yyyy').format(booking.startTime),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Chip(
                  label: Text(
                    booking.status.toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                  ),
                  backgroundColor: statusColor,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 8),
            chargerAsync.when(
              data: (charger) => Text(
                charger?.name ?? 'Unknown Charger',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              loading: () => const Skeletonizer(
                enabled: true,
                child: Text(
                  'Loading charger...',
                  style: TextStyle(fontSize: 16),
                ),
              ),
              error: (err, stack) => const Text(
                'Charger info unavailable',
                style: TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${DateFormat("hh:mm a").format(booking.startTime)} - ${DateFormat("hh:mm a").format(booking.endTime)}',
            ),
            const SizedBox(height: 8),
            Text(
              'Total: \$${booking.totalAmount.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

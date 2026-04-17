import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class RenterBookingsScreen extends ConsumerWidget {
  const RenterBookingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Mock data for frontend preview
    final now = DateTime.now();
    final upcoming = [
      _MockBooking('1', 'Supercharger Station SF', now.add(const Duration(days: 1)), now.add(const Duration(days: 1, hours: 2)), 25.0, 'confirmed'),
    ];
    final active = <_MockBooking>[];
    final past = [
      _MockBooking('2', 'Downtown Fast Charge', now.subtract(const Duration(days: 5)), now.subtract(const Duration(days: 5, hours: 1)), 15.0, 'completed'),
      _MockBooking('3', 'Mall Parking Charger', now.subtract(const Duration(days: 10)), now.subtract(const Duration(days: 10, hours: 3)), 30.0, 'cancelled'),
    ];

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
        body: TabBarView(
          children: [
            _BookingList(bookings: upcoming),
            _BookingList(bookings: active),
            _BookingList(bookings: past),
          ],
        ),
      ),
    );
  }
}

class _BookingList extends StatelessWidget {
  final List<_MockBooking> bookings;
  const _BookingList({required this.bookings});

  @override
  Widget build(BuildContext context) {
    if (bookings.isEmpty) return const Center(child: Text('No bookings found.'));

    return ListView.builder(
      itemCount: bookings.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final booking = bookings[index];
        
        Color statusColor = Colors.grey;
        if (booking.status == 'confirmed' || booking.status == 'completed') statusColor = const Color(0xFF1DB954);
        if (booking.status == 'active') statusColor = Colors.blue;
        if (booking.status == 'cancelled') statusColor = Colors.red;

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
                      label: Text(booking.status.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 10)),
                      backgroundColor: statusColor,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(booking.chargerName, style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 4),
                Text('\${DateFormat("hh:mm a").format(booking.startTime)} - \${DateFormat("hh:mm a").format(booking.endTime)}'),
                const SizedBox(height: 8),
                Text('Total: \$ \${booking.totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MockBooking {
  final String id;
  final String chargerName;
  final DateTime startTime;
  final DateTime endTime;
  final double totalAmount;
  final String status;

  _MockBooking(this.id, this.chargerName, this.startTime, this.endTime, this.totalAmount, this.status);
}

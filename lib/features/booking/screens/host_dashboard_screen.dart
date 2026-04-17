import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class HostDashboardScreen extends ConsumerWidget {
  const HostDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Mock Data for Host Dashboard
    final today = DateTime.now();
    final todayBookings = [
      _MockHostBooking(
        '1',
        'Alice',
        today.add(const Duration(hours: 1)),
        today.add(const Duration(hours: 3)),
        30.0,
        'confirmed',
      ),
      _MockHostBooking(
        '2',
        'Bob',
        today.add(const Duration(hours: 5)),
        today.add(const Duration(hours: 6)),
        15.0,
        'confirmed',
      ),
    ];
    // final totalEarnings = 450.50; // Mock past earnings

    return Scaffold(
      appBar: AppBar(title: const Text('Host Dashboard')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: const Color(0xFF1DB954),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  const Text(
                    'Total Earnings',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '\$ 450.50',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            "Today's Bookings",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          if (todayBookings.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('No bookings for today.'),
            ),
          ...todayBookings.map(
            (b) => Card(
              child: ListTile(
                leading: const Icon(Icons.bolt, color: Color(0xFF1DB954)),
                title: Text('\${b.renterName}'),
                subtitle: Text(
                  '\${DateFormat("hh:mm a").format(b.startTime)} - \${DateFormat("hh:mm a").format(b.endTime)}\\n\$ \${b.totalAmount.toStringAsFixed(2)}',
                ),
                isThreeLine: true,
                trailing: Chip(
                  label: Text(
                    b.status.toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                  ),
                  backgroundColor: b.status == 'confirmed'
                      ? const Color(0xFF1DB954)
                      : Colors.grey,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MockHostBooking {
  final String id;
  final String renterName;
  final DateTime startTime;
  final DateTime endTime;
  final double totalAmount;
  final String status;

  _MockHostBooking(
    this.id,
    this.renterName,
    this.startTime,
    this.endTime,
    this.totalAmount,
    this.status,
  );
}

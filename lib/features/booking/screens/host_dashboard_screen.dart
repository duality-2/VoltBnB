import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/booking_provider.dart';
import '../models/booking_model.dart';

class HostDashboardScreen extends ConsumerWidget {
  const HostDashboardScreen({super.key});

  void _startSession(
    BuildContext context,
    WidgetRef ref,
    BookingModel booking,
  ) async {
    final db = FirebaseDatabase.instance.ref();

    // 1. Initialize Realtime DB Session
    await db.child('sessions/${booking.id}').set({
      'startedAt': DateTime.now().toIso8601String(),
      'elapsedSeconds': 0,
      'kwhDelivered': 0.0,
      'hostUid': booking.hostUid,
      'renterUid': booking.renterUid,
      'status': 'active',
    });

    // 2. Update Firestore Status
    await ref
        .read(bookingNotifierProvider.notifier)
        .updateBookingStatus(booking.id, 'active');

    // 3. Navigate to Live Session
    if (context.mounted) {
      context.push('/live-session', extra: booking);
    }
  }

  void _updateBookingStatus(
    WidgetRef ref,
    String bookingId,
    String status,
  ) async {
    await ref
        .read(bookingNotifierProvider.notifier)
        .updateBookingStatus(bookingId, status);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsAsync = ref.watch(hostBookingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Host Dashboard')),
      body: bookingsAsync.when(
        data: (bookings) {
          final now = DateTime.now();
          final todayBookings = bookings.where((b) {
            return b.startTime.year == now.year &&
                b.startTime.month == now.month &&
                b.startTime.day == now.day;
          }).toList();

          final totalEarnings = bookings
              .where((b) => b.status == 'confirmed' || b.status == 'completed')
              .fold(
                0.0,
                (sum, item) => sum + (item.slotFee + (item.energyFee * 0.85)),
              );

          // Prepare Chart Data
          final last7Days = List.generate(
            7,
            (index) => now.subtract(Duration(days: 6 - index)),
          );
          final chartData = last7Days.map((day) {
            final dayTotal = bookings
                .where(
                  (b) =>
                      (b.status == 'confirmed' || b.status == 'completed') &&
                      b.startTime.year == day.year &&
                      b.startTime.month == day.month &&
                      b.startTime.day == day.day,
                )
                .fold(
                  0.0,
                  (sum, item) => sum + (item.slotFee + (item.energyFee * 0.85)),
                );
            return dayTotal;
          }).toList();

          final maxDayTotal = chartData.isEmpty
              ? 100.0
              : chartData.reduce((curr, next) => curr > next ? curr : next) +
                    20;

          return ListView(
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
                      Text(
                        '\$${totalEarnings.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          // Payout logic
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Payout requested!')),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF1DB954),
                        ),
                        child: const Text('Request Payout'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                "Earnings (Last 7 Days)",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 200,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: maxDayTotal,
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (double value, TitleMeta meta) {
                            final date = last7Days[value.toInt()];
                            return SideTitleWidget(
                              meta: meta,
                              child: Text(
                                DateFormat('E').format(date),
                                style: const TextStyle(fontSize: 10),
                              ),
                            );
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    gridData: FlGridData(show: false),
                    barGroups: chartData.asMap().entries.map((e) {
                      return BarChartGroupData(
                        x: e.key,
                        barRods: [
                          BarChartRodData(
                            toY: e.value,
                            color: const Color(0xFF1DB954),
                            width: 16,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ],
                      );
                    }).toList(),
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
                    title: Text('Renter: ${b.renterUid}'),
                    subtitle: Text(
                      '${DateFormat("hh:mm a").format(b.startTime)} - ${DateFormat("hh:mm a").format(b.endTime)}\n\$${b.totalAmount.toStringAsFixed(2)}',
                    ),
                    isThreeLine: true,
                    trailing: b.status == 'pending'
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.check_circle,
                                  color: Color(0xFF1DB954),
                                ),
                                onPressed: () => _updateBookingStatus(
                                  ref,
                                  b.id,
                                  'confirmed',
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.cancel,
                                  color: Colors.red,
                                ),
                                onPressed: () =>
                                    _updateBookingStatus(ref, b.id, 'rejected'),
                              ),
                            ],
                          )
                        : (b.status == 'confirmed' &&
                                  b.startTime.isBefore(
                                    DateTime.now().add(
                                      const Duration(minutes: 15),
                                    ),
                                  )
                              ? ElevatedButton(
                                  onPressed: () =>
                                      _startSession(context, ref, b),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1DB954),
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('Start Session'),
                                )
                              : Chip(
                                  label: Text(
                                    b.status.toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                    ),
                                  ),
                                  backgroundColor:
                                      b.status == 'confirmed' ||
                                          b.status == 'completed'
                                      ? const Color(0xFF1DB954)
                                      : (b.status == 'active'
                                            ? Colors.blue
                                            : Colors.grey),
                                )),
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Skeletonizer(
          enabled: true,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (err, stack) =>
            Center(child: Text('Error loading dashboard: $err')),
      ),
    );
  }
}

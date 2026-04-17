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
      appBar: AppBar(
        title: const Text('Host Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded),
            onPressed: () => context.push('/host-notifications'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: bookingsAsync.when(
        data: (bookings) {
          final now = DateTime.now();
          final todayBookings = bookings.where((b) {
            return b.startTime.year == now.year &&
                b.startTime.month == now.month &&
                b.startTime.day == now.day;
          }).toList();

          final totalEarnings = bookings
              .where((b) => b.status == 'confirmed' || b.status == 'completed' || b.status == 'active')
              .fold(0.0, (sum, item) => sum + (item.slotFee + (item.energyFee * 0.85)));

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
                .fold(0.0, (sum, item) => sum + (item.slotFee + (item.energyFee * 0.85)));
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
                color: const Color(0xFF111827),
                child: Padding(
                  padding: const EdgeInsets.all(28.0),
                  child: Column(
                    children: [
                      Text(
                        'AVAILABLE BALANCE',
                        style: GoogleFonts.inter(
                          color: Colors.white.withValues(alpha: 0.6), 
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '₹${totalEarnings.toStringAsFixed(0)}',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Payout requested!')),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF22C55E),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Request Payout',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
               Text(
                "Earnings (Last 7 Days)",
                style: GoogleFonts.inter(
                  fontSize: 18, 
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF111827),
                ),
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
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF6B7280),
                                ),
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
                            color: const Color(0xFF22C55E),
                            width: 14,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 24),
               Text(
                "Today's Bookings",
                style: GoogleFonts.inter(
                  fontSize: 18, 
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 16),
              if (todayBookings.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('No bookings for today.'),
                ),
              ...todayBookings.map(
                (b) => Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.bolt_rounded, color: Color(0xFF22C55E)),
                      ),
                      title: Text(
                        'Renter: ${b.renterUid.substring(0, 8)}',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        '${DateFormat("hh:mm a").format(b.startTime)} - ${DateFormat("hh:mm a").format(b.endTime)}\n₹${b.totalAmount.toStringAsFixed(0)}',
                        style: GoogleFonts.inter(color: const Color(0xFF6B7280), fontSize: 13),
                      ),
                      isThreeLine: true,
                      trailing: b.status == 'awaiting_approval'
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.check_circle,
                                  color: Color(0xFF1DB954),
                                ),
                                onPressed: () => ref.read(bookingNotifierProvider.notifier).confirmBooking(b.id),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.cancel,
                                  color: Colors.red,
                                ),
                                onPressed: () => _updateBookingStatus(
                                  ref,
                                  b.id,
                                  'rejected',
                                ),
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
                                    backgroundColor: const Color(0xFF111827),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    minimumSize: const Size(0, 36),
                                  ),
                                  child: Text(
                                    'Start',
                                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                                  ),
                                )
                              : Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: (b.status == 'confirmed' || b.status == 'completed') 
                                        ? const Color(0xFFDCFCE7) 
                                        : (b.status == 'active' ? const Color(0xFFDBEAFE) : const Color(0xFFF3F4F6)),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    b.status.toUpperCase(),
                                    style: GoogleFonts.inter(
                                      color: (b.status == 'confirmed' || b.status == 'completed') 
                                          ? const Color(0xFF15803D) 
                                          : (b.status == 'active' ? const Color(0xFF1E40AF) : const Color(0xFF6B7280)),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
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

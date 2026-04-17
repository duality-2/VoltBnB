import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:go_router/go_router.dart';
import '../providers/booking_provider.dart';
import '../models/booking_model.dart';
import '../../charger/providers/charger_provider.dart';
import '../../../core/providers/timer_provider.dart';
import 'review_dialog.dart';

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
          bottom: TabBar(
            labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
            unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 14),
            indicatorColor: const Color(0xFF22C55E),
            labelColor: const Color(0xFF22C55E),
            unselectedLabelColor: const Color(0xFF6B7280),
            indicatorWeight: 3,
            tabs: const [
              Tab(text: 'Upcoming'),
              Tab(text: 'Active'),
              Tab(text: 'Past'),
            ],
          ),
        ),
        body: bookingsAsync.when(
          data: (bookings) {
            final now = ref.watch(currentTimeProvider).value ?? DateTime.now();
            final upcoming = bookings
                .where(
                  (b) => b.startTime.isAfter(now) && b.status != 'cancelled' && b.status != 'completed',
                )
                .toList();
            final active = bookings
                .where(
                  (b) =>
                      (b.startTime.isBefore(now) && b.endTime.isAfter(now) && b.status != 'cancelled' && b.status != 'completed') ||
                      b.status == 'active',
                )
                .toList();
            final past = bookings
                .where(
                  (b) => b.endTime.isBefore(now) || b.status == 'cancelled' || b.status == 'completed',
                )
                .toList();

            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(renterBookingsProvider);
              },
              child: TabBarView(
                children: [
                  _BookingList(bookings: upcoming),
                  _BookingList(bookings: active),
                  _BookingList(bookings: past),
                ],
              ),
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
    if (bookings.isEmpty) {
      return const Center(child: Text('No bookings found.'));
    }

    return ListView.builder(
      itemCount: bookings.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final booking = bookings[index];

        Color backgroundColor = const Color(0xFFF3F4F6);
        Color textColor = const Color(0xFF4B5563);

        if (booking.status == 'confirmed' || booking.status == 'completed') {
          backgroundColor = const Color(0xFFDCFCE7);
          textColor = const Color(0xFF15803D);
        }
        if (booking.status == 'active') {
          backgroundColor = const Color(0xFFDBEAFE);
          textColor = const Color(0xFF1E40AF);
        }
        if (booking.status == 'cancelled') {
          backgroundColor = const Color(0xFFFEE2E2);
          textColor = const Color(0xFF991B1B);
        }

        return BookingCard(
          booking: booking, 
          statusColor: textColor,
          statusBg: backgroundColor,
        );
      },
    );
  }
}

class BookingCard extends ConsumerWidget {
  final BookingModel booking;
  final Color statusColor;
  final Color statusBg;

  const BookingCard({
    super.key,
    required this.booking,
    required this.statusColor,
    required this.statusBg,
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
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF111827),
                    fontSize: 15,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    booking.status.toUpperCase(),
                    style: GoogleFonts.inter(
                      color: statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            chargerAsync.when(
              data: (charger) => Text(
                charger?.name ?? 'Unknown Charger',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF374151),
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
              style: GoogleFonts.inter(
                color: const Color(0xFF6B7280),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Total Paid: ₹${booking.totalAmount.toStringAsFixed(0)}',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                color: const Color(0xFF111827),
                fontSize: 15,
              ),
            ),
            if (booking.status == 'active') ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () =>
                      context.push('/live-session', extra: booking),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF111827),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'View Live Session',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
            if (booking.status == 'completed') ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => ReviewDialog(booking: booking),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFE5E7EB)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Leave a Review',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF374151),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

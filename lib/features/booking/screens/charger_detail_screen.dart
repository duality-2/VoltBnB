import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../charger/models/charger_model.dart';
import '../models/booking_model.dart';
import '../providers/booking_provider.dart';
import '../../auth/providers/auth_provider.dart';

class ChargerDetailScreen extends ConsumerStatefulWidget {
  final ChargerModel charger;
  const ChargerDetailScreen({super.key, required this.charger});

  @override
  ConsumerState<ChargerDetailScreen> createState() =>
      _ChargerDetailScreenState();
}

class _ChargerDetailScreenState extends ConsumerState<ChargerDetailScreen> {
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  double _durationHours = 1.0;
  late Razorpay _razorpay;
  String? _pendingBookingId;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    if (_pendingBookingId != null) {
      await ref
          .read(bookingNotifierProvider.notifier)
          .confirmBooking(_pendingBookingId!, response.paymentId ?? '');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment Successful! Booking Confirmed.')),
      );
      context.pop(); // Go back to previous screen
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) async {
    if (_pendingBookingId != null) {
      await ref
          .read(bookingNotifierProvider.notifier)
          .cancelPendingBooking(_pendingBookingId!);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Payment Failed: ${response.message}')),
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('External Wallet Selected: ${response.walletName}'),
      ),
    );
  }

  Future<void> _startBooking() async {
    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select date and time')),
      );
      return;
    }

    final user = ref.read(userProvider);
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please login to book')));
      return;
    }

    final subtotal = widget.charger.pricePerHour * _durationHours;
    final totalAmount = subtotal + (subtotal * 0.05);

    final startTime = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );
    final endTime = startTime.add(Duration(minutes: (_durationHours * 60).toInt()));

    if (startTime.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot book a time slot in the past')),
      );
      return;
    }

    // OVERLAP VALIDATION
    final existingBookings = ref.read(chargerBookingsProvider(widget.charger.id)).value;
    if (existingBookings != null) {
      final hasOverlap = existingBookings.any((b) {
        if (b.status == 'cancelled' || b.status == 'pending') return false; // Ignore cancelled/pending
        // Overlap condition: Start1 < End2 AND End1 > Start2
        return startTime.isBefore(b.endTime) && endTime.isAfter(b.startTime);
      });

      if (hasOverlap) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Time slot overlaps with an existing booking. Please select another time.')),
        );
        return;
      }
    }

    final bookingId = const Uuid().v4();
    _pendingBookingId = bookingId;

    final booking = BookingModel(
      id: bookingId,
      renterUid: user.uid,
      chargerUid: widget.charger.id,
      hostUid: widget.charger.hostUid,
      startTime: startTime,
      endTime: endTime,
      durationHours: _durationHours,
      totalAmount: totalAmount,
      status: 'pending',
      paymentId: '',
      createdAt: DateTime.now(),
    );

    await ref
        .read(bookingNotifierProvider.notifier)
        .createPendingBooking(booking);

    // TODO: Ensure you use actual test key id
    var options = {
      'key': dotenv.env['RAZORPAY_TEST_KEY'] ?? 'rzp_test_YOUR_KEY_HERE',
      'amount': (totalAmount * 100).toInt(),
      'name': 'VoltBnB',
      'description': '${widget.charger.title} - ${_durationHours}h',
      'prefill': {'contact': '', 'email': user.email ?? ''},
      'notes': {'bookingId': bookingId},
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final subtotal = widget.charger.pricePerHour * _durationHours;
    final serviceFee = subtotal * 0.05;
    final totalAmount = subtotal + serviceFee;
    final bookingsAsync = ref.watch(chargerBookingsProvider(widget.charger.id));

    return Scaffold(
      appBar: AppBar(title: Text(widget.charger.title)),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 250,
              child: widget.charger.photos.isNotEmpty
                  ? PageView.builder(
                      itemCount: widget.charger.photos.length,
                      itemBuilder: (context, index) {
                        return CachedNetworkImage(
                          imageUrl: widget.charger.photos[index],
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Colors.grey.shade200,
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.broken_image),
                          ),
                        );
                      },
                    )
                  : Container(
                      color: Colors.grey.shade200,
                      child: const Icon(
                        Icons.ev_station,
                        size: 80,
                        color: Colors.grey,
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.charger.title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        color: Colors.grey,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          widget.charger.address,
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Amenities',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: widget.charger.amenities
                        .map((a) => Chip(label: Text(a)))
                        .toList(),
                  ),
                  const Divider(height: 32),
                  const Text(
                    'Book Time Slot',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.calendar_today),
                          label: Text(
                            _selectedDate == null
                                ? 'Select Date'
                                : DateFormat(
                                    'MMM dd, yyyy',
                                  ).format(_selectedDate!),
                          ),
                          onPressed: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(
                                const Duration(days: 30),
                              ),
                            );
                            if (date != null) {
                              setState(() => _selectedDate = date);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.access_time),
                          label: Text(
                            _selectedTime == null
                                ? 'Select Time'
                                : _selectedTime!.format(context),
                          ),
                          onPressed: () async {
                            final time = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay.now(),
                            );
                            if (time != null) {
                              setState(() => _selectedTime = time);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Duration (Hours)'),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: _durationHours > 0.5
                                ? () => setState(() => _durationHours -= 0.5)
                                : null,
                          ),
                          Text(
                            '\${_durationHours}h',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: () =>
                                setState(() => _durationHours += 0.5),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const Text(
                    'Availability',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  bookingsAsync.when(
                    data: (bookings) {
                      final upcomingBookings = bookings
                          .where((b) => b.endTime.isAfter(DateTime.now()))
                          .toList();
                      if (upcomingBookings.isEmpty) {
                        return const Text(
                          'No upcoming bookings. Fully available!',
                        );
                      }
                      return Column(
                        children: upcomingBookings
                            .map(
                              (b) => ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(
                                  Icons.event_busy,
                                  color: Colors.orange,
                                ),
                                title: Text(
                                  DateFormat('MMM dd').format(b.startTime),
                                ),
                                subtitle: Text(
                                  '${DateFormat.jm().format(b.startTime)} - ${DateFormat.jm().format(b.endTime)}',
                                ),
                                trailing: const Text(
                                  'Booked',
                                  style: TextStyle(color: Colors.orange),
                                ),
                              ),
                            )
                            .toList(),
                      );
                    },
                    loading: () => const CircularProgressIndicator(),
                    error: (err, stack) =>
                        Text('Error loading availability: $err'),
                  ),
                  const Divider(height: 32),
                  const Text(
                    'Price Breakdown',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '\$${widget.charger.pricePerHour.toStringAsFixed(2)} x $_durationHours hours',
                      ),
                      Text('\$${subtotal.toStringAsFixed(2)}'),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Service Fee (5%)'),
                      Text('\$${serviceFee.toStringAsFixed(2)}'),
                    ],
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '\$${totalAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _startBooking,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1DB954),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Book Now',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

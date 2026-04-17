import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../charger/models/charger_model.dart';
import '../../charger/providers/charger_provider.dart';
import '../models/booking_model.dart';
import '../providers/booking_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/utils/razorpay_web_stub.dart'
    if (dart.library.js_util) '../../../core/utils/razorpay_web_gate.dart'
    as web_payment;

class ChargerDetailScreen extends ConsumerStatefulWidget {
  final ChargerModel charger;
  const ChargerDetailScreen({super.key, required this.charger});

  @override
  ConsumerState<ChargerDetailScreen> createState() =>
      _ChargerDetailScreenState();
}

class _ChargerDetailScreenState extends ConsumerState<ChargerDetailScreen> {
  DateTime? _selectedDate;
  String? _selectedSlot;
  Razorpay? _razorpay;
  String? _pendingBookingId;

  // Fixed slot reservation fee
  final double slotFee = 30.0;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    if (!kIsWeb) {
      _razorpay = Razorpay();
      _razorpay?.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
      _razorpay?.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
      _razorpay?.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    }
  }

  @override
  void dispose() {
    _razorpay?.clear();
    super.dispose();
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    if (_pendingBookingId != null) {
      await ref
          .read(bookingNotifierProvider.notifier)
          .requestApproval(_pendingBookingId!, response.paymentId ?? '');
      if (!mounted) return;

      final user = ref.read(userProvider);
      final timeParts = _selectedSlot!.split(' - ');
      final startTimeOfDay = _parseTime(timeParts[0]);
      final endTimeOfDay = _parseTime(timeParts[1]);

      final startTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        startTimeOfDay.hour,
        startTimeOfDay.minute,
      );
      final endTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        endTimeOfDay.hour,
        endTimeOfDay.minute,
      );

      final booking = BookingModel(
        id: _pendingBookingId!,
        renterUid: user?.uid ?? '',
        chargerUid: widget.charger.id,
        hostUid: widget.charger.hostId,
        slot: _selectedSlot!,
        date: _selectedDate!,
        slotFee: slotFee,
        energyFee: 0.0,
        totalAmount: slotFee, // Paid slot fee
        status: 'confirmed',
        paymentId: response.paymentId ?? '',
        createdAt: DateTime.now(),
        startTime: startTime,
        endTime: endTime,
      );

      context.pushReplacement(
        '/booking-success',
        extra: {'booking': booking, 'charger': widget.charger},
      );
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

  TimeOfDay _parseTime(String timeStr) {
    // Handle '10:00 AM' or '10:00PM' with any space character (Web uses U+202F)
    final match = RegExp(
      r'(\d+):(\d+)\s*(AM|PM)',
      caseSensitive: false,
    ).firstMatch(timeStr.replaceAll('\u202F', ' ').replaceAll('\u00A0', ' '));
    if (match != null) {
      int hour = int.parse(match.group(1)!);
      int minute = int.parse(match.group(2)!);
      final period = match.group(3)!.toUpperCase();
      if (period == 'PM' && hour < 12) hour += 12;
      if (period == 'AM' && hour == 12) hour = 0;
      return TimeOfDay(hour: hour, minute: minute);
    }
    return const TimeOfDay(hour: 0, minute: 0);
  }

  Future<void> _startBooking() async {
    if (_selectedDate == null || _selectedSlot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select date and a time slot')),
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

    final timeParts = _selectedSlot!.split(' - ');
    final startTimeOfDay = _parseTime(timeParts[0]);
    final endTimeOfDay = _parseTime(timeParts[1]);

    final startTime = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      startTimeOfDay.hour,
      startTimeOfDay.minute,
    );
    final endTime = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      endTimeOfDay.hour,
      endTimeOfDay.minute,
    );

    if (startTime.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot book a time slot in the past')),
      );
      return;
    }

    // Temporary 5-min lock
    final lockedUntil = Timestamp.fromDate(
      DateTime.now().add(const Duration(minutes: 5)),
    );

    final bookingsList =
        ref.read(chargerBookingsProvider(widget.charger.id)).value ?? [];
    bool isSelectedOccupied = false;
    int selectedQueueSize = 0;

    for (var b in bookingsList) {
      if (b.date.year == _selectedDate!.year &&
          b.date.month == _selectedDate!.month &&
          b.date.day == _selectedDate!.day &&
          b.slot == _selectedSlot) {
        if (['confirmed', 'active', 'completed'].contains(b.status))
          isSelectedOccupied = true;
        if (b.status == 'pending' &&
            b.lockedUntil != null &&
            b.lockedUntil!.toDate().isAfter(DateTime.now()))
          isSelectedOccupied = true;
        if (['queued', 'confirmed', 'active'].contains(b.status))
          selectedQueueSize++;
      }
    }

    final bookingId = const Uuid().v4();
    _pendingBookingId = bookingId;

    final booking = BookingModel(
      id: bookingId,
      renterUid: user.uid,
      chargerUid: widget.charger.id,
      hostUid: widget.charger.hostId,
      slot: _selectedSlot!,
      date: _selectedDate!,
      slotFee: slotFee,
      energyFee: 0.0,
      totalAmount: slotFee,
      status: isSelectedOccupied ? 'queued' : 'pending',
      paymentId: '',
      createdAt: DateTime.now(),
      startTime: startTime,
      endTime: endTime,
      lockedUntil: isSelectedOccupied ? null : lockedUntil,
      queuePosition: isSelectedOccupied ? selectedQueueSize + 1 : null,
      estimatedSessionStart: isSelectedOccupied
          ? DateTime.now().add(Duration(minutes: (selectedQueueSize + 1) * 30))
          : null,
    );

    await ref
        .read(bookingNotifierProvider.notifier)
        .createPendingBooking(booking);

    // If joining queue, no payment required right now
    if (isSelectedOccupied) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Successfully joined the queue!')),
      );
      context.pushReplacement(
        '/booking-success',
        extra: {'booking': booking, 'charger': widget.charger},
      );
      return;
    }

    if (kIsWeb) {
      final webOptions = {
        'key': dotenv.env['RAZORPAY_TEST_KEY'] ?? 'rzp_test_YOUR_KEY_HERE',
        'amount': (slotFee * 100).round(), // Ensure integer
        'currency': 'INR', // Explicit currency for Web
        'name': 'VoltBnB',
        'description': 'Slot Fee: ${_selectedSlot}',
        'prefill': {
          'contact': user.phoneNumber ?? '9999999999',
          'email': user.email ?? '',
        },
        'notes': {'bookingId': bookingId},
      };

      try {
        web_payment.openRazorpayWeb(
          options: jsonEncode(webOptions),
          onSuccess: (paymentId) async {
            if (_pendingBookingId != null) {
              await ref
                  .read(bookingNotifierProvider.notifier)
                  .requestApproval(_pendingBookingId!, paymentId);
              if (!mounted) return;
              context.pushReplacement(
                '/booking-success',
                extra: {'booking': booking, 'charger': widget.charger},
              );
            }
          },
          onFailure: (error) {
            if (!mounted) return;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Payment failed: $error')));
          },
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Web Payment Error: $e')));
      }
      return;
    }

    var options = {
      'key': dotenv.env['RAZORPAY_TEST_KEY'] ?? 'rzp_test_YOUR_KEY_HERE',
      'amount': (slotFee * 100).round(),
      'currency': 'INR',
      'name': 'VoltBnB',
      'description': 'Slot Fee: ${_selectedSlot}',
      'prefill': {
        'contact': user.phoneNumber ?? '9999999999',
        'email': user.email ?? '',
      },
      'notes': {'bookingId': bookingId},
    };

    try {
      _razorpay?.open(options);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Payment failed: $e')));
    }
  }

  void _rerouteToAlternative() async {
    final allChargersAsync = await ref.read(availableChargersProvider.future);
    final alternative = allChargersAsync
        .where((c) => c.id != widget.charger.id)
        .firstOrNull;
    if (alternative != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Rerouting to ${alternative.name}...')),
      );
      context.pushReplacement('/charger/${alternative.id}');
    } else {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No alternatives found nearby.')),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bookingsAsync = ref.watch(chargerBookingsProvider(widget.charger.id));

    // Simulated available slots if host did not set any
    final dynamicSlots = widget.charger.availableSlots.isNotEmpty
        ? widget.charger.availableSlots
        : [
            '09:00 AM - 10:00 AM',
            '10:00 AM - 11:00 AM',
            '11:00 AM - 12:00 PM',
            '01:00 PM - 02:00 PM',
          ];

    return Scaffold(
      appBar: AppBar(title: Text(widget.charger.name)),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 250,
              child: widget.charger.photos.isNotEmpty
                  ? ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: widget.charger.photos.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 4),
                      itemBuilder: (context, index) => CachedNetworkImage(
                        imageUrl: widget.charger.photos[index],
                        fit: BoxFit.cover,
                        width: MediaQuery.of(context).size.width,
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
                      ),
                    )
                  : widget.charger.imageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: widget.charger.imageUrl!,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: Colors.grey.shade200,
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.broken_image),
                      ),
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          widget.charger.name,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Chip(
                        backgroundColor:
                            widget.charger.healthStatus == 'Excellent'
                            ? Colors.green.shade100
                            : Colors.orange.shade100,
                        label: Text(
                          widget.charger.healthStatus,
                          style: TextStyle(
                            color: widget.charger.healthStatus == 'Excellent'
                                ? Colors.green.shade800
                                : Colors.orange.shade800,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
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
                  if ((widget.charger.description ?? '').isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(widget.charger.description!),
                  ],
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () =>
                        context.push('/charger/${widget.charger.id}/reviews'),
                    icon: const Icon(Icons.rate_review_outlined),
                    label: Text('See Reviews (${widget.charger.reviewCount})'),
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
                  OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today),
                    label: Text(
                      _selectedDate == null
                          ? 'Select Date'
                          : DateFormat('MMM dd, yyyy').format(_selectedDate!),
                    ),
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 30)),
                      );
                      if (date != null) {
                        setState(() {
                          _selectedDate = date;
                          _selectedSlot = null; // reset slot selection
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Available Slots',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  bookingsAsync.when(
                    data: (bookings) {
                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: dynamicSlots.map((slotString) {
                          bool isLockedOrBooked = false;

                          if (_selectedDate != null) {
                            for (var b in bookings) {
                              if (b.date.year == _selectedDate!.year &&
                                  b.date.month == _selectedDate!.month &&
                                  b.date.day == _selectedDate!.day &&
                                  b.slot == slotString) {
                                // Check if active/confirmed/completed
                                if ([
                                  'confirmed',
                                  'active',
                                  'completed',
                                ].contains(b.status)) {
                                  isLockedOrBooked = true;
                                  break;
                                }
                                // Check if pending lock is still valid
                                if (b.status == 'pending' &&
                                    b.lockedUntil != null) {
                                  if (b.lockedUntil!.toDate().isAfter(
                                    DateTime.now(),
                                  )) {
                                    isLockedOrBooked = true;
                                    break;
                                  }
                                }
                              }
                            }
                          }

                          final isSelected = _selectedSlot == slotString;

                          return ChoiceChip(
                            label: Text(slotString),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                _selectedSlot = selected ? slotString : null;
                              });
                            },
                            backgroundColor: isLockedOrBooked
                                ? Colors.orange.shade100
                                : null,
                            selectedColor: isLockedOrBooked
                                ? Colors.orange.shade300
                                : const Color(0xFF1DB954).withAlpha(80),
                            labelStyle: TextStyle(
                              color: isLockedOrBooked
                                  ? Colors.deepOrange
                                  : (isSelected
                                        ? const Color(0xFF1DB954)
                                        : Colors.black),
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          );
                        }).toList(),
                      );
                    },
                    loading: () => const CircularProgressIndicator(),
                    error: (err, stack) =>
                        Text('Error loading availability: $err'),
                  ),

                  if (_selectedSlot != null) ...[
                    const Divider(height: 32),
                    const Text(
                      'Booking Summary',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Builder(
                      builder: (context) {
                        final bookingsList = bookingsAsync.value ?? [];
                        bool isOccupied = false;
                        int queueSize = 0;

                        for (var b in bookingsList) {
                          if (b.date.year == _selectedDate!.year &&
                              b.date.month == _selectedDate!.month &&
                              b.date.day == _selectedDate!.day &&
                              b.slot == _selectedSlot) {
                            if ([
                              'confirmed',
                              'active',
                              'completed',
                            ].contains(b.status))
                              isOccupied = true;
                            if (b.status == 'pending' &&
                                b.lockedUntil != null &&
                                b.lockedUntil!.toDate().isAfter(DateTime.now()))
                              isOccupied = true;
                            if ([
                              'queued',
                              'confirmed',
                              'active',
                            ].contains(b.status))
                              queueSize++;
                          }
                        }

                        if (isOccupied) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.orange.shade200,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    const Row(
                                      children: [
                                        Icon(
                                          Icons.warning_amber_rounded,
                                          color: Colors.orange,
                                        ),
                                        SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Slot is Currently Occupied',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Wait time is approximately ${(queueSize) * 30} mins. Join virtually to be notified when available!',
                                      style: TextStyle(
                                        color: Colors.orange.shade900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                height: 50,
                                child: ElevatedButton.icon(
                                  onPressed: _startBooking,
                                  icon: const Icon(Icons.group_add),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  label: Text(
                                    'Join Virtual Queue (Pos: ${queueSize + 1})',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                height: 50,
                                child: OutlinedButton.icon(
                                  onPressed: _rerouteToAlternative,
                                  icon: const Icon(Icons.directions),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.deepPurple,
                                    side: const BorderSide(
                                      color: Colors.deepPurple,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  label: const Text(
                                    'Reroute to Nearby Alternate',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.blue.shade100),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Slot Reservation Fee (Pay Now)',
                                      ),
                                      Text(
                                        'Γé╣${slotFee.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Estimated Energy Cost (Pay Later)',
                                      ),
                                      Text(
                                        '~Γé╣${widget.charger.pricePerHour.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  const Row(
                                    children: [
                                      Icon(
                                        Icons.info_outline,
                                        size: 16,
                                        color: Colors.blue,
                                      ),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Your slot is secured for 5 minutes after booking initiation.',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.blue,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              height: 50,
                              child: ElevatedButton(
                                onPressed: _startBooking,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1DB954),
                                  disabledBackgroundColor: Colors.grey.shade300,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  'Confirm & Pay Reservation Fee',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
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

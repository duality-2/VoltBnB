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

  // Base slot reservation fee
  final double _baseSlotFee = 30.0;

  double get _currentSlotFee {
    if (_selectedSlot == null) return _baseSlotFee;

    final timeParts = _selectedSlot!.split(' - ');
    final startTimeOfDay = _parseTime(timeParts[0]);
    final hour = startTimeOfDay.hour;

    for (var rule in widget.charger.pricingRules) {
      if (rule.startHour <= hour && rule.endHour > hour) {
        return (_baseSlotFee * rule.multiplier);
      }
      // Handle overnight ranges (e.g. 22:00 to 05:00)
      if (rule.startHour > rule.endHour) {
        if (hour >= rule.startHour || hour < rule.endHour) {
          return (_baseSlotFee * rule.multiplier);
        }
      }
    }
    return _baseSlotFee;
  }

  String? get _activePriceLabel {
    if (_selectedSlot == null) return null;

    final timeParts = _selectedSlot!.split(' - ');
    final startTimeOfDay = _parseTime(timeParts[0]);
    final hour = startTimeOfDay.hour;

    for (var rule in widget.charger.pricingRules) {
      if (rule.startHour <= hour && rule.endHour > hour) {
        return rule.label.toUpperCase();
      }
      if (rule.startHour > rule.endHour) {
        if (hour >= rule.startHour || hour < rule.endHour) {
          return rule.label.toUpperCase();
        }
      }
    }
    return null;
  }

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
          .confirmBooking(_pendingBookingId!, response.paymentId ?? '');
      if (!mounted) return;

      final user = ref.read(userProvider);
      final timeParts = _selectedSlot!.split(' - ');
      final startTimeOfDay = _parseTime(timeParts[0]);
      final endTimeOfDay = _parseTime(timeParts[1]);

      final startTime = DateTime(
        _selectedDate!.year, _selectedDate!.month, _selectedDate!.day,
        startTimeOfDay.hour, startTimeOfDay.minute,
      );
      final endTime = DateTime(
        _selectedDate!.year, _selectedDate!.month, _selectedDate!.day,
        endTimeOfDay.hour, endTimeOfDay.minute,
      );

      final booking = BookingModel(
        id: _pendingBookingId!,
        renterUid: user?.uid ?? '',
        chargerUid: widget.charger.id,
        hostUid: widget.charger.hostId,
        slot: _selectedSlot!,
        date: _selectedDate!,
        slotFee: _currentSlotFee,
        energyFee: 0.0, 
        totalAmount: _currentSlotFee, // Paid slot fee
        status: 'confirmed',
        paymentId: response.paymentId ?? '',
        createdAt: DateTime.now(),
        startTime: startTime,
        endTime: endTime,
      );

      context.pushReplacement('/booking-success', extra: {
        'booking': booking,
        'charger': widget.charger,
      });
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
    final match = RegExp(r'(\d+):(\d+)\s*(AM|PM)', caseSensitive: false)
        .firstMatch(timeStr.replaceAll('\u202F', ' ').replaceAll('\u00A0', ' '));
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
      _selectedDate!.year, _selectedDate!.month, _selectedDate!.day,
      startTimeOfDay.hour, startTimeOfDay.minute,
    );
    final endTime = DateTime(
      _selectedDate!.year, _selectedDate!.month, _selectedDate!.day,
      endTimeOfDay.hour, endTimeOfDay.minute,
    );

    if (startTime.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot book a time slot in the past')),
      );
      return;
    }

    // Temporary 5-min lock
    final lockedUntil = Timestamp.fromDate(DateTime.now().add(const Duration(minutes: 5)));

    final bookingId = const Uuid().v4();
    _pendingBookingId = bookingId;

    final booking = BookingModel(
      id: bookingId,
      renterUid: user.uid,
      chargerUid: widget.charger.id,
      hostUid: widget.charger.hostId,
      slot: _selectedSlot!,
      date: _selectedDate!,
      slotFee: _currentSlotFee,
      energyFee: 0.0,
      totalAmount: _currentSlotFee,
      status: 'pending',
      paymentId: '',
      createdAt: DateTime.now(),
      startTime: startTime,
      endTime: endTime,
      lockedUntil: lockedUntil,
    );

    await ref
        .read(bookingNotifierProvider.notifier)
        .createPendingBooking(booking);

    if (kIsWeb) {
      final webOptions = {
        'key': dotenv.env['RAZORPAY_TEST_KEY'] ?? 'rzp_test_YOUR_KEY_HERE',
        'amount': (_currentSlotFee * 100).round(), // Ensure integer
        'currency': 'INR', // Explicit currency for Web
        'name': 'VoltBnB',
        'description': 'Slot Fee: ${_selectedSlot}',
        'prefill': {
          'contact': user.phoneNumber ?? '9999999999',
          'email': user.email ?? ''
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
                  .confirmBooking(_pendingBookingId!, paymentId);
              if (!mounted) return;
              context.pushReplacement('/booking-success', extra: {
                'booking': booking,
                'charger': widget.charger,
              });
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
      'amount': (_currentSlotFee * 100).round(),
      'currency': 'INR',
      'name': 'VoltBnB',
      'description': 'Slot Fee: ${_selectedSlot}',
      'prefill': {
        'contact': user.phoneNumber ?? '9999999999',
        'email': user.email ?? ''
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

  @override
  Widget build(BuildContext context) {
    final bookingsAsync = ref.watch(chargerBookingsProvider(widget.charger.id));

    // Simulated available slots if host did not set any
    final dynamicSlots = widget.charger.availableSlots.isNotEmpty
        ? widget.charger.availableSlots
        : ['09:00 AM - 10:00 AM', '10:00 AM - 11:00 AM', '11:00 AM - 12:00 PM', '01:00 PM - 02:00 PM'];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          widget.charger.name,
          style: GoogleFonts.inter(
            color: const Color(0xFF111827),
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF111827)),
          onPressed: () => context.pop(),
        ),
      ),
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
                          style: GoogleFonts.inter(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF111827),
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: widget.charger.healthStatus == 'Excellent' 
                            ? const Color(0xFFDCFCE7) 
                            : const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          widget.charger.healthStatus.toUpperCase(),
                          style: GoogleFonts.inter(
                            color: widget.charger.healthStatus == 'Excellent' 
                              ? const Color(0xFF166534) 
                              : const Color(0xFF92400E),
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                            letterSpacing: 0.5,
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
                          style: GoogleFonts.inter(
                            color: const Color(0xFF6B7280),
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if ((widget.charger.description ?? '').isNotEmpty) ...[
                    const SizedBox(height: 8),
                      Text(
                        widget.charger.description!,
                        style: GoogleFonts.inter(
                          height: 1.5,
                          color: const Color(0xFF374151),
                          fontSize: 15,
                        ),
                      ),
                  ],
                  const SizedBox(height: 8),
                    onPressed: () =>
                        context.push('/charger/${widget.charger.id}/reviews'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF22C55E),
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(Icons.star_outline, size: 18),
                    label: Text(
                      'See Reviews (${widget.charger.reviewCount})',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Amenities',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: widget.charger.amenities
                        .map((a) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: Text(
                            a,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF374151),
                            ),
                          ),
                        ))
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
                        lastDate: DateTime.now().add(
                          const Duration(days: 30),
                        ),
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
                                if (['confirmed', 'active', 'completed'].contains(b.status)) {
                                  isLockedOrBooked = true;
                                  break;
                                }
                                // Check if pending lock is still valid
                                if (b.status == 'pending' && b.lockedUntil != null) {
                                  if (b.lockedUntil!.toDate().isAfter(DateTime.now())) {
                                    isLockedOrBooked = true;
                                    break;
                                  }
                                }
                              }
                            }
                          }
                          
                          final isSelected = _selectedSlot == slotString;

                          return ChoiceChip(
                            label: Text(
                              slotString,
                              style: GoogleFonts.inter(
                                color: isLockedOrBooked 
                                  ? const Color(0xFF9CA3AF) 
                                  : (isSelected ? Colors.white : const Color(0xFF374151)),
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                fontSize: 13,
                              ),
                            ),
                            selected: isSelected,
                            onSelected: isLockedOrBooked ? null : (selected) {
                              setState(() {
                                _selectedSlot = selected ? slotString : null;
                              });
                            },
                            backgroundColor: isLockedOrBooked ? const Color(0xFFF3F4F6) : Colors.white,
                            selectedColor: const Color(0xFF22C55E),
                            showCheckmark: false,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: isSelected 
                                  ? const Color(0xFF22C55E) 
                                  : const Color(0xFFE5E7EB),
                                width: 1.5,
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                    loading: () => const CircularProgressIndicator(),
                    error: (err, stack) => Text('Error loading availability: $err'),
                  ),
                  
                  if (_selectedSlot != null) ...[
                    const Divider(height: 32),
                    const Text(
                      'Booking Summary',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFBBF7D0), width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF22C55E).withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Column(
                        children: [
                               Row(
                                children: [
                                  Text(
                                    'Reservation Fee',
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w500,
                                      color: const Color(0xFF166534),
                                    ),
                                  ),
                                  if (_activePriceLabel != null) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: _currentSlotFee > _baseSlotFee 
                                          ? const Color(0xFFFECACA) 
                                          : const Color(0xFFDCFCE7),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        _activePriceLabel!,
                                        style: GoogleFonts.inter(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          color: _currentSlotFee > _baseSlotFee 
                                            ? const Color(0xFF991B1B) 
                                            : const Color(0xFF166534),
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              Text(
                                '₹${_currentSlotFee.toStringAsFixed(2)}', 
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700, 
                                  fontSize: 18,
                                  color: const Color(0xFF111827),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Est. Energy Cost',
                                style: GoogleFonts.inter(
                                  color: const Color(0xFF6B7280),
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                '~₹${widget.charger.pricePerHour.toStringAsFixed(0)} /hr', 
                                style: GoogleFonts.inter(
                                  color: const Color(0xFF6B7280),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                           Row(
                            children: [
                              const Icon(Icons.security_rounded, size: 16, color: Color(0xFF059669)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Slot secured for 5 mins after starting.',
                                  style: GoogleFonts.inter(
                                    fontSize: 12, 
                                    color: const Color(0xFF059669),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _selectedSlot != null ? _startBooking : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF111827),
                        disabledBackgroundColor: const Color(0xFFE5E7EB),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        'Book & Pay ₹${_currentSlotFee.toStringAsFixed(0)}',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
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

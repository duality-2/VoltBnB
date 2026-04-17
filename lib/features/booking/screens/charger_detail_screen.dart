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
import 'package:google_fonts/google_fonts.dart';

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
          .requestApproval(_pendingBookingId!, response.paymentId ?? '');
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
        status: 'awaiting_approval',
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

    final bookingsList = ref.read(chargerBookingsProvider(widget.charger.id)).value ?? [];
    bool isSelectedOccupied = false;
    int selectedQueueSize = 0;
    
    for (var b in bookingsList) {
       if (b.date.year == _selectedDate!.year &&
           b.date.month == _selectedDate!.month &&
           b.date.day == _selectedDate!.day &&
           b.slot == _selectedSlot) {
           if (['confirmed', 'active', 'completed'].contains(b.status)) isSelectedOccupied = true;
           if (b.status == 'pending' && b.lockedUntil != null && b.lockedUntil!.toDate().isAfter(DateTime.now())) isSelectedOccupied = true;
           if (['queued', 'confirmed', 'active'].contains(b.status)) selectedQueueSize++;
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
      slotFee: _currentSlotFee,
      energyFee: 0.0,
      totalAmount: _currentSlotFee,
      status: isSelectedOccupied ? 'queued' : 'pending',
      paymentId: '',
      createdAt: DateTime.now(),
      startTime: startTime,
      endTime: endTime,
      lockedUntil: isSelectedOccupied ? null : lockedUntil,
      queuePosition: isSelectedOccupied ? selectedQueueSize + 1 : null,
      estimatedSessionStart: isSelectedOccupied ? DateTime.now().add(Duration(minutes: (selectedQueueSize + 1) * 30)) : null,
    );

    await ref
        .read(bookingNotifierProvider.notifier)
        .createPendingBooking(booking);

    // If joining queue, no payment required right now
    if (isSelectedOccupied) {
       if (!mounted) return;
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Successfully joined the queue!')));
       context.pushReplacement('/booking-success', extra: {
         'booking': booking,
         'charger': widget.charger,
       });
       return;
    }

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
                  .requestApproval(_pendingBookingId!, paymentId);
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

  void _
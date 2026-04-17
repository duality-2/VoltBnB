import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import '../models/booking_model.dart';
import '../providers/booking_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../charger/providers/charger_provider.dart';
import 'package:google_fonts/google_fonts.dart';

class LiveSessionScreen extends ConsumerStatefulWidget {
  final BookingModel booking;
  const LiveSessionScreen({super.key, required this.booking});

  @override
  ConsumerState<LiveSessionScreen> createState() => _LiveSessionScreenState();
}

class _LiveSessionScreenState extends ConsumerState<LiveSessionScreen> {
  final _db = FirebaseDatabase.instance.ref();
  StreamSubscription<DatabaseEvent>? _sessionSubscription;
  Map<dynamic, dynamic>? _sessionData;
  Object? _sessionError;
  bool _isEnding = false;
  bool _hapticFired = false;

  @override
  void initState() {
    super.initState();
    _startOrJoinSessionMock();
    _sessionSubscription = _db.child('sessions/${widget.booking.id}').onValue.listen(
      (event) {
        if (!mounted) return;
        setState(() {
          _sessionData = event.snapshot.value as Map<dynamic, dynamic>?;
          _sessionError = null;
        });
      },
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _sessionError = error;
          _sessionData = null;
        });
      },
    );
  }

  Future<void> _startOrJoinSessionMock() async {
    // If we're the driver and navigating here from QR Check-in Mock, we ensure the session is initialized in RTDB
    final snapshot = await _db.child('sessions/${widget.booking.id}').get();
    if (!snapshot.exists) {
      await _db.child('sessions/${widget.booking.id}').set({
        'startedAt': DateTime.now().toIso8601String(),
        'elapsedSeconds': 0,
        'kwhDelivered': 0.0,
        'hostUid': widget.booking.hostUid,
        'renterUid': widget.booking.renterUid,
        'status': 'active',
      });
      // Start a mock incrementer just for the demo
      _runMockDemoIncrement();
    } else {
      // If host started it, joining should also be okay
      if (snapshot.child('status').value == 'active') {
          _runMockDemoIncrement(); // just in case it's not running
      }
    }
  }

  void _runMockDemoIncrement() {
    // Demo mode: Increment elapsedSeconds by 60 every 1 second, kwh by 0.5
    Timer.periodic(const Duration(seconds: 1), (timer) async {
       if (!mounted || _isEnding) {
         timer.cancel();
         return;
       }
       final refData = await _db.child('sessions/${widget.booking.id}').get();
       final data = refData.value as Map<dynamic, dynamic>?;
       if (data != null && data['status'] == 'active') {
          int elapsed = data['elapsedSeconds'] ?? 0;
          double kwh = (data['kwhDelivered'] ?? 0.0).toDouble();
          await _db.child('sessions/${widget.booking.id}').update({
            'elapsedSeconds': elapsed + 60,
            'kwhDelivered': kwh + 0.1,
          });
       } else {
         timer.cancel();
       }
    });
  }

  @override
  void dispose() {
    _sessionSubscription?.cancel();
    super.dispose();
  }

  Future<void> _endSession(Map<dynamic, dynamic> sessionData) async {
    setState(() => _isEnding = true);
    try {
      final kwhDelivered = (sessionData['kwhDelivered'] ?? 0.0).toDouble();
      
      double pricePerKwh = 10.0; // Default fallback
      final chargerData = await ref.read(chargerByIdProvider(widget.booking.chargerUid).future);
      if (chargerData != null) {
        pricePerKwh = chargerData.pricePerHour.toDouble(); 
        // Note: we use pricePerHour to roughly mean price per kwh for this demo flow.
      }

      final energyFee = kwhDelivered * pricePerKwh;
      final totalAmount = widget.booking.slotFee + energyFee;

      // 1. Update RTDB status
      await _db.child('sessions/${widget.booking.id}').update({
        'status': 'ended',
        'endedAt': DateTime.now().toIso8601String(),
      });

      // 2. Update Firestore booking status
      await FirebaseFirestore.instance.collection('bookings').doc(widget.booking.id).update({
        'status': 'completed',
        'energyFee': energyFee,
        'totalAmount': totalAmount,
        'kWhConsumed': kwhDelivered,
        'sessionEndTime': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Charging Session Completed & Billed!')));
        // Let it naturally show the completed state instead of popping instantly.
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error ending session: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isEnding = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Deep navy dark mode
      appBar: AppBar(
        title: Text(
          'Live Charging',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Builder(
        builder: (context) {
          if (_sessionError != null) {
            return Center(
              child: Text(
              child: Text(
                'Error: $_sessionError',
                style: GoogleFonts.inter(color: const Color(0xFFEF4444)),
              ),
            );
          }

          if (_sessionData == null) {
            return const Center(
              child: Text(
              child: Text(
                'Connecting to Charger...',
                style: GoogleFonts.inter(
                  color: Colors.white60,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          }

          final data = _sessionData!;
          final status = data['status'] ?? 'pending';
          final elapsedSeconds = data['elapsedSeconds'] ?? 0;
          final kwhDelivered = (data['kwhDelivered'] ?? 0.0).toDouble();

          final totalDurationSeconds = 3600; // 1 hr mock
          final remainingSeconds = totalDurationSeconds - elapsedSeconds;
          final progress = (elapsedSeconds / totalDurationSeconds).clamp(0.0, 1.0);

          if (remainingSeconds <= 600 && !_hapticFired && status == 'active') {
            HapticFeedback.heavyImpact();
            _hapticFired = true;
          }

          if (status == 'ended') {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF22C55E).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_circle_rounded, color: Color(0xFF22C55E), size: 80),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Charging Complete',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 32),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Energy Consumed', style: GoogleFonts.inter(color: Colors.white60)),
                            Text('${kwhDelivered.toStringAsFixed(1)} kWh', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('CO2 Offset', style: GoogleFonts.inter(color: Colors.white60)),
                            Text('${(kwhDelivered * 0.4).toStringAsFixed(2)} kg', style: GoogleFonts.inter(color: const Color(0xFF22C55E), fontWeight: FontWeight.w700)),
                          ],
                        ),
                        const Divider(height: 32, color: Colors.white10),
                        Text(
                          'Payment processed automatically',
                          style: GoogleFonts.inter(color: Colors.white38, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 48),
                  SizedBox(
                    width: 200,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: () => context.go('/'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF0F172A),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(100),
                        ),
                      ),
                      child: Text(
                        'Back to Home',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                      ),
                    ),
                  )
                ],
              ),
            );
          }

          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 260,
                      height: 260,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF22C55E).withValues(alpha: 0.15),
                            blurRadius: 40,
                            spreadRadius: 5,
                          )
                        ],
                      ),
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 14,
                        backgroundColor: Colors.white.withValues(alpha: 0.05),
                        color: const Color(0xFF22C55E),
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${kwhDelivered.toStringAsFixed(1)}',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 56,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -2,
                          ),
                        ),
                        Text(
                          'kWh DELIVERED',
                          style: GoogleFonts.inter(
                            color: Colors.white54,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(
                            '${(remainingSeconds ~/ 60)}m left',
                            style: GoogleFonts.inter(
                              color: Colors.white70,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 60),
                Text(
                  'Powering your journey...',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF22C55E),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 40),
                // Both Host and Driver can stop the session
                SizedBox(
                  width: 240,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _isEnding ? null : () => _endSession(data),
                    icon: _isEnding
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.stop_rounded),
                    label: Text(
                      'End Session',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444).withValues(alpha: 0.1),
                      foregroundColor: const Color(0xFFEF4444),
                      surfaceTintColor: Colors.transparent,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(100),
                        side: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

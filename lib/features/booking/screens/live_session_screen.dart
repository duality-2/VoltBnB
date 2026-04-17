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
      appBar: AppBar(
        title: const Text('Live Charging Session'),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.black87,
      body: Builder(
        builder: (context) {
          if (_sessionError != null) {
            return Center(
              child: Text(
                'Error: $_sessionError',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          if (_sessionData == null) {
            return const Center(
              child: Text(
                'Connecting to Charger...',
                style: TextStyle(color: Colors.white70),
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
                  const Icon(Icons.check_circle, color: Color(0xFF1DB954), size: 80),
                  const SizedBox(height: 16),
                  const Text(
                    'Session Completed',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Card(
                    color: Colors.white12,
                    margin: const EdgeInsets.symmetric(horizontal: 32),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Text('Energy Consumed: ${kwhDelivered.toStringAsFixed(2)} kWh', style: const TextStyle(color: Colors.white70, fontSize: 16)),
                          const SizedBox(height: 8),
                          Text('CO2 Saved: ${(kwhDelivered * 0.4).toStringAsFixed(2)} kg', style: const TextStyle(color: Colors.greenAccent, fontSize: 16)),
                          const SizedBox(height: 16),
                          const Text('Energy Fee billed to saved card', style: TextStyle(color: Colors.white54, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () => context.go('/'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                    ),
                    child: const Text('Back to Home'),
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
                    SizedBox(
                      width: 250,
                      height: 250,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 12,
                        backgroundColor: Colors.white12,
                        color: const Color(0xFF1DB954),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${kwhDelivered.toStringAsFixed(2)} kWh',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${(remainingSeconds ~/ 60).toString().padLeft(2, '0')}:${(remainingSeconds % 60).toString().padLeft(2, '0')} remaining',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 60),
                const Text(
                  'Charging in progress...',
                  style: TextStyle(
                    color: Color(0xFF1DB954),
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 40),
                // Both Host and Driver can stop the session
                ElevatedButton.icon(
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
                      : const Icon(Icons.stop),
                  label: const Text('Stop Session'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    textStyle: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
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

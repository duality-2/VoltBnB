import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import '../models/booking_model.dart';
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
       } else if (data != null && data['status'] == 'ended' && data['isIdling'] == true) {
          int idleSecs = data['idleSeconds'] ?? 0;
          double currentIdleFee = (data['idleFee'] ?? 0.0).toDouble();
          
          bool shouldNudge = idleSecs >= 300 && data['nudgeSent'] != true;
          if (shouldNudge) {
             // Mock sending a nudge (in a real app, this triggers a push notification)
             await FirebaseFirestore.instance.collection('bookings').doc(widget.booking.id).update({
                'nudgeSent': true,
             });
             await FirebaseFirestore.instance.collection('notifications').add({
                'userUid': widget.booking.renterUid,
                'title': 'Car Idling Warning!',
                'body': 'Your session ended 5 minutes ago. Please move your car to avoid idle fees.',
                'type': 'nudge',
                'createdAt': FieldValue.serverTimestamp(),
                'read': false,
             });
          }
          
          // Accrue fee after 5 mins of idling (e.g., Rs 5 per minute mock)
          if (idleSecs >= 300) {
            currentIdleFee += 5.0;
          }

          await _db.child('sessions/${widget.booking.id}').update({
            'idleSeconds': idleSecs + 60,
            'idleFee': currentIdleFee,
            'nudgeSent': data['nudgeSent'] == true || shouldNudge,
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

      // 1. Update RTDB status to track idling
      await _db.child('sessions/${widget.booking.id}').update({
        'status': 'ended',
        'endedAt': DateTime.now().toIso8601String(),
        'isIdling': true,
        'idleSeconds': 0,
        'idleFee': 0.0,
      });

      // 2. Update Firestore booking status
      await FirebaseFirestore.instance.collection('bookings').doc(widget.booking.id).update({
        'status': 'completed',
        'energyFee': energyFee,
        'totalAmount': totalAmount,
        'kWhConsumed': kwhDelivered,
        'sessionEndTime': FieldValue.serverTimestamp(),
        'isIdling': true, 
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

  Future<void> _leaveCharger(Map<dynamic, dynamic> sessionData) async {
    try {
      final idleFee = (sessionData['idleFee'] ?? 0.0).toDouble();
      
      await _db.child('sessions/${widget.booking.id}').update({
         'isIdling': false,
      });
      await FirebaseFirestore.instance.collection('bookings').doc(widget.booking.id).update({
         'isIdling': false,
         'idleFee': idleFee,
      });
      if (mounted) {
         context.go('/');
      }
    } catch (e) {
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
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
            final isIdling = data['isIdling'] == true;
            final idleSeconds = data['idleSeconds'] ?? 0;
            final idleFee = (data['idleFee'] ?? 0.0).toDouble();
            final nudgeSent = data['nudgeSent'] == true;

            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(isIdling ? Icons.warning_amber_rounded : Icons.check_circle, 
                       color: isIdling ? Colors.orange : const Color(0xFF1DB954), 
                       size: 80),
                  const SizedBox(height: 16),
                  Text(
                    isIdling ? 'Action Required' : 'Session Completed',
                    style: TextStyle(
                      color: isIdling ? Colors.orange : Colors.white,
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
                          if (isIdling) ...[
                            const Divider(color: Colors.white24),
                            const Text('Please unplug and move your car safely.', style: TextStyle(color: Colors.orangeAccent)),
                            if (nudgeSent)
                               const Text('Nudge Notification Sent!', style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                            Text('Idle Time: ${(idleSeconds ~/ 60)} min', style: const TextStyle(color: Colors.white70)),
                            if (idleFee > 0)
                               Text('Idle Fee Accrued: Γé╣${idleFee.toStringAsFixed(2)}', style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 16),
                          ],
                          const Text('Energy Fee billed to saved card', style: TextStyle(color: Colors.white54, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  if (isIdling)
                    ElevatedButton.icon(
                      onPressed: () => _leaveCharger(data),
                      icon: const Icon(Icons.directions_car),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                      label: const Text('I have moved my car'),
                    )
                  else
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

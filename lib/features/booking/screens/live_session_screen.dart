import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import '../models/booking_model.dart';
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
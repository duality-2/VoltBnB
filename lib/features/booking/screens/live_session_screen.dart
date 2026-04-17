import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import '../models/booking_model.dart';
import '../providers/booking_provider.dart';
import '../../auth/providers/auth_provider.dart';

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

  @override
  void dispose() {
    _sessionSubscription?.cancel();
    super.dispose();
  }

  Future<void> _endSession(Map<dynamic, dynamic> sessionData) async {
    setState(() => _isEnding = true);
    try {
      // 1. Update RTDB status
      await _db.child('sessions/${widget.booking.id}').update({
        'status': 'ended',
        'endedAt': DateTime.now().toIso8601String(),
      });

      // 2. Update Firestore booking status
      await ref
          .read(bookingNotifierProvider.notifier)
          .updateBookingStatus(widget.booking.id, 'completed');

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Charging Session Ended')));
        context.pop();
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
                'Waiting for host to start session...',
                style: TextStyle(color: Colors.white70),
              ),
            );
          }

          final data = _sessionData!;
          final status = data['status'] ?? 'pending';
          final elapsedSeconds = data['elapsedSeconds'] ?? 0;
          final kwhDelivered = (data['kwhDelivered'] ?? 0.0).toDouble();

          final totalDurationSeconds = (widget.booking.durationHours * 3600).toInt();
          final remainingSeconds = totalDurationSeconds - elapsedSeconds;
          final progress = (elapsedSeconds / totalDurationSeconds).clamp(0.0, 1.0);

          if (remainingSeconds <= 600 && !_hapticFired && status == 'active') {
            HapticFeedback.heavyImpact();
            _hapticFired = true;
          }

          if (status == 'ended') {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, color: Color(0xFF1DB954), size: 80),
                  SizedBox(height: 16),
                  Text(
                    'Session Completed',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
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
                if (widget.booking.hostUid == ref.read(userProvider)?.uid)
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

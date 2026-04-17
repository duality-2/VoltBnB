import 'package:cloud_firestore/cloud_firestore.dart';

class BookingModel {
  final String id;
  final String renterUid;
  final String chargerUid; 
  final String hostUid;
  final String slot; // e.g., '10:00 AM - 11:00 AM'
  final DateTime date; // The specific date of the booking
  final double slotFee; // Fixed ₹30
  final double energyFee; // Calculated post-session
  final double totalAmount;
  final String status; // 'pending' | 'confirmed' | 'active' | 'completed' | 'cancelled' | 'rejected'
  final String paymentId;
  final DateTime createdAt;
  final DateTime startTime; // Represents exact start time of slot
  final DateTime endTime; // Represents exact end time of slot
  final DateTime? sessionStartTime;
  final DateTime? sessionEndTime;
  final double kWhConsumed;
  final Timestamp? lockedUntil; 

  BookingModel({
    required this.id,
    required this.renterUid,
    required this.chargerUid,
    required this.hostUid,
    required this.slot,
    required this.date,
    required this.slotFee,
    required this.energyFee,
    required this.totalAmount,
    required this.status,
    required this.paymentId,
    required this.createdAt,
    required this.startTime,
    required this.endTime,
    this.sessionStartTime,
    this.sessionEndTime,
    this.kWhConsumed = 0.0,
    this.lockedUntil,
  });

  factory BookingModel.fromMap(Map<String, dynamic> map, String documentId) {
    return BookingModel(
      id: documentId,
      renterUid: map['driverId'] ?? map['renterUid'] ?? '',
      chargerUid: map['chargerId'] ?? map['chargerUid'] ?? '',
      hostUid: map['hostId'] ?? map['hostUid'] ?? '',
      slot: map['slot'] ?? '',
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      slotFee: (map['slotFee'] ?? 30.0).toDouble(),
      energyFee: (map['energyFee'] ?? 0.0).toDouble(),
      totalAmount: (map['totalAmount'] ?? 0.0).toDouble(),
      status: map['status'] ?? 'pending',
      paymentId: map['paymentId'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      startTime: (map['startTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endTime: (map['endTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      sessionStartTime: (map['sessionStartTime'] as Timestamp?)?.toDate(),
      sessionEndTime: (map['sessionEndTime'] as Timestamp?)?.toDate(),
      kWhConsumed: (map['kWhConsumed'] ?? 0.0).toDouble(),
      lockedUntil: map['lockedUntil'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'driverId': renterUid, // using driverId for FB to match checklist
      'chargerId': chargerUid,
      'hostId': hostUid,
      'slot': slot,
      'date': Timestamp.fromDate(date),
      'slotFee': slotFee,
      'energyFee': energyFee,
      'totalAmount': totalAmount,
      'status': status,
      'paymentId': paymentId,
      'createdAt': Timestamp.fromDate(createdAt),
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'sessionStartTime': sessionStartTime != null ? Timestamp.fromDate(sessionStartTime!) : null,
      'sessionEndTime': sessionEndTime != null ? Timestamp.fromDate(sessionEndTime!) : null,
      'kWhConsumed': kWhConsumed,
      'lockedUntil': lockedUntil,
      
      // Fallback keys for legacy
      'renterUid': renterUid,
      'chargerUid': chargerUid,
      'hostUid': hostUid,
    };
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';

class BookingModel {
  final String id;
  final String renterUid;
  final String chargerUid; // Wait, prompt said chargerUid, likely means chargerId. I'll stick to what was provided or just use chargerId.
  final String hostUid;
  final DateTime startTime;
  final DateTime endTime;
  final double durationHours;
  final double totalAmount;
  final String status; // 'pending' | 'confirmed' | 'active' | 'completed' | 'cancelled'
  final String paymentId;
  final DateTime createdAt;

  BookingModel({
    required this.id,
    required this.renterUid,
    required this.chargerUid,
    required this.hostUid,
    required this.startTime,
    required this.endTime,
    required this.durationHours,
    required this.totalAmount,
    required this.status,
    required this.paymentId,
    required this.createdAt,
  });

  factory BookingModel.fromMap(Map<String, dynamic> map, String documentId) {
    return BookingModel(
      id: documentId,
      renterUid: map['renterUid'] ?? '',
      chargerUid: map['chargerUid'] ?? '',
      hostUid: map['hostUid'] ?? '',
      startTime: (map['startTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endTime: (map['endTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      durationHours: (map['durationHours'] ?? 0.0).toDouble(),
      totalAmount: (map['totalAmount'] ?? 0.0).toDouble(),
      status: map['status'] ?? 'pending',
      paymentId: map['paymentId'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'renterUid': renterUid,
      'chargerUid': chargerUid,
      'hostUid': hostUid,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'durationHours': durationHours,
      'totalAmount': totalAmount,
      'status': status,
      'paymentId': paymentId,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

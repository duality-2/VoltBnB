import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String name;
  final String email;
  final String? phone;
  final String? photoUrl;
  final String role; // 'host' | 'renter'
  final DateTime createdAt;
  final double walletBalance;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    this.phone,
    this.photoUrl,
    required this.role,
    required this.createdAt,
    required this.walletBalance,
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String documentId) {
    return UserModel(
      uid: documentId,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'],
      photoUrl: map['photoUrl'],
      role: map['role'] ?? 'renter',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      walletBalance: (map['walletBalance'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'photoUrl': photoUrl,
      'role': role,
      'createdAt': Timestamp.fromDate(createdAt),
      'walletBalance': walletBalance,
    };
  }
}

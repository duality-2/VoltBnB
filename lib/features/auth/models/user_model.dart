import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String name;
  final String email;
  final String? phone;
  final String? photoUrl;
  final String role; // 'host' | 'renter'
  final String? fcmToken;
  final DateTime createdAt;
  final double walletBalance;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    this.phone,
    this.photoUrl,
    required this.role,
    this.fcmToken,
    required this.createdAt,
    required this.walletBalance,
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String documentId) {
    DateTime parsedDate = DateTime.now();
    if (map['createdAt'] != null) {
      if (map['createdAt'] is Timestamp) {
        parsedDate = (map['createdAt'] as Timestamp).toDate();
      } else if (map['createdAt'] is String) {
        parsedDate = DateTime.parse(map['createdAt'] as String);
      }
    }

    return UserModel(
      uid: documentId,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'],
      photoUrl: map['photoUrl'],
      role: map['role'] ?? 'renter',
      fcmToken: map['fcmToken'],
      createdAt: parsedDate,
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
      'fcmToken': fcmToken,
      'createdAt': Timestamp.fromDate(createdAt),
      'walletBalance': walletBalance,
    };
  }

  UserModel copyWith({
    String? uid,
    String? name,
    String? email,
    String? phone,
    String? photoUrl,
    String? role,
    DateTime? createdAt,
    double? walletBalance,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      photoUrl: photoUrl ?? this.photoUrl,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      walletBalance: walletBalance ?? this.walletBalance,
    );
  }
}

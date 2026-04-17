class UserModel {
  final String id;
  final String email;
  final String? phone;
  final String? photoUrl;
  final String role; // 'host' | 'renter'
  final String? fcmToken;
  final String name;
  final String userType; // 'driver' or 'host'
  final DateTime createdAt;
  final DateTime? updatedAt;

  UserModel({
    required this.id,
    required this.email,
    this.phone,
    this.photoUrl,
    required this.role,
    this.fcmToken,
    required this.name,
    required this.userType,
    required this.createdAt,
    this.updatedAt,
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
      id: id,
      email: map['email'] ?? '',
      phone: map['phone'],
      photoUrl: map['photoUrl'],
      role: map['role'] ?? 'renter',
      fcmToken: map['fcmToken'],
      walletBalance: (map['walletBalance'] ?? 0.0).toDouble(),
      name: map['name'] ?? '',
      userType: map['userType'] ?? 'driver',
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'phone': phone,
      'photoUrl': photoUrl,
      'role': role,
      'fcmToken': fcmToken,
      'createdAt': Timestamp.fromDate(createdAt),
      'walletBalance': walletBalance,
      'name': name,
      'userType': userType,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
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

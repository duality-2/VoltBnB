class UserModel {
  final String uid;
  final String email;
  final String name;
  final String role; // 'host' or 'renter'
  final String authProvider;
  final bool passwordManagedByFirebase;
  final DateTime? passwordUpdatedAt;
  final String? photoUrl;
  final String? phone;
  final String? address;
  final String? fcmToken;
  final double walletBalance;
  final DateTime createdAt;
  final DateTime? updatedAt;

  UserModel({
    required this.uid,
    required this.email,
    required this.name,
    required this.role,
    this.authProvider = 'password',
    this.passwordManagedByFirebase = true,
    this.passwordUpdatedAt,
    this.photoUrl,
    this.phone,
    this.address,
    this.fcmToken,
    this.walletBalance = 0,
    required this.createdAt,
    this.updatedAt,
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    final rawRole = (map['role'] ?? map['userType'] ?? 'renter').toString();
    final normalizedRole = rawRole == 'driver' ? 'renter' : rawRole;

    return UserModel(
      uid: map['uid']?.toString() ?? id,
      email: map['email'] ?? '',
      name: map['name'] ?? '',
      role: normalizedRole,
      authProvider: map['authProvider']?.toString() ?? 'password',
      passwordManagedByFirebase: map['passwordManagedByFirebase'] == null
          ? true
          : map['passwordManagedByFirebase'] == true,
      passwordUpdatedAt: map['passwordUpdatedAt'] != null
          ? DateTime.tryParse(map['passwordUpdatedAt'].toString())
          : null,
      photoUrl: map['photoUrl'] ?? map['profileImageUrl'],
      phone: map['phone'] ?? map['phoneNumber'],
      address: map['address'],
      fcmToken: map['fcmToken'],
      walletBalance: (map['walletBalance'] ?? 0).toDouble(),
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      'role': role,
      'userType': role,
      'authProvider': authProvider,
      'passwordManagedByFirebase': passwordManagedByFirebase,
      'passwordUpdatedAt': passwordUpdatedAt?.toIso8601String(),
      'photoUrl': photoUrl,
      'profileImageUrl': photoUrl,
      'phone': phone,
      'phoneNumber': phone,
      'address': address,
      'fcmToken': fcmToken,
      'walletBalance': walletBalance,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  UserModel copyWith({
    String? uid,
    String? email,
    String? name,
    String? role,
    String? authProvider,
    bool? passwordManagedByFirebase,
    DateTime? passwordUpdatedAt,
    String? photoUrl,
    String? phone,
    String? address,
    String? fcmToken,
    double? walletBalance,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      name: name ?? this.name,
      role: role ?? this.role,
      authProvider: authProvider ?? this.authProvider,
      passwordManagedByFirebase:
          passwordManagedByFirebase ?? this.passwordManagedByFirebase,
      passwordUpdatedAt: passwordUpdatedAt ?? this.passwordUpdatedAt,
      photoUrl: photoUrl ?? this.photoUrl,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      fcmToken: fcmToken ?? this.fcmToken,
      walletBalance: walletBalance ?? this.walletBalance,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Backward-compatible aliases used in older widgets.
  String get id => uid;
  String get userType => role;
  String? get profileImageUrl => photoUrl;
  String? get phoneNumber => phone;
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';

class UserService {
  final FirebaseFirestore _firestore;

  UserService(this._firestore);

  /// Create a new user document in Firestore
  Future<void> createUser(UserModel user) async {
    try {
      await _firestore.collection('users').doc(user.id).set(user.toMap());
    } catch (e) {
      throw Exception('Failed to create user: $e');
    }
  }

  /// Get user by ID
  Future<UserModel?> getUser(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists && doc.data() != null) {
        return UserModel.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching user: $e');
      return null;
    }
  }

  /// Update user data
  Future<void> updateUser(String userId, Map<String, dynamic> data) async {
    data['updatedAt'] = DateTime.now().toIso8601String();
    await _firestore.collection('users').doc(userId).update(data);
  }

  /// Delete user
  Future<void> deleteUser(String userId) async {
    await _firestore.collection('users').doc(userId).delete();
  }

  /// Get all hosts (users with role = 'host')
  Future<List<UserModel>> getHosts() async {
    try {
      final roleSnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'host')
          .get();
      if (roleSnapshot.docs.isNotEmpty) {
        return roleSnapshot.docs
            .map((doc) => UserModel.fromMap(doc.data(), doc.id))
            .toList();
      }

      final legacySnapshot = await _firestore
          .collection('users')
          .where('userType', isEqualTo: 'host')
          .get();

      return legacySnapshot.docs
          .map((doc) => UserModel.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      debugPrint('Error fetching hosts: $e');
      return [];
    }
  }

  /// Stream of user data for real-time updates
  Stream<UserModel?> getUserStream(String userId) {
    return _firestore.collection('users').doc(userId).snapshots().map((doc) {
      if (doc.exists && doc.data() != null) {
        return UserModel.fromMap(doc.data()!, doc.id);
      }
      return null;
    });
  }

  /// Save FCM token to user document
  Future<void> saveFcmToken(String userId, String token) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'fcmToken': token,
        'updatedAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error saving FCM token: $e');
    }
  }
}

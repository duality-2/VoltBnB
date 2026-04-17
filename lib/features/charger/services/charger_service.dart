import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/charger_model.dart';
import '../providers/charger_filter_provider.dart';

class ChargerService {
  final FirebaseFirestore _firestore;

  ChargerService(this._firestore);

  /// Create a new charger
  Future<String> addCharger(ChargerModel charger) async {
    final docRef = _firestore.collection('chargers').doc(charger.id);
    await docRef.set(charger.toMap());
    return charger.id;
  }

  /// Get charger by ID
  Future<ChargerModel?> getCharger(String chargerId) async {
    try {
      final doc = await _firestore.collection('chargers').doc(chargerId).get();
      if (doc.exists && doc.data() != null) {
        return ChargerModel.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching charger: $e');
      return null;
    }
  }

  /// Update charger
  Future<void> updateCharger(
    String chargerId,
    Map<String, dynamic> data,
  ) async {
    data['updatedAt'] = DateTime.now().toIso8601String();
    await _firestore.collection('chargers').doc(chargerId).update(data);
  }

  /// Delete charger
  Future<void> deleteCharger(String chargerId) async {
    await _firestore.collection('chargers').doc(chargerId).delete();
  }

  /// Get all chargers by host
  Stream<List<ChargerModel>> getHostChargers(String hostUid) {
    return _firestore
        .collection('chargers')
        .where('hostId', isEqualTo: hostId)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => ChargerModel.fromMap(doc.data(), doc.id))
              .toList();
        });
  }

  /// Get all available chargers
  Stream<List<ChargerModel>> getAvailableChargers() {
    return _firestore
        .collection('chargers')
        .where('available', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => ChargerModel.fromMap(doc.data(), doc.id))
              .toList();
        });
  }

  Stream<List<ChargerModel>> getAllChargers() {
    return _firestore.collection('chargers').snapshots().map((snapshot) {
  /// Get chargers by location (within radius)
  Future<List<ChargerModel>> getChargersByLocation(
    double latitude,
    double longitude,
    double radiusInKm,
  ) async {
    try {
      // Approximate conversion: 1 degree ≈ 111 km
      double latDelta = radiusInKm / 111.0;
      double lonDelta = radiusInKm / (111.0 * DateTime.now().month.toDouble());

      final snapshot = await _firestore
          .collection('chargers')
          .where('latitude', isGreaterThan: latitude - latDelta)
          .where('latitude', isLessThan: latitude + latDelta)
          .get();

      return snapshot.docs
          .where((doc) {
            final charger = ChargerModel.fromMap(doc.data(), doc.id);
            return (charger.longitude - longitude).abs() < lonDelta;
          })
          .map((doc) => ChargerModel.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      print('Error fetching chargers by location: $e');
      return [];
    }
  }

  /// Search chargers by name
  Future<List<ChargerModel>> searchChargers(String query) async {
    try {
      final snapshot = await _firestore
          .collection('chargers')
          .where('name', isGreaterThanOrEqualTo: query)
          .where('name', isLessThan: query + 'z')
          .get();

      return snapshot.docs
          .map((doc) => ChargerModel.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      print('Error searching chargers: $e');
      return [];
    }
  }

  /// Get chargers filtered on the server.
  Stream<List<ChargerModel>> getFilteredChargers(ChargerFilter filter) {
    Query<Map<String, dynamic>> query = _firestore.collection('chargers');

    if (filter.availableOnly) {
      query = query.where('isAvailable', isEqualTo: true);
    }

    if (filter.connectorType != null) {
      query = query.where('connectorType', isEqualTo: filter.connectorType);
    }

    if (filter.maxPrice != null) {
      query = query
          .orderBy('pricePerHour')
          .where('pricePerHour', isLessThanOrEqualTo: filter.maxPrice);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => ChargerModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  /// Get chargers by location (within radius)
  Future<List<ChargerModel>> getChargersByLocation(
    double latitude,
    double longitude,
    double radiusInKm,
  ) async {
    try {
      // Approximate conversion: 1 degree ≈ 111 km
      double latDelta = radiusInKm / 111.0;
      // Proper longitude calculation using cosine
      final radians = latitude * (3.14159265 / 180.0);
      double lonDelta = radiusInKm / (111.0 * cos(radians));

      final snapshot = await _firestore
          .collection('chargers')
          .where('lat', isGreaterThan: latitude - latDelta)
          .where('lat', isLessThan: latitude + latDelta)
          .get();

      return snapshot.docs
          .where((doc) {
            final charger = ChargerModel.fromMap(doc.data(), doc.id);
            return (charger.lng - longitude).abs() < lonDelta;
          })
          .map((doc) => ChargerModel.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      debugPrint('Error fetching chargers by location: $e');
      return [];
    }
  }

  /// Search chargers by name
  Future<List<ChargerModel>> searchChargers(String query) async {
    try {
      final snapshot = await _firestore
          .collection('chargers')
          .where('title', isGreaterThanOrEqualTo: query)
          .where('title', isLessThan: '${query}z')
          .get();

      return snapshot.docs
          .map((doc) => ChargerModel.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      debugPrint('Error searching chargers: $e');
      return [];
    }
  }
}

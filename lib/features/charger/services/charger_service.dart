import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/charger_model.dart';

class ChargerService {
  final FirebaseFirestore _firestore;

  ChargerService(this._firestore);

  /// Create a new charger
  Future<String> createCharger(ChargerModel charger) async {
    final docRef = await _firestore.collection('chargers').add(charger.toMap());
    return docRef.id;
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
      print('Error fetching charger: $e');
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
  Stream<List<ChargerModel>> getHostChargers(String hostId) {
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
}

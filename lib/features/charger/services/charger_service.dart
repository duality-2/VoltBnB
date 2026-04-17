import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/charger_model.dart';

class ChargerService {
  final FirebaseFirestore _firestore;

  ChargerService(this._firestore);

  Future<void> addCharger(ChargerModel charger) async {
    await _firestore.collection('chargers').doc(charger.id).set(charger.toMap());
  }

  Future<void> updateCharger(String id, Map<String, dynamic> data) async {
    await _firestore.collection('chargers').doc(id).update(data);
  }

  Future<void> deleteCharger(String id) async {
    await _firestore.collection('chargers').doc(id).delete();
  }

  Stream<List<ChargerModel>> getHostChargers(String hostUid) {
    return _firestore
        .collection('chargers')
        .where('hostUid', isEqualTo: hostUid)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ChargerModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  Stream<List<ChargerModel>> getAvailableChargers() {
    return _firestore
        .collection('chargers')
        .where('isAvailable', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ChargerModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }
}

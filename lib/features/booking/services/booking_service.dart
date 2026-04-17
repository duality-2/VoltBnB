import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/booking_model.dart';

class BookingService {
  final FirebaseFirestore _firestore;

  BookingService(this._firestore);

  Future<void> createBooking(BookingModel booking) async {
    await _firestore.collection('bookings').doc(booking.id).set(booking.toMap());
  }

  Future<void> updateBookingStatus(String bookingId, String status, {String? paymentId}) async {
    final data = <String, dynamic>{'status': status};
    if (paymentId != null) data['paymentId'] = paymentId;
    await _firestore.collection('bookings').doc(bookingId).update(data);
  }

  Future<void> deleteBooking(String bookingId) async {
    await _firestore.collection('bookings').doc(bookingId).delete();
  }

  Stream<List<BookingModel>> getRenterBookings(String renterUid) {
    return _firestore
        .collection('bookings')
        .where('driverId', isEqualTo: renterUid)
        .orderBy('startTime', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => BookingModel.fromMap(doc.data(), doc.id)).toList();
    });
  }

  Stream<List<BookingModel>> getHostBookings(String hostUid) {
    return _firestore
        .collection('bookings')
        .where('hostId', isEqualTo: hostUid)
        .orderBy('startTime', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => BookingModel.fromMap(doc.data(), doc.id)).toList();
    });
  }

  Stream<List<BookingModel>> getChargerBookings(String chargerId) {
    return _firestore
        .collection('bookings')
        .where('chargerId', isEqualTo: chargerId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => BookingModel.fromMap(doc.data(), doc.id)).toList();
    });
  }
}

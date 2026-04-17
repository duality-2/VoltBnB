import 'package:cloud_firestore/cloud_firestore.dart';

class ChargerModel {
  final String id;
  final String hostUid;
  final String title;
  final String description;
  final String address;
  final double lat;
  final double lng;
  final double pricePerHour;
  final String connectorType;
  final List<String> amenities;
  final bool isAvailable;
  final List<String> photos;
  final double rating;
  final int reviewCount;
  final DateTime createdAt;

  ChargerModel({
    required this.id,
    required this.hostUid,
    required this.title,
    required this.description,
    required this.address,
    required this.lat,
    required this.lng,
    required this.pricePerHour,
    required this.connectorType,
    required this.amenities,
    required this.isAvailable,
    required this.photos,
    required this.rating,
    required this.reviewCount,
    required this.createdAt,
  });

  factory ChargerModel.fromMap(Map<String, dynamic> map, String documentId) {
    return ChargerModel(
      id: documentId,
      hostUid: map['hostUid'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      address: map['address'] ?? '',
      lat: (map['lat'] ?? 0.0).toDouble(),
      lng: (map['lng'] ?? 0.0).toDouble(),
      pricePerHour: (map['pricePerHour'] ?? 0.0).toDouble(),
      connectorType: map['connectorType'] ?? '',
      amenities: List<String>.from(map['amenities'] ?? []),
      isAvailable: map['isAvailable'] ?? false,
      photos: List<String>.from(map['photos'] ?? []),
      rating: (map['rating'] ?? 0.0).toDouble(),
      reviewCount: map['reviewCount'] ?? 0,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'hostUid': hostUid,
      'title': title,
      'description': description,
      'address': address,
      'lat': lat,
      'lng': lng,
      'pricePerHour': pricePerHour,
      'connectorType': connectorType,
      'amenities': amenities,
      'isAvailable': isAvailable,
      'photos': photos,
      'rating': rating,
      'reviewCount': reviewCount,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

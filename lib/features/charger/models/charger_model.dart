import 'package:cloud_firestore/cloud_firestore.dart';

class ChargerModel {
  final String id;
  final String hostId;
  final String name;
  final String? description;
  final String address;
  final double latitude;
  final double longitude;
  final String chargerType;
  final double? powerKw;
  final int pricePerHour;
  final bool available;
  final int totalSlots;
  final int occupiedSlots;
  final List<String> amenities;
  final List<String> photos;
  final String? imageUrl;
  final double? rating;
  final int reviewCount;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final List<String> availableSlots;
  final String healthStatus;

  ChargerModel({
    required this.id,
    required this.hostId,
    required this.name,
    this.description,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.chargerType,
    this.powerKw,
    required this.pricePerHour,
    required this.available,
    required this.totalSlots,
    required this.occupiedSlots,
    required this.amenities,
    this.photos = const [],
    this.imageUrl,
    this.rating,
    this.reviewCount = 0,
    required this.createdAt,
    this.updatedAt,
    this.availableSlots = const [],
    this.healthStatus = 'Good',
  });

  factory ChargerModel.fromMap(Map<String, dynamic> map, String id) {
    final parsedPhotos = List<String>.from(map['photos'] ?? []);
    return ChargerModel(
      id: id,
      // Support both 'hostUid' (Firestore) and legacy 'hostId'
      hostId: map['hostUid'] ?? map['hostId'] ?? '',
      name: map['name'] ?? '',
      description: map['description'],
      address: map['address'] ?? '',
      // Support both 'lat' (Firestore) and legacy 'latitude'
      latitude: (map['lat'] ?? map['latitude'] ?? 0).toDouble(),
      // Support both 'lng' (Firestore) and legacy 'longitude'
      longitude: (map['lng'] ?? map['longitude'] ?? 0).toDouble(),
      // Support both 'connectorType' (Firestore) and legacy 'chargerType'
      chargerType: map['connectorType'] ?? map['chargerType'] ?? 'AC',
      powerKw: (map['powerKw'] as num?)?.toDouble(),
      pricePerHour: (map['pricePerHour'] ?? 0) is int
          ? map['pricePerHour'] ?? 0
          : (map['pricePerHour'] ?? 0).toInt(),
      // Support both 'isAvailable' (Firestore) and legacy 'available'
      available: map['isAvailable'] ?? map['available'] ?? true,
      totalSlots: map['totalSlots'] ?? 1,
      occupiedSlots: map['occupiedSlots'] ?? 0,
      amenities: List<String>.from(map['amenities'] ?? []),
      photos: parsedPhotos,
      imageUrl:
          map['imageUrl'] ??
          (parsedPhotos.isNotEmpty ? parsedPhotos.first : null),
      rating: (map['rating'] as num?)?.toDouble(),
      reviewCount: map['reviewCount'] ?? 0,
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] is Timestamp
              ? (map['createdAt'] as Timestamp).toDate()
              : DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now())
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] is Timestamp
              ? (map['updatedAt'] as Timestamp).toDate()
              : DateTime.tryParse(map['updatedAt'].toString()))
          : null,
      availableSlots: List<String>.from(map['availableSlots'] ?? []),
      healthStatus: map['healthStatus'] ?? 'Good',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      // Use Firestore field names (matching actual DB documents)
      'hostUid': hostId,
      'name': name,
      'description': description,
      'address': address,
      'lat': latitude,
      'lng': longitude,
      'connectorType': chargerType,
      'powerKw': powerKw,
      'pricePerHour': pricePerHour,
      'isAvailable': available,
      'totalSlots': totalSlots,
      'occupiedSlots': occupiedSlots,
      'amenities': amenities,
      'photos': photos,
      'imageUrl': imageUrl,
      'rating': rating,
      'reviewCount': reviewCount,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'availableSlots': availableSlots,
      'healthStatus': healthStatus,
    };
  }

  ChargerModel copyWith({
    String? id,
    String? hostId,
    String? name,
    String? description,
    String? address,
    double? latitude,
    double? longitude,
    String? chargerType,
    double? powerKw,
    int? pricePerHour,
    bool? available,
    int? totalSlots,
    int? occupiedSlots,
    List<String>? amenities,
    List<String>? photos,
    String? imageUrl,
    double? rating,
    int? reviewCount,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? availableSlots,
    String? healthStatus,
  }) {
    return ChargerModel(
      id: id ?? this.id,
      hostId: hostId ?? this.hostId,
      name: name ?? this.name,
      description: description ?? this.description,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      chargerType: chargerType ?? this.chargerType,
      powerKw: powerKw ?? this.powerKw,
      pricePerHour: pricePerHour ?? this.pricePerHour,
      available: available ?? this.available,
      totalSlots: totalSlots ?? this.totalSlots,
      occupiedSlots: occupiedSlots ?? this.occupiedSlots,
      amenities: amenities ?? this.amenities,
      photos: photos ?? this.photos,
      imageUrl: imageUrl ?? this.imageUrl,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      availableSlots: availableSlots ?? this.availableSlots,
      healthStatus: healthStatus ?? this.healthStatus,
    );
  }
}

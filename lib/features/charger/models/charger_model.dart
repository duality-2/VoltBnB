class ChargerModel {
  final String id;
  final String hostId;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final String chargerType; // 'AC', 'DC', 'ULTRA_FAST'
  final int pricePerHour;
  final bool available;
  final int totalSlots;
  final int occupiedSlots;
  final List<String> amenities;
  final String? imageUrl;
  final double? rating;
  final DateTime createdAt;
  final DateTime? updatedAt;

  ChargerModel({
    required this.id,
    required this.hostId,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.chargerType,
    required this.pricePerHour,
    required this.available,
    required this.totalSlots,
    required this.occupiedSlots,
    required this.amenities,
    this.imageUrl,
    this.rating,
    required this.createdAt,
    this.updatedAt,
  });

  factory ChargerModel.fromMap(Map<String, dynamic> map, String id) {
    return ChargerModel(
      id: id,
      hostId: map['hostId'] ?? '',
      name: map['name'] ?? '',
      address: map['address'] ?? '',
      latitude: (map['latitude'] ?? 0).toDouble(),
      longitude: (map['longitude'] ?? 0).toDouble(),
      chargerType: map['chargerType'] ?? 'AC',
      pricePerHour: map['pricePerHour'] ?? 0,
      available: map['available'] ?? true,
      totalSlots: map['totalSlots'] ?? 1,
      occupiedSlots: map['occupiedSlots'] ?? 0,
      amenities: List<String>.from(map['amenities'] ?? []),
      imageUrl: map['imageUrl'],
      rating: (map['rating'] as num?)?.toDouble(),
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
      'hostId': hostId,
      'name': name,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'chargerType': chargerType,
      'pricePerHour': pricePerHour,
      'available': available,
      'totalSlots': totalSlots,
      'occupiedSlots': occupiedSlots,
      'amenities': amenities,
      'imageUrl': imageUrl,
      'rating': rating,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  ChargerModel copyWith({
    String? id,
    String? hostId,
    String? name,
    String? address,
    double? latitude,
    double? longitude,
    String? chargerType,
    int? pricePerHour,
    bool? available,
    int? totalSlots,
    int? occupiedSlots,
    List<String>? amenities,
    String? imageUrl,
    double? rating,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ChargerModel(
      id: id ?? this.id,
      hostId: hostId ?? this.hostId,
      name: name ?? this.name,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      chargerType: chargerType ?? this.chargerType,
      pricePerHour: pricePerHour ?? this.pricePerHour,
      available: available ?? this.available,
      totalSlots: totalSlots ?? this.totalSlots,
      occupiedSlots: occupiedSlots ?? this.occupiedSlots,
      amenities: amenities ?? this.amenities,
      imageUrl: imageUrl ?? this.imageUrl,
      rating: rating ?? this.rating,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

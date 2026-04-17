import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../charger/models/charger_model.dart';
import '../../charger/providers/charger_filter_provider.dart';
import '../../charger/providers/charger_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  final MapController _mapController = MapController();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  LatLng _initialCenter = const LatLng(28.6139, 77.2090);
  LatLng? _currentLocation;
  List<ChargerModel> _dummyChargers = const [];
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    _resolveCurrentLocation();
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      results,
    ) {
      setState(() {
        _isOffline = results.every(
          (result) => result == ConnectivityResult.none,
        );
      });
    });
  }

  Future<void> _resolveCurrentLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      final nextCenter = LatLng(position.latitude, position.longitude);
      if (!mounted) return;

      setState(() {
        _initialCenter = nextCenter;
        _currentLocation = nextCenter;
        _dummyChargers = _generateDummyChargers(position);
      });
      _mapController.move(nextCenter, 15.0);
    } catch (_) {}
  }

  List<ChargerModel> _generateDummyChargers(Position currentPos) {
    final random = Random();
    const earthRadiusKm = 6371.0;

    double randomDistanceKm(int index) {
      if (index < 2) {
        return 0.25 + random.nextDouble() * 0.65;
      }
      if (index < 4) {
        return 0.8 + random.nextDouble() * 0.8;
      }
      return 1.4 + random.nextDouble() * 0.6;
    }

    double randomBearingRad() {
      return random.nextDouble() * 2 * pi;
    }

    final baseLat = currentPos.latitude * pi / 180;
    final baseLng = currentPos.longitude * pi / 180;

    return List.generate(6, (index) {
      final distanceKm = randomDistanceKm(index);
      final bearing = randomBearingRad();
      final angularDistance = distanceKm / earthRadiusKm;

      final latRadians = asin(
        sin(baseLat) * cos(angularDistance) +
            cos(baseLat) * sin(angularDistance) * cos(bearing),
      );

      final lngRadians =
          baseLng +
          atan2(
            sin(bearing) * sin(angularDistance) * cos(baseLat),
            cos(angularDistance) - sin(baseLat) * sin(latRadians),
          );

      final isAvailable = index % 3 != 1 || random.nextBool();

      return ChargerModel(
        id: 'dummy_charger_$index',
        hostId: 'demo-host',
        name: 'Demo Charger ${index + 1}',
        description: 'Synthetic charger for hackathon demo use only.',
        address: 'Demo Zone ${index + 1}',
        latitude: latRadians * 180 / pi,
        longitude: lngRadians * 180 / pi,
        chargerType: index.isEven ? 'CCS2' : 'Type 2',
        powerKw: 22 + (index * 7.5),
        pricePerHour: 20 + random.nextInt(40),
        available: isAvailable,
        totalSlots: 2 + random.nextInt(3),
        occupiedSlots: isAvailable ? 0 : 1 + random.nextInt(2),
        amenities: const ['Fast Charging', 'Parking', '24/7 Access'],
        rating: 4.2 + (random.nextDouble() * 0.7),
        reviewCount: 12 + random.nextInt(60),
        createdAt: DateTime.now(),
        availableSlots: const [],
        healthStatus: isAvailable ? 'Good' : 'Busy',
      );
    });
  }

  List<ChargerModel> _applySearch(
    List<ChargerModel> chargers,
    String searchQuery,
  ) {
    if (searchQuery.trim().isEmpty) return chargers;

    final query = searchQuery.trim().toLowerCase();
    return chargers.where((charger) {
      return charger.name.toLowerCase().contains(query) ||
          charger.address.toLowerCase().contains(query) ||
          (charger.description ?? '').toLowerCase().contains(query);
    }).toList();
  }

  Marker _buildChargerMarker(
    ChargerModel charger, {
    required VoidCallback onTap,
  }) {
    final markerColor = charger.available
        ? const Color(0xFF22C55E)
        : const Color(0xFFEF4444);

    return Marker(
      point: LatLng(charger.latitude, charger.longitude),
      width: 50,
      height: 50,
      builder: (context) => GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: markerColor,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: markerColor.withValues(alpha: 0.3),
                blurRadius: 10,
                spreadRadius: 0,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 20),
        ),
      ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
    );
  }

  Marker _buildCurrentLocationMarker() {
    final currentLocation = _currentLocation;
    if (currentLocation == null) {
      return Marker
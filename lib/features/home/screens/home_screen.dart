import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/utils/astar_pathfinder.dart';
import '../../charger/models/charger_model.dart';
import '../../charger/providers/charger_filter_provider.dart';
import '../../charger/providers/charger_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  static const List<String> _supportedConnectorTypes = [
    'Type 1 - 6A',
    'Type 2 - 16A',
  ];

  final TextEditingController _searchController = TextEditingController();
  final MapController _mapController = MapController();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  LatLng _initialCenter = LatLng(28.6139, 77.2090);
  LatLng? _currentLocation;
  List<LatLng> _shortestPathPoints = const [];
  ChargerModel? _routeTargetCharger;
  double? _routeDistanceMeters;
  bool _isRoutingNearest = false;
  bool _autoNearestRoutePending = false;
  bool _autoNearestRouteDone = false;
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
        _autoNearestRoutePending = true;
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
        chargerType: index.isEven ? 'Type 2 - 16A' : 'Type 1 - 6A',
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
      width: 56,
      height: 56,
      builder: (context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
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
      ),
    );
  }

  Marker _buildCurrentLocationMarker() {
    final currentLocation = _currentLocation;
    if (currentLocation == null) {
      return Marker(
        point: _initialCenter,
        width: 0,
        height: 0,
        builder: (_) => const SizedBox.shrink(),
      );
    }

    return Marker(
      point: currentLocation,
      width: 72,
      height: 72,
      builder: (context) => Stack(
        alignment: Alignment.center,
        children: [
          Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF1E88E5).withValues(alpha: 0.18),
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1E88E5).withValues(alpha: 0.35),
                      blurRadius: 18,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              )
              .animate(onPlay: (controller) => controller.repeat(reverse: true))
              .scaleXY(
                begin: 0.92,
                end: 1.08,
                duration: 1.2.seconds,
                curve: Curves.easeInOut,
              ),
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                colors: [Color(0xFF64B5F6), Color(0xFF1565C0)],
              ),
              border: Border.all(color: Colors.white, width: 3),
            ),
            child: const Icon(
              Icons.my_location_rounded,
              color: Colors.white,
              size: 16,
            ),
          ),
        ],
      ),
    );
  }

  void _onChargerTap(ChargerModel charger) {
    _showChargerQuickInfo(charger);
  }

  double? _distanceKmTo(ChargerModel charger) {
    final source = _currentLocation;
    if (source == null) return null;

    const distance = Distance();
    final meters = distance(source, LatLng(charger.latitude, charger.longitude));
    return meters / 1000;
  }

  int? _estimatedDriveMinutes(ChargerModel charger) {
    final km = _distanceKmTo(charger);
    if (km == null) return null;

    // Conservative city average speed.
    const avgSpeedKmPerHour = 28.0;
    final hours = km / avgSpeedKmPerHour;
    return max(1, (hours * 60).round());
  }

  String _availabilityText(ChargerModel charger) {
    final freeSlots = charger.totalSlots - charger.occupiedSlots;
    if (charger.totalSlots <= 0) {
      return charger.available ? 'Available now' : 'Busy now';
    }
    return '${freeSlots.clamp(0, charger.totalSlots)}/${charger.totalSlots} slots free';
  }

  void _showChargerQuickInfo(ChargerModel charger) {
    final distanceKm = _distanceKmTo(charger);
    final etaMinutes = _estimatedDriveMinutes(charger);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 14),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      charger.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF111827),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: charger.available
                          ? const Color(0xFFF0FDF4)
                          : const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      charger.available ? 'AVAILABLE' : 'BUSY',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: charger.available
                            ? const Color(0xFF166534)
                            : const Color(0xFFB91C1C),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                charger.address,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: const Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _infoChip(Icons.currency_rupee_rounded, '₹${charger.pricePerHour}/hr'),
                  _infoChip(Icons.power_rounded, charger.chargerType),
                  _infoChip(Icons.bolt_rounded, '${(charger.powerKw ?? 0).toStringAsFixed(1)} kW'),
                  _infoChip(Icons.ev_station_rounded, _availabilityText(charger)),
                  if (distanceKm != null)
                    _infoChip(Icons.place_outlined, '${distanceKm.toStringAsFixed(2)} km away'),
                  if (etaMinutes != null)
                    _infoChip(Icons.schedule_rounded, '~$etaMinutes min drive'),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _showRouteToCharger(charger);
                      },
                      icon: const Icon(Icons.alt_route_rounded),
                      label: const Text('Find Route'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: charger.id.startsWith('dummy_charger_')
                          ? null
                          : () {
                              Navigator.of(context).pop();
                              context.push('/charger/${charger.id}', extra: charger);
                            },
                      icon: const Icon(Icons.info_outline_rounded),
                      label: const Text('View Details'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _infoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: const Color(0xFF374151)),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }

  Future<List<LatLng>?> _fetchRoadRoute(
    LatLng source,
    LatLng destination,
  ) async {
    final accessToken = dotenv.env['MAPBOX_ACCESS_TOKEN'];
    if (accessToken == null || accessToken.isEmpty) {
      return null;
    }

    final uri = Uri.parse(
      'https://api.mapbox.com/directions/v5/mapbox/driving/'
      '${source.longitude},${source.latitude};'
      '${destination.longitude},${destination.latitude}'
      '?alternatives=false&geometries=geojson&overview=full&steps=false'
      '&access_token=$accessToken',
    );

    try {
      final response = await http.get(uri);
      if (response.statusCode != 200) {
        return null;
      }

      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      final routes = payload['routes'] as List<dynamic>?;
      if (routes == null || routes.isEmpty) {
        return null;
      }

      final firstRoute = routes.first as Map<String, dynamic>;
      final geometry = firstRoute['geometry'] as Map<String, dynamic>?;
      final coordinates = geometry?['coordinates'] as List<dynamic>?;
      if (coordinates == null || coordinates.length < 2) {
        return null;
      }

      final roadPath = coordinates
          .map((point) => point as List<dynamic>)
          .map((point) => LatLng((point[1] as num).toDouble(), (point[0] as num).toDouble()))
          .toList();

      final distanceMeters = (firstRoute['distance'] as num?)?.toDouble();
      if (distanceMeters != null && mounted) {
        setState(() => _routeDistanceMeters = distanceMeters);
      }

      return roadPath;
    } catch (_) {
      return null;
    }
  }

  Future<void> _showRouteToCharger(ChargerModel charger) async {
    final source = _currentLocation;
    if (source == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enable location to find shortest path.'),
        ),
      );
      return;
    }

    setState(() => _routeDistanceMeters = null);

    final destination = LatLng(charger.latitude, charger.longitude);
    final roadPath = await _fetchRoadRoute(source, destination);
    final path =
        roadPath ??
        AStarPathfinder.findShortestPath(start: source, goal: destination);

    const distance = Distance();
    double totalMeters = 0;
    for (var i = 0; i < path.length - 1; i++) {
      totalMeters += distance(path[i], path[i + 1]);
    }

    setState(() {
      _routeTargetCharger = charger;
      _shortestPathPoints = path;
      _routeDistanceMeters = _routeDistanceMeters ?? totalMeters;
    });

    _mapController.fitBounds(
      LatLngBounds.fromPoints(path),
      options: const FitBoundsOptions(padding: EdgeInsets.all(52)),
    );
  }

  ChargerModel? _nearestCharger(List<ChargerModel> chargers) {
    final source = _currentLocation;
    if (source == null || chargers.isEmpty) {
      return null;
    }

    const distance = Distance();
    ChargerModel? nearest;
    var nearestMeters = double.infinity;

    for (final charger in chargers) {
      final meters = distance(source, LatLng(charger.latitude, charger.longitude));
      if (meters < nearestMeters) {
        nearestMeters = meters;
        nearest = charger;
      }
    }

    return nearest;
  }

  Future<void> _routeToNearestCharger(
    List<ChargerModel> chargers, {
    bool showFeedback = true,
  }) async {
    if (_isRoutingNearest) return;

    final nearest = _nearestCharger(chargers);
    if (nearest == null) {
      if (showFeedback) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No nearby pins found.')),
        );
      }
      return;
    }

    setState(() => _isRoutingNearest = true);
    try {
      await _showRouteToCharger(nearest);
      if (!mounted) return;
      if (showFeedback) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Showing road route to nearest pin: ${nearest.name}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isRoutingNearest = false);
    }
  }

  void _clearRoute() {
    setState(() {
      _routeTargetCharger = null;
      _shortestPathPoints = const [];
      _routeDistanceMeters = null;
    });
  }

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)} m';
    }
    return '${(meters / 1000).toStringAsFixed(2)} km';
  }

  void _openFilterSheet() {
    final currentFilter = ref.read(chargerFilterProvider);
    String? selectedConnector = currentFilter.connectorType;
    if (selectedConnector != null &&
        !_supportedConnectorTypes.contains(selectedConnector)) {
      selectedConnector = null;
    }
    double maxPrice = currentFilter.maxPrice ?? 200;
    bool availableOnly = currentFilter.availableOnly;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              margin: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 48,
                      height: 6,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Filter Chargers',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 24),
                  DropdownButtonFormField<String>(
                    initialValue: selectedConnector,
                    decoration: const InputDecoration(
                      labelText: 'Connector Type',
                      prefixIcon: Icon(Icons.electrical_services_rounded),
                    ),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('All Types')),
                      DropdownMenuItem(
                        value: 'Type - 6A',
                        child: Text('Type - 6A'),
                      ),
                      DropdownMenuItem(
                        value: 'Type 2 - 16A',
                        child: Text('Type 2 - 16A'),
                      ),
                    ],
                    onChanged: (value) =>
                        setModalState(() => selectedConnector = value),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Max Price/hr',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '₹${maxPrice.toStringAsFixed(0)}',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                          color: const Color(0xFF22C55E),
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    min: 20,
                    max: 500,
                    divisions: 24,
                    value: maxPrice,
                    activeColor: const Color(0xFF22C55E),
                    onChanged: (value) => setModalState(() => maxPrice = value),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade200),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: SwitchListTile(
                      activeThumbColor: const Color(0xFF22C55E),
                      value: availableOnly,
                      onChanged: (value) =>
                          setModalState(() => availableOnly = value),
                      title: const Text(
                        'Available right now',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        flex: 1,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 56),
                            padding: EdgeInsets.zero,
                          ),
                          onPressed: () {
                            ref
                                .read(chargerFilterProvider.notifier)
                                .updateState(ChargerFilter());
                            Navigator.of(context).pop();
                          },
                          child: const Text('Reset'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: () {
                            ref
                                .read(chargerFilterProvider.notifier)
                                .updateState(
                                  ChargerFilter(
                                    connectorType: selectedConnector,
                                    maxPrice: maxPrice,
                                    availableOnly: availableOnly,
                                  ),
                                );
                            Navigator.of(context).pop();
                          },
                          child: const Text('Apply Filters'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _mapController.dispose();
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chargersAsync = ref.watch(filteredChargersProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          chargersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) =>
                Center(child: Text('Failed to load map: $error')),
            data: (chargers) {
              final visibleChargers = _applySearch([
                ...chargers,
                ..._dummyChargers,
              ], _searchController.text);

              if (_autoNearestRoutePending &&
                  !_autoNearestRouteDone &&
                  _currentLocation != null &&
                  visibleChargers.isNotEmpty) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted || _autoNearestRouteDone || _isRoutingNearest) {
                    return;
                  }
                  setState(() {
                    _autoNearestRoutePending = false;
                    _autoNearestRouteDone = true;
                  });
                  _routeToNearestCharger(visibleChargers, showFeedback: false);
                });
              }

              final markers = visibleChargers
                  .map(
                    (charger) => _buildChargerMarker(
                      charger,
                      onTap: () => _onChargerTap(charger),
                    ),
                  )
                  .toList();

              if (_currentLocation != null) {
                markers.insert(0, _buildCurrentLocationMarker());
              }

              return FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  center: _initialCenter,
                  zoom: 13.0,
                  maxZoom: 18.0,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://api.mapbox.com/styles/v1/mapbox/light-v11/tiles/{z}/{x}/{y}?access_token=${dotenv.env['MAPBOX_ACCESS_TOKEN']}',
                    additionalOptions: {
                      'accessToken': dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '',
                    },
                  ),
                  MarkerLayer(markers: markers),
                  if (_shortestPathPoints.length >= 2)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: _shortestPathPoints,
                          strokeWidth: 5,
                          color: const Color(0xFF2563EB),
                        ),
                      ],
                    ),
                ],
              );
            },
          ),

          Positioned(
            right: 16,
            bottom: 220,
            child: chargersAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (error, stackTrace) => const SizedBox.shrink(),
              data: (chargers) {
                final visibleChargers = _applySearch([
                  ...chargers,
                  ..._dummyChargers,
                ], _searchController.text);

                return FloatingActionButton.extended(
                  heroTag: 'nearest_route_fab',
                  onPressed: _isRoutingNearest
                      ? null
                      : () => _routeToNearestCharger(visibleChargers),
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  icon: _isRoutingNearest
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.near_me_rounded),
                  label: Text(
                    _isRoutingNearest ? 'Routing...' : 'Nearest Pin Route',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                );
              },
            ),
          ),

          if (_routeTargetCharger != null && _routeDistanceMeters != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 220,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.alt_route_rounded,
                      color: Color(0xFF2563EB),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Road route to ${_routeTargetCharger!.name}: ${_formatDistance(_routeDistanceMeters!)}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF111827),
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _clearRoute,
                      child: const Text('Clear'),
                    ),
                  ],
                ),
              ),
            ),

          if (_isOffline)
            Positioned(
              top: MediaQuery.of(context).padding.top,
              left: 0,
              right: 0,
              child: MaterialBanner(
                backgroundColor: Colors.redAccent,
                contentTextStyle: const TextStyle(color: Colors.white),
                content: const Text(
                  'You are offline. Map data may be outdated.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => setState(() => _isOffline = false),
                    child: const Text(
                      'Dismiss',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),

          Positioned(
            top: MediaQuery.of(context).padding.top + (_isOffline ? 60 : 16),
            left: 16,
            right: 16,
            child:
                ClipRRect(
                  borderRadius: BorderRadius.circular(100),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(
                          color: const Color(0xFFE5E7EB),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 16,
                            spreadRadius: 0,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(left: 8.0),
                            child: Icon(
                              Icons.search_rounded,
                              color: Color(0xFF9CA3AF),
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              onChanged: (_) => setState(() {}),
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w400,
                                color: const Color(0xFF111827),
                              ),
                              decoration: InputDecoration(
                                hintText: 'Search chargers...',
                                hintStyle: GoogleFonts.inter(
                                  color: const Color(0xFF9CA3AF),
                                  fontSize: 15,
                                ),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                filled: false,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                          if (_searchController.text.isNotEmpty)
                            IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              icon: const Icon(
                                Icons.close_rounded,
                                size: 18,
                                color: Color(0xFF6B7280),
                              ),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                            ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => context.push('/notifications'),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF9FAFB),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFFE5E7EB),
                                ),
                              ),
                              child: const Icon(
                                Icons.notifications_none_rounded,
                                size: 20,
                                color: Color(0xFF374151),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: _openFilterSheet,
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: const BoxDecoration(
                                color: Color(0xFF111827),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.tune_rounded,
                                size: 20,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                        ],
                      ),
                    ),
                  ),
                ).animate().slideY(
                  begin: -1,
                  duration: 500.ms,
                  curve: Curves.easeOutCirc,
                ),
          ),

          Positioned(
            left: 0,
            right: 0,
            bottom: 24,
            child: SizedBox(
              height: 180,
              child: chargersAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (error, _) => const SizedBox.shrink(),
                data: (chargers) {
                  final visibleChargers = _applySearch([
                    ...chargers,
                    ..._dummyChargers,
                  ], _searchController.text);

                  if (visibleChargers.isEmpty) {
                    return Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 20,
                            ),
                          ],
                        ),
                        child: const Text(
                          'No chargers match your search.',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: visibleChargers.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 16),
                    itemBuilder: (context, index) {
                      final charger = visibleChargers[index];
                      return SizedBox(
                            width: MediaQuery.of(context).size.width * 0.85,
                            child: GestureDetector(
                              onTap: () => _onChargerTap(charger),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: const Color(0xFFE5E7EB),
                                    width: 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.04,
                                      ),
                                      blurRadius: 16,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF8FAFC),
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.ev_station_rounded,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                charger.name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: GoogleFonts.inter(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 17,
                                                  color: const Color(
                                                    0xFF111827,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                charger.address,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: GoogleFonts.inter(
                                                  color: const Color(
                                                    0xFF6B7280,
                                                  ),
                                                  fontWeight: FontWeight.w400,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Spacer(),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: charger.available
                                                ? const Color(0xFFF0FDF4)
                                                : const Color(0xFFFEF2F2),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color: charger.available
                                                  ? const Color(0xFFDCFCE7)
                                                  : const Color(0xFFFEE2E2),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Container(
                                                    width: 8,
                                                    height: 8,
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      color: charger.available
                                                          ? const Color(
                                                              0xFF00E676,
                                                            )
                                                          : Colors.redAccent,
                                                    ),
                                                  )
                                                  .animate(
                                                    onPlay: (controller) =>
                                                        controller.repeat(
                                                          reverse: true,
                                                        ),
                                                  )
                                                  .scaleXY(
                                                    end: charger.available
                                                        ? 1.5
                                                        : 1,
                                                    duration: 800.ms,
                                                  ),
                                              const SizedBox(width: 6),
                                              Text(
                                                charger.available
                                                    ? 'AVAILABLE'
                                                    : 'BUSY',
                                                style: GoogleFonts.inter(
                                                  color: charger.available
                                                      ? const Color(0xFF15803D)
                                                      : const Color(0xFFB91C1C),
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 11,
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Text(
                                          '₹${charger.pricePerHour}/hr',
                                          style: GoogleFonts.inter(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 20,
                                            color: const Color(0xFF111827),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                          .animate()
                          .slideX(
                            begin: 0.2,
                            delay: (index * 100).ms,
                            duration: 400.ms,
                            curve: Curves.easeOutBack,
                          )
                          .fadeIn();
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

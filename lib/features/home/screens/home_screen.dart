import 'dart:async';
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

  LatLng _initialCenter = LatLng(28.6139, 77.2090);
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
      });
      _mapController.move(nextCenter, 15.0);
    } catch (_) {}
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

  void _openFilterSheet() {
    final currentFilter = ref.read(chargerFilterProvider);
    String? selectedConnector = currentFilter.connectorType;
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
                  // ignore: deprecated_member_use
                    value: selectedConnector,
                    decoration: const InputDecoration(
                      labelText: 'Connector Type',
                      prefixIcon: Icon(Icons.electrical_services_rounded),
                    ),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('All Types')),
                      DropdownMenuItem(value: 'Type 1', child: Text('Type 1')),
                      DropdownMenuItem(value: 'Type 2', child: Text('Type 2')),
                      DropdownMenuItem(value: 'CCS1', child: Text('CCS1')),
                      DropdownMenuItem(value: 'CCS2', child: Text('CCS2')),
                      DropdownMenuItem(value: 'CHAdeMO', child: Text('CHAdeMO')),
                      DropdownMenuItem(value: 'Tesla', child: Text('Tesla')),
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
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                      ),
                      Text(
                        '\$${maxPrice.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          color: Color(0xFF00E676),
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    min: 20,
                    max: 500,
                    divisions: 24,
                    value: maxPrice,
                    activeColor: const Color(0xFF00E676),
                    onChanged: (value) => setModalState(() => maxPrice = value),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade200),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: SwitchListTile(
                      activeThumbColor: const Color(0xFF00E676),
                      value: availableOnly,
                      onChanged: (value) => setModalState(() => availableOnly = value),
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
          // 1. The Map Layer
          chargersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(child: Text('Failed to load map: $error')),
            data: (chargers) {
              final visibleChargers = _applySearch(
                chargers,
                _searchController.text,
              );

              final markers = visibleChargers
                  .map(
                    (charger) => Marker(
                      point: LatLng(charger.latitude, charger.longitude),
                      width: 50,
                      height: 50,
                      builder: (context) => GestureDetector(
                        onTap: () => context.push(
                          '/charger/${charger.id}',
                          extra: charger,
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: charger.available
                                ? const Color(0xFF00E676)
                                : Colors.redAccent,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: (charger.available
                                        ? const Color(0xFF00E676)
                                        : Colors.redAccent)
                                    .withValues(alpha: 0.5),
                                blurRadius: 12,
                                spreadRadius: 2,
                              )
                            ],
                          ),
                          child: const Icon(
                            Icons.bolt_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ).animate().scale(
                            duration: 400.ms,
                            curve: Curves.easeOutBack,
                          ),
                    ),
                  )
                  .toList();

              return FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  center: _initialCenter,
                  zoom: 13.0,
                  maxZoom: 18.0,
                ),
                children: [
                   TileLayer(
                      urlTemplate: 'https://api.mapbox.com/styles/v1/mapbox/light-v11/tiles/{z}/{x}/{y}?access_token=${dotenv.env['MAPBOX_ACCESS_TOKEN']}',
                      additionalOptions: {
                        'accessToken': dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '',
                      },
                    ),
                  MarkerLayer(markers: markers),
                ],
              );
            },
          ),

          // 2. Offline Banner
          if (_isOffline)
            Positioned(
              top: MediaQuery.of(context).padding.top,
              left: 0,
              right: 0,
              child: MaterialBanner(
                backgroundColor: Colors.redAccent,
                contentTextStyle: const TextStyle(color: Colors.white),
                content: const Text('You are offline. Map data may be outdated.'),
                actions: [
                  TextButton(
                    onPressed: () => setState(() => _isOffline = false),
                    child: const Text('Dismiss', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),

          // 3. Top Floating Glassmorphic Search Bar
          Positioned(
            top: MediaQuery.of(context).padding.top + (_isOffline ? 60 : 16),
            left: 16,
            right: 16,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      )
                    ],
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.notifications_none_rounded),
                        onPressed: () => context.push('/notifications'),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            hintText: 'Search areas or chargers...',
                            hintStyle: TextStyle(color: Colors.grey.shade500),
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
                          icon: const Icon(Icons.clear, size: 20),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                        ),
                      Container(
                        margin: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.black,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.tune_rounded, color: Colors.white),
                          onPressed: _openFilterSheet,
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ).animate().slideY(begin: -1, duration: 500.ms, curve: Curves.easeOutCirc),
          ),

          // 4. Bottom Horizontal Card List
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
                  final visibleChargers = _applySearch(
                    chargers,
                    _searchController.text,
                  );

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
                            )
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
                          onTap: () => context.push(
                            '/charger/${charger.id}',
                            extra: charger,
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(32),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 24,
                                  offset: const Offset(0, 12),
                                )
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
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: const Icon(
                                        Icons.ev_station_rounded,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            charger.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 18,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            charger.address,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: Colors.grey.shade600,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const Spacer(),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: charger.available
                                            ? const Color(0xFFE8F5E9)
                                            : Colors.red.shade50,
                                        borderRadius: BorderRadius.circular(100),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 8,
                                            height: 8,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: charger.available
                                                  ? const Color(0xFF00E676)
                                                  : Colors.redAccent,
                                            ),
                                          ).animate(
                                              onPlay: (controller) =>
                                                  controller.repeat(reverse: true))
                                           .scaleXY(end: charger.available ? 1.5 : 1, duration: 800.ms),
                                          const SizedBox(width: 6),
                                          Text(
                                            charger.available ? 'Available' : 'Busy',
                                            style: TextStyle(
                                              color: charger.available
                                                  ? Colors.green.shade800
                                                  : Colors.red.shade800,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      '\$${charger.pricePerHour}/hr',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 20,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ).animate().slideX(
                            begin: 0.2,
                            delay: (index * 100).ms,
                            duration: 400.ms,
                            curve: Curves.easeOutBack,
                          ).fadeIn();
                    },
                  );
                },
              ),
            ),
          ),

          // Removed Host Mode FAB as per requirement
        ],
      ),
    );
  }
}

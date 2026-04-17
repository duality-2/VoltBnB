import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:go_router/go_router.dart';
import 'package:skeletonizer/skeletonizer.dart';
import '../../charger/providers/charger_provider.dart';
import '../../charger/providers/charger_filter_provider.dart';
import '../../charger/models/charger_model.dart';
import '../../auth/providers/auth_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return;
    }

    final position = await Geolocator.getCurrentPosition();
    setState(() {
      _currentPosition = position;
    });

    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(position.latitude, position.longitude),
          zoom: 14,
        ),
      ),
    );
  }

  Future<void> _searchLocation() async {
    final query = _searchController.text;
    if (query.isEmpty) return;

    try {
      List<Location> locations = await locationFromAddress(query);
      if (locations.isNotEmpty) {
        final loc = locations.first;
        _mapController?.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(loc.latitude, loc.longitude),
              zoom: 14,
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Location not found')));
    }
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Consumer(
          builder: (context, ref, _) {
            final filter = ref.watch(chargerFilterProvider);
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Filters',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Available Only'),
                    value: filter.availableOnly,
                    onChanged: (val) {
                      ref
                          .read(chargerFilterProvider.notifier)
                          .updateState(filter.copyWith(availableOnly: val));
                    },
                  ),
                  const Text('Connector Type'),
                  Wrap(
                    spacing: 8,
                    children:
                        [
                          'Type 1',
                          'Type 2',
                          'CCS1',
                          'CCS2',
                          'CHAdeMO',
                          'Tesla',
                        ].map((type) {
                          final isSelected = filter.connectorType == type;
                          return FilterChip(
                            label: Text(type),
                            selected: isSelected,
                            onSelected: (selected) {
                              ref
                                  .read(chargerFilterProvider.notifier)
                                  .updateState(
                                    filter.copyWith(
                                      connectorType: selected ? type : null,
                                      clearConnectorType: !selected,
                                    ),
                                  );
                            },
                          );
                        }).toList(),
                  ),
                  const SizedBox(height: 16),
                  const Text('Max Price / Hour'),
                  Slider(
                    value: filter.maxPrice ?? 100.0,
                    min: 0,
                    max: 100,
                    divisions: 20,
                    label: filter.maxPrice == null
                        ? 'Any'
                        : '\$${filter.maxPrice?.toStringAsFixed(0)}',
                    onChanged: (val) {
                      ref
                          .read(chargerFilterProvider.notifier)
                          .updateState(
                            filter.copyWith(
                              maxPrice: val,
                              clearMaxPrice: val == 100,
                            ),
                          );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showChargerDetails(ChargerModel charger) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                charger.title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '\$ \${charger.pricePerHour.toStringAsFixed(2)} / hr • \${charger.connectorType}',
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.star, color: Colors.amber, size: 16),
                  Text(
                    ' \${charger.rating.toStringAsFixed(1)} (\${charger.reviewCount} reviews)',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  context.pop();
                  context.push('/charger/\${charger.id}', extra: charger);
                },
                child: const Text('View & Book'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final chargersAsync = ref.watch(filteredChargersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('VoltBnB'),
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long),
            onPressed: () => context.push('/bookings'),
          ),
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () => context.push('/profile'),
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Color(0xFF1DB954)),
              child: Text(
                'VoltBnB',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.ev_station),
              title: const Text('Host: My Chargers'),
              onTap: () {
                context.pop();
                context.push('/my-chargers');
              },
            ),
            ListTile(
              leading: const Icon(Icons.dashboard),
              title: const Text('Host: Dashboard'),
              onTap: () {
                context.pop();
                context.push('/host-dashboard');
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () {
                ref.read(authServiceProvider).signOut();
                context.go('/login');
              },
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          chargersAsync.when(
            data: (chargers) {
              Set<Marker> markers = chargers.map((charger) {
                return Marker(
                  markerId: MarkerId(charger.id),
                  position: LatLng(charger.lat, charger.lng),
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                    charger.isAvailable
                        ? BitmapDescriptor.hueGreen
                        : BitmapDescriptor.hueRed,
                  ),
                  onTap: () => _showChargerDetails(charger),
                );
              }).toSet();

              return GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: _currentPosition != null
                      ? LatLng(
                          _currentPosition!.latitude,
                          _currentPosition!.longitude,
                        )
                      : const LatLng(37.7749, -122.4194), // Default SF
                  zoom: 12,
                ),
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                markers: markers,
                onMapCreated: (controller) => _mapController = controller,
              );
            },
            loading: () => const Skeletonizer(
              enabled: true,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (err, stack) =>
                Center(child: Text('Error loading map: \$err')),
          ),
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 4,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search location...',
                        prefixIcon: const Icon(Icons.search),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.send),
                          onPressed: _searchLocation,
                        ),
                      ),
                      onSubmitted: (_) => _searchLocation(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton(
                  heroTag: 'filter_fab',
                  mini: true,
                  backgroundColor: Colors.white,
                  onPressed: _showFilterBottomSheet,
                  child: const Icon(Icons.filter_list, color: Colors.black87),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton(
              heroTag: 'location_fab',
              backgroundColor: Colors.white,
              onPressed: _determinePosition,
              child: const Icon(Icons.my_location, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}

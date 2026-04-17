import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import '../models/charger_model.dart';
import '../providers/charger_provider.dart';
import '../../auth/providers/auth_provider.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/geocoding_service.dart';

class AddChargerScreen extends ConsumerStatefulWidget {
  const AddChargerScreen({super.key});

  @override
  ConsumerState<AddChargerScreen> createState() => _AddChargerScreenState();
}

class _AddChargerScreenState extends ConsumerState<AddChargerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _addressController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();

  String _connectorType = 'Type 2';
  final List<String> _amenities = [];
  final List<String> _availableSlots = [];
  final List<XFile> _photos = [];
  bool _isLoading = false;

  final _availableAmenities = ['WiFi', 'Restroom', 'Cafe', 'Shopping'];
  final _connectorTypes = [
    'Type 1',
    'Type 2',
    'CCS1',
    'CCS2',
    'CHAdeMO',
    'Tesla',
  ];
  
  final _allSlots = [
    '09:00 AM - 10:00 AM',
    '10:00 AM - 11:00 AM',
    '11:00 AM - 12:00 PM',
    '12:00 PM - 01:00 PM',
    '01:00 PM - 02:00 PM',
    '02:00 PM - 03:00 PM',
    '03:00 PM - 04:00 PM',
    '04:00 PM - 05:00 PM',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _addressController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage();
    if (pickedFiles.isNotEmpty) {
      setState(() {
        _photos.addAll(pickedFiles);
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_availableSlots.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one available slot.')),
      );
      return;
    }

    final user = ref.read(userProvider);
    if (user == null) return;

    setState(() => _isLoading = true);
    try {
      final chargerId = const Uuid().v4();
      final photoUrls = <String>[];

      // Upload photos
      for (var photo in _photos) {
        final refPath = 'chargers/$chargerId/${const Uuid().v4()}.jpg';
        final storageRef = FirebaseStorage.instance.ref().child(refPath);

        if (kIsWeb) {
          final bytes = await photo.readAsBytes();
          await storageRef.putData(
            bytes,
            SettableMetadata(contentType: 'image/jpeg'),
          );
        } else {
          // On mobile, dynamically import dart:io
          final bytes = await photo.readAsBytes();
          await storageRef.putData(
            bytes,
            SettableMetadata(contentType: 'image/jpeg'),
          );
        }

        final downloadUrl = await storageRef.getDownloadURL();
        photoUrls.add(downloadUrl);
      }

      final geocodingService = GeocodingService();
      final geocoded = await geocodingService.geocodeAddress(
        _addressController.text.trim(),
      );

      final lat = geocoded?.lat ?? 37.7749;
      final lng = geocoded?.lng ?? -122.4194;

      final charger = ChargerModel(
        id: chargerId,
        hostId: user.uid,
        name: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        address: _addressController.text.trim(),
        latitude: lat,
        longitude: lng,
        pricePerHour: int.parse(_priceController.text.trim()),
        chargerType: _connectorType,
        amenities: _amenities,
        photos: photoUrls,
        available: true,
        imageUrl: photoUrls.isNotEmpty ? photoUrls.first : null,
        powerKw: 7.2,
        rating: 0.0,
        reviewCount: 0,
        availableSlots: _availableSlots,
        totalSlots: _availableSlots.length,
        occupiedSlots: 0,
        createdAt: DateTime.now(),
      );

      await ref.read(chargerServiceProvider).createCharger(charger);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Charger added successfully!')),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Charger')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(labelText: 'Address'),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Parking details, access instructions, etc.',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(labelText: 'Price Per Hour'),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Required';
                  }

                  final price = double.tryParse(v.trim());
                  if (price == null) {
                    return 'Enter a valid number';
                  }
                  if (price < 5 || price > 50) {
                    return 'Price must be between ₹5 and ₹50';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _connectorType,
                decoration: const InputDecoration(labelText: 'Connector Type'),
                items: _connectorTypes.map((type) {
                  return DropdownMenuItem(value: type, child: Text(type));
                }).toList(),
                onChanged: (v) => setState(() => _connectorType = v!),
              ),
              const SizedBox(height: 24),
              const Text(
                'Amenities',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Wrap(
                spacing: 8.0,
                children: _availableAmenities.map((amenity) {
                  final isSelected = _amenities.contains(amenity);
                  return FilterChip(
                    label: Text(amenity),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _amenities.add(amenity);
                        } else {
                          _amenities.remove(amenity);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              const Text(
                'Available Slots',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Wrap(
                spacing: 8.0,
                children: _allSlots.map((slot) {
                  final isSelected = _availableSlots.contains(slot);
                  return FilterChip(
                    label: Text(slot),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _availableSlots.add(slot);
                        } else {
                          _availableSlots.remove(slot);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              const Text(
                'Photos',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ..._photos.map(
                    (xfile) => FutureBuilder<Uint8List>(
                      future: xfile.readAsBytes(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return Container(
                            width: 100,
                            height: 100,
                            color: Colors.grey.shade200,
                            child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                          );
                        }
                        return Image.memory(
                          snapshot.data!,
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                        );
                      },
                    ),
                  ),
                  GestureDetector(
                    onTap: _pickImages,
                    child: Container(
                      width: 100,
                      height: 100,
                      color: Colors.grey.shade200,
                      child: const Icon(Icons.add_a_photo),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Add Charger'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

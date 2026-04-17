import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import '../models/charger_model.dart';
import '../providers/charger_provider.dart';
import '../../auth/providers/auth_provider.dart';
import 'package:go_router/go_router.dart';

class AddChargerScreen extends ConsumerStatefulWidget {
  const AddChargerScreen({super.key});

  @override
  ConsumerState<AddChargerScreen> createState() => _AddChargerScreenState();
}

class _AddChargerScreenState extends ConsumerState<AddChargerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _addressController = TextEditingController();
  final _priceController = TextEditingController();
  
  String _connectorType = 'Type 2';
  final List<String> _amenities = [];
  final List<File> _photos = [];
  bool _isLoading = false;

  final _availableAmenities = ['WiFi', 'Restroom', 'Cafe', 'Shopping'];
  final _connectorTypes = ['Type 1', 'Type 2', 'CCS1', 'CCS2', 'CHAdeMO', 'Tesla'];

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage();
    if (pickedFiles.isNotEmpty) {
      setState(() {
        _photos.addAll(pickedFiles.map((x) => File(x.path)));
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    final user = ref.read(userProvider);
    if (user == null) return;

    setState(() => _isLoading = true);
    try {
      final chargerId = const Uuid().v4();
      final photoUrls = <String>[];

      // Upload photos
      for (var photo in _photos) {
        final fileName = '${const Uuid().v4()}.jpg';
        final refPath = 'chargers/$chargerId/$fileName';
        final storageRef = FirebaseStorage.instance.ref().child(refPath);
        await storageRef.putFile(photo);
        final downloadUrl = await storageRef.getDownloadURL();
        photoUrls.add(downloadUrl);
      }

      // In real app, we use google_maps_webservice for lat/lng based on address
      // Here we mock the coordinates for simplicity
      final lat = 37.7749;
      final lng = -122.4194;

      final charger = ChargerModel(
        id: chargerId,
        hostUid: user.uid,
        title: _titleController.text.trim(),
        description: '', // Optional field
        address: _addressController.text.trim(),
        lat: lat,
        lng: lng,
        pricePerHour: double.parse(_priceController.text.trim()),
        connectorType: _connectorType,
        amenities: _amenities,
        isAvailable: true,
        photos: photoUrls,
        rating: 0.0,
        reviewCount: 0,
        createdAt: DateTime.now(),
      );

      await ref.read(chargerServiceProvider).createCharger(charger);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Charger added successfully!')));
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
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
                controller: _priceController,
                decoration: const InputDecoration(labelText: 'Price Per Hour'),
                keyboardType: TextInputType.number,
                validator: (v) => v!.isEmpty ? 'Required' : null,
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
              const Text('Amenities', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
              const Text('Photos', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ..._photos.map((file) => Image.file(file, width: 100, height: 100, fit: BoxFit.cover)),
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
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                child: _isLoading 
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Add Charger'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

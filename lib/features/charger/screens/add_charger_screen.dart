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
import 'package:google_fonts/google_fonts.dart';

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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Register Station',
          style: GoogleFonts.inter(
            color: const Color(0xFF111827),
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF111827)),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _titleController,
                style: GoogleFonts.inter(fontSize: 15),
                decoration: const InputDecoration(
                  labelText: 'Station Name',
                  prefixIcon: Icon(Icons.bolt_rounded, size: 20),
                ),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressController,
                style: GoogleFonts.inter(fontSize: 15),
                decoration: const InputDecoration(
                  labelText: 'Exact Address',
                  prefixIcon: Icon(Icons.location_on_outlined, size: 20),
                ),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                style: GoogleFonts.inter(fontSize: 15),
                decoration: const InputDecoration(
                  labelText: 'Description',
                  alignLabelWithHint: true,
                  hintText: 'Parking details, access instructions, etc.',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _priceController,
                style: GoogleFonts.inter(fontSize: 15),
                decoration: const InputDecoration(
                  labelText: 'Price per Hour',
                  prefixIcon: Padding(
                    padding: EdgeInsets.all(14),
                    child: Text('₹', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF22C55E))),
                  ),
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Required';
                  }

                  final price = double.tryParse(v.trim());
                  if (price == null) {
                    return 'Enter a valid number';
                  }
                  if (price < 5 || price > 500) {
                    return 'Enter realistic price';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _connectorType,
                style: GoogleFonts.inter(fontSize: 15, color: const Color(0xFF111827)),
                decoration: const InputDecoration(
                  labelText: 'Connector Type',
                  prefixIcon: Icon(Icons.power_rounded, size: 20),
                ),
                items: _connectorTypes.map((type) {
                  return DropdownMenuItem(value: type, child: Text(type));
                }).toList(),
                onChanged: (v) => setState(() => _connectorType = v!),
              ),
              const SizedBox(height: 24),
              Text(
                'Amenities',
                style: GoogleFonts.inter(
                  fontSize: 16, 
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF111827),
                ),
              ),
              Wrap(
                spacing: 8.0,
                children: _availableAmenities.map((amenity) {
                  final isSelected = _amenities.contains(amenity);
                  return FilterChip(
                    label: Text(amenity),
                    labelStyle: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected ? const Color(0xFF166534) : const Color(0xFF374151),
                    ),
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
                    backgroundColor: const Color(0xFFF3F4F6),
                    selectedColor: const Color(0xFFDCFCE7),
                    checkmarkColor: const Color(0xFF166534),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              Text(
                'Available Slots',
                style: GoogleFonts.inter(
                  fontSize: 16, 
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF111827),
                ),
              ),
              Wrap(
                spacing: 8.0,
                children: _allSlots.map((slot) {
                  final isSelected = _availableSlots.contains(slot);
                  return FilterChip(
                    label: Text(slot),
                    labelStyle: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected ? const Color(0xFF166534) : const Color(0xFF374151),
                    ),
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
                    backgroundColor: const Color(0xFFF3F4F6),
                    selectedColor: const Color(0xFFDCFCE7),
                    checkmarkColor: const Color(0xFF166534),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              Text(
                'Photos',
                style: GoogleFonts.inter(
                  fontSize: 16, 
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF111827),
                ),
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
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF111827),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          'Register Station',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/services/user_service.dart';
import '../../auth/models/user_model.dart';

final userServiceProvider = Provider(
  (ref) => UserService(FirebaseFirestore.instance),
);

final currentUserModelProvider = FutureProvider<UserModel?>((ref) async {
  final user = ref.watch(userProvider);
  if (user == null) return null;
  return ref.read(userServiceProvider).getUser(user.uid);
});

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isLoading = false;
  bool _isUploading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImage() async {
    final user = ref.read(userProvider);
    if (user == null) return;

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile == null) return;

    setState(() => _isUploading = true);
    try {
      final file = File(pickedFile.path);
      final refPath = 'users/\${user.uid}/avatar.jpg';
      final storageRef = FirebaseStorage.instance.ref().child(refPath);

      await storageRef.putFile(file);
      final downloadUrl = await storageRef.getDownloadURL();

      await ref.read(userServiceProvider).updateUser(user.uid, {
        'photoUrl': downloadUrl,
      });
      ref.invalidate(currentUserModelProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _updateProfile() async {
    final user = ref.read(userProvider);
    if (user == null) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(userServiceProvider).updateUser(user.uid, {
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
      });
      ref.invalidate(currentUserModelProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully')),
      );
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
    final userAsync = ref.watch(currentUserModelProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Profile')),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: \$err')),
        data: (userModel) {
          if (userModel == null)
            return const Center(child: Text('User not found.'));

          if (_nameController.text.isEmpty && userModel.name.isNotEmpty) {
            _nameController.text = userModel.name;
          }
          if (_phoneController.text.isEmpty && userModel.phone != null) {
            _phoneController.text = userModel.phone!;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                GestureDetector(
                  onTap: _pickAndUploadImage,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundImage: userModel.photoUrl != null
                            ? NetworkImage(userModel.photoUrl!)
                            : null,
                        child: userModel.photoUrl == null
                            ? const Icon(Icons.person, size: 50)
                            : null,
                      ),
                      if (_isUploading)
                        const Positioned.fill(
                          child: CircularProgressIndicator(),
                        ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            size: 20,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: userModel.role == 'host'
                        ? Colors.blue.shade100
                        : Colors.green.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    userModel.role.toUpperCase(),
                    style: TextStyle(
                      color: userModel.role == 'host'
                          ? Colors.blue.shade900
                          : Colors.green.shade900,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Full Name'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _phoneController,
                  decoration: const InputDecoration(labelText: 'Phone Number'),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading ? null : _updateProfile,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save Changes'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

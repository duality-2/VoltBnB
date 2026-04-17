import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/firebase_service_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _firebaseInitialized = false;
  String _status = 'Checking Firebase...';
  String _error = '';

  @override
  void initState() {
    super.initState();
    _checkFirebaseStatus();
  }

  Future<void> _checkFirebaseStatus() async {
    try {
      setState(() {
        _status = 'Checking Firebase...';
        _error = '';
      });

      // Check if Firebase Auth is initialized
      final auth = ref.read(firebaseAuthProvider);
      final currentUser = auth.currentUser;

      // Check Firestore connection by trying to read the chargers collection
      final firestore = ref.read(firebaseFirestoreProvider);

      // This will test the connection without requiring authentication
      final snapshot = await firestore
          .collection('chargers')
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 5));

      setState(() {
        _firebaseInitialized = true;
        _status = '✅ Firebase Connected!\n\n';
        _status +=
            'Auth Status: ${currentUser != null ? "Logged in (${currentUser.email})" : "Not logged in"}\n';
        _status += 'Firestore: Connected\n';
        _status += 'Available Chargers: ${snapshot.size}';
      });
    } catch (e) {
      setState(() {
        _firebaseInitialized = false;
        _status = '❌ Firebase Connection Issue';
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('VoltBnB'),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final auth = ref.read(firebaseAuthProvider);
              await auth.signOut();
              if (context.mounted) {
                context.go('/login');
              }
            },
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: _firebaseInitialized
                      ? Colors.green[50]
                      : Colors.red[50],
                  border: Border.all(
                    color: _firebaseInitialized
                        ? Colors.green[300]!
                        : Colors.red[300]!,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      _status,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        height: 1.6,
                      ),
                    ),
                    if (_error.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Error: $_error',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red[900],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _checkFirebaseStatus,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry Connection'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
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

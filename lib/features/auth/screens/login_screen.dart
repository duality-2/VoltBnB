import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../providers/auth_provider.dart';
import '../../../core/providers/firebase_service_provider.dart';
import '../models/user_model.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String _error = '';

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() => _error = 'Please fill in all fields');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final authService = ref.watch(authServiceProvider);
      final userService = ref.watch(userServiceProvider);

      final userCredential = await authService.signInWithEmail(
        _emailController.text.trim(),
        _passwordController.text,
      );

      // Save FCM token for push notifications
      if (userCredential.user != null) {
        final fcmToken = await FirebaseMessaging.instance.getToken();
        if (fcmToken != null) {
          await userService.saveFcmToken(userCredential.user!.uid, fcmToken);
        }
      }

      if (mounted) {
        context.go('/');
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _googleLogin() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final authService = ref.read(authServiceProvider);
      final userService = ref.read(userServiceProvider);
      final userCredential = await authService.signInWithGoogle();
      
      if (userCredential == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      if (userCredential.user != null) {
        // Ensure user document exists in Firestore
        final existingUser = await userService.getUser(userCredential.user!.uid);
        if (existingUser == null) {
          // Create new user defaulted to renter
          final userModel = UserModel(
            uid: userCredential.user!.uid,
            email: userCredential.user!.email ?? '',
            name: userCredential.user!.displayName ?? 'Guest',
            role: 'renter',
            createdAt: DateTime.now(),
          );
          await userService.createUser(userModel);
        }

        final fcmToken = await FirebaseMessaging.instance.getToken();
        if (fcmToken != null) {
          await userService.saveFcmToken(userCredential.user!.uid, fcmToken);
        }
      }

      if (mounted) {
        context.go('/');
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('VoltBnB Login')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 40),
            const Text(
              'Welcome to VoltBnB',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                hintText: 'Email',
                prefixIcon: const Icon(Icons.email),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(
                hintText: 'Password',
                prefixIcon: const Icon(Icons.lock),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              obscureText: true,
            ),
            if (_error.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_error, style: TextStyle(color: Colors.red[900])),
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _login,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Login'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _isLoading ? null : _googleLogin,
              icon: const Icon(Icons.login),
              label: const Text('Continue with Google'),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => context.push('/forgot-password'),
                child: const Text('Forgot Password?'),
              ),
            ),

            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("Don't have an account? "),
                TextButton(
                  onPressed: () => context.go('/signup'),
                  child: const Text('Sign Up'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

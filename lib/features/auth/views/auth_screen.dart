import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/auth_service.dart';
import '../../home/views/home_screen.dart';
import 'pin_auth_screen.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthRequired();
  }

  Future<void> _checkAuthRequired() async {
    final authService = ref.read(authServiceProvider);
    final hasPin = await authService.hasPinCode();

    if (hasPin) {
      // Show PIN auth screen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const PinAuthScreen()),
      );
    } else {
      // No PIN required, go to home
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
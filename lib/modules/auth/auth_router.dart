import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/app_provider.dart';
import 'sign_in_screen.dart';
import '../pairing/pairing_screen.dart';
import '../dashboard/dashboard_screen.dart';

class AuthRouter extends StatelessWidget {
  const AuthRouter({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    if (provider.isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: Color(0xFF1AB8B8),
          ),
        ),
      );
    }

    if (!provider.isAuthenticated) {
      return const SignInScreen();
    }

    if (!provider.isPaired) {
      return const PairingScreen();
    }

    return const DashboardScreen();
  }
}
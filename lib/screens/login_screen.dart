// lib/screens/login_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/auth_controller.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart'; // Add this dependency to your pubspec.yaml

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthController>();

    return Obx(() {
      // Show a loading indicator while the auth controller is initializing or signing in
      if (auth.status.value == AuthStatus.loading) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }

      // If already authenticated, the auth gate will route to the home screen
      if (auth.status.value == AuthStatus.authenticated) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }

      final hasError = auth.status.value == AuthStatus.error && auth.errorMessage.isNotEmpty;

      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFFE0F7FA), // Light Cyan
                Color(0xFFB3E5FC), // Light Blue
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 50),
                    // App Logo or Icon
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.8),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.account_balance_wallet, // Wallet icon for expense tracker
                          size: 80,
                          color: Color(0xFF0277BD), // Dark Blue
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    // Welcome Text
                    Text(
                      'Welcome to\nYour Expense Tracker',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF01579B), // Even darker blue for contrast
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Subtitle or tagline
                    Text(
                      'Manage your finances with ease.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: const Color(0xFF0277BD),
                      ),
                    ),
                    const SizedBox(height: 40),
                    // Error Message
                    if (hasError)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 24.0),
                        child: Text(
                          auth.errorMessage.value,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    // Google Sign-In Button
                    ElevatedButton.icon(
                      icon: const FaIcon(FontAwesomeIcons.google, color: Colors.white),
                      label: const Text(
                        'Sign in with Google',
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
                      onPressed: auth.status.value == AuthStatus.loading
                          ? null
                          : () async {
                              await auth.signInWithGoogle();
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4285F4), // Google's brand color
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        elevation: 5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    });
  }
}
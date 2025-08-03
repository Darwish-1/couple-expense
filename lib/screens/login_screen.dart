import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return FutureBuilder(
      future: authProvider.waitForInitialization(),
      builder: (context, snapshot) {
        // Still initializing (e.g. checking existing sign-in)
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Initialization error
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Initialization error',
                    style: TextStyle(color: Colors.redAccent, fontSize: 16),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                    ),
                    child: const Text('Retry', style: TextStyle(fontSize: 16)),
                  ),
                ],
              ),
            ),
          );
        }

        // If already signed in (e.g. after logout → new login), jump to home
        if (authProvider.status == AuthStatus.authenticated) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushReplacementNamed(context, '/home');
          });
          // Show a brief spinner while the navigation happens
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Otherwise, show the login UI
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: Center(
            child: authProvider.status == AuthStatus.loading
                ? const CircularProgressIndicator(color: Colors.blue)
                : authProvider.status == AuthStatus.error
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            authProvider.errorMessage ?? 'An error occurred',
                            style: const TextStyle(color: Colors.redAccent, fontSize: 16),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.refresh, color: Colors.white),
                            label: const Text('Retry Sign-In', style: TextStyle(fontSize: 16, color: Colors.white)),
                            onPressed: authProvider.signInWithGoogle,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Welcome to Expense Tracker',
                            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.login, color: Colors.white),
                            label: const Text('Sign in with Google', style: TextStyle(fontSize: 16, color: Colors.white)),
                            onPressed: () async {
                              await authProvider.signInWithGoogle();
                              if (!context.mounted) return;
                              authProvider.showError(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                            ),
                          ),
                        ],
                      ),
          ),
        );
      },
    );
  }
}

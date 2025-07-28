import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

     return Scaffold(
      body: Center(
        child: ElevatedButton.icon(
          icon: const Icon(Icons.login),
          label: const Text("Sign in with Google"),
        onPressed: () async {
  await auth.signInWithGoogle();

  // Make sure the widget is still in the tree
  if (!context.mounted) return;

  if (auth.status == AuthStatus.unauthenticated) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Login cancelled")),
    );
  } else if (auth.status == AuthStatus.error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Error: ${auth.errorMessage}")),
    );
  }
}

        ),
      ),
    );
  }
}

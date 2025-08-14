// lib/main.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'firebase_options.dart'; // <-- use your generated options
import 'controllers/auth_controller.dart';
import 'screens/login_screen.dart';
import 'screens/expenses_root_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // IMPORTANT: initialize with generated options so release builds use the right project
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint('dotenv not loaded: $e');
  }

  // Register AuthController (permanent)
  Get.put(
    AuthController(
      clientId: dotenv.maybeGet('GSI_CLIENT_ID'),
      serverClientId: dotenv.maybeGet('GSI_SERVER_CLIENT_ID'),
    ),
    permanent: true,
  );
  debugPrint('Cold start: currentUser = ${FirebaseAuth.instance.currentUser?.uid}');

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Expense Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.grey[100],
        appBarTheme: const AppBarTheme(
          elevation: 0,
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(vertical: 15),
          ),
        ),
      ),
      home: const AuthGate(),
    );
  }
}

/// AuthGate that waits until Firebase finishes restoring the session for this process.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      // authStateChanges() is ideal for “signed in/out” decisions and avoids early nulls
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        // While Firebase is restoring the user, keep the splash/loader
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final user = snap.data; // will be non-null if a cached session exists
        if (user == null) {
          return const LoginScreen();
        }
        return const ExpensesRootScreen();
      },
    );
  }
}

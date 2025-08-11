// lib/main.dart (only the additions/changes shown)
import 'package:couple_expenses/controllers/wallet_controller.dart';
import 'package:couple_expenses/screens/expenses_root_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'screens/login_screen.dart';
import 'screens/my_expenses_screen.dart';
import 'screens/shared_expenses_screen.dart';
import 'controllers/auth_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint('dotenv not loaded: $e');
  }

  // 👇 Register AuthController with your client IDs (optional)
  Get.put(
    AuthController(
      clientId: dotenv.maybeGet('GSI_CLIENT_ID'),
      serverClientId: dotenv.maybeGet('GSI_SERVER_CLIENT_ID'),
    ),
    permanent: true,
  );
Get.put(WalletController(), permanent: true);

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
      home: const _AuthGate(),
      getPages: [
        GetPage(name: '/login', page: () => const LoginScreen()),
        GetPage(name: '/expenses', page: () => MyExpensesScreen()),
        GetPage(name: '/shared', page: () => SharedExpensesScreen()),
      ],
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    // Using FirebaseAuth stream is fine; AuthController listens too.
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final user = snap.data;
        if (user == null) {
          return const LoginScreen();
        }
        return ExpensesRootScreen();
      },
    );
  }
}

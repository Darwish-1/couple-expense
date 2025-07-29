import 'package:couple_expenses/providers/home_screen_provider.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/wallet_provider.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Future<void> _initializeFirebase() async {
    await Firebase.initializeApp();
    try {
      await dotenv.load(fileName: ".env");
    } catch (e) {
      debugPrint('Error loading .env file: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _initializeFirebase(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const MaterialApp(
            home: Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        if (snapshot.hasError) {
          return MaterialApp(
            home: Scaffold(
              body: Center(
                child: Text('Initialization error: ${snapshot.error}'),
              ),
            ),
          );
        }
        return MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => WalletProvider()),
            ChangeNotifierProvider(create: (_) => HomeScreenProvider()),
            ChangeNotifierProxyProvider<WalletProvider, AuthProvider>(
              create: (context) => AuthProvider(walletProvider: context.read<WalletProvider>()),
              update: (context, walletProvider, authProvider) => authProvider ?? AuthProvider(walletProvider: walletProvider),
            ),
          ],
          child: MaterialApp(
            title: 'Expense Tracker',
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
            routes: {
              '/login': (context) => const LoginScreen(),
              '/home': (context) => const HomeScreen(),
            },
            home: Consumer<AuthProvider>(
              builder: (context, auth, _) {
                switch (auth.status) {
                  case AuthStatus.loading:
                    return const Scaffold(
                      body: Center(child: CircularProgressIndicator()),
                    );
                  case AuthStatus.authenticated:
                    return const HomeScreen();
                  case AuthStatus.unauthenticated:
                    return const LoginScreen();
                  case AuthStatus.error:
                    return Scaffold(
                      body: Center(
                        child: Text('Error: ${auth.errorMessage ?? "An error occurred"}'),
                      ),
                    );
                  default:
                    return const LoginScreen();
                }
              },
            ),
          ),
        );
      },
    );
  }
}
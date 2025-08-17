// lib/main.dart
import 'package:couple_expenses/controllers/expenses_controller.dart';
import 'package:couple_expenses/screens/auth_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:sizer/sizer.dart';

import 'firebase_options.dart';
import 'controllers/auth_controller.dart';
import 'controllers/theme_controller.dart';


// ⬇️ add this import
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint('dotenv not loaded: $e');
  }
  debugPrint(
    'AZURE=${dotenv.env['AZURE_SPEECH_KEY']?.substring(0,6)}..., '
    'PROJ=${dotenv.env['GCP_PROJECT_ID']}',
  );
  // Controllers
  final assetPath = dotenv.env['GCP_SA_ASSET'];
try {
  final bytes = await rootBundle.load(assetPath!);
  debugPrint('SA asset OK: $assetPath (${bytes.lengthInBytes} bytes)');
} catch (e) {
  debugPrint('SA asset MISSING: $assetPath -> $e');
}
 Get.put(
    AuthController(
      clientId: dotenv.maybeGet('GSI_CLIENT_ID'),
      serverClientId: dotenv.maybeGet('GSI_SERVER_CLIENT_ID'),
    ),
    permanent: true,
  );
  Get.put(ThemeController(), permanent: true);

  // ⬇️ Register ExpensesController globally so MicController can find it
  Get.put(
    ExpensesController(collectionName: 'expenses'),
    permanent: true,
  );

  debugPrint('Cold start: currentUser = ${FirebaseAuth.instance.currentUser?.uid}');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Get.find<ThemeController>();

    return Sizer(
      builder: (context, orientation, deviceType) {
        return Obx(() {
          final isDark = theme.isDark.value;
          return GetMaterialApp(
            title: 'Expense Tracker',
            debugShowCheckedModeBanner: false,

            // ⬇️ use the global theme
            theme: AppTheme.light,

            // keep dark mode toggle working; swap in a custom AppTheme.dark later if you want
            themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
            darkTheme: ThemeData.dark(),

            home: const AuthGate(),
          );
        });
      },
    );
  }
}


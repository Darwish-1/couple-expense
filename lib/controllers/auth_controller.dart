// lib/controllers/auth_controller.dart
import 'dart:developer';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'mic_controller.dart';
import 'wallet_controller.dart';
import 'expenses_controller.dart';
import 'expense_summary_controller.dart';

enum AuthStatus { loading, authenticated, unauthenticated, error }

class AuthController extends GetxController {
  AuthController({
    this.clientId,
    this.serverClientId,
  });

  final String? clientId;        // optional iOS client ID
  final String? serverClientId;  // optional Web client ID (recommended)

  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  final GoogleSignIn _gsi = GoogleSignIn.instance;

  final Rx<AuthStatus> status = AuthStatus.loading.obs;
  final Rxn<User> user = Rxn<User>();
  final RxString errorMessage = ''.obs;

  bool _gotFirstAuthEvent = false;

  @override
  void onInit() {
    super.onInit();
    _initGoogleSignIn();

    // Seed from cache so we don't flash unauthenticated on cold start
    final cached = _auth.currentUser;
    if (cached != null) {
      user.value = cached;
      status.value = AuthStatus.authenticated;
    }

    _auth.userChanges().listen((u) async {
      _gotFirstAuthEvent = true;
      user.value = u;

      if (u == null) {
        status.value = AuthStatus.unauthenticated;
        return;
      }

      try {
        await _ensureUserDoc(u);

        // Ensure wallet controller once authenticated
        if (!Get.isRegistered<WalletController>()) {
          Get.put(WalletController(), permanent: true);
        }

        status.value = AuthStatus.authenticated;
      } catch (e) {
        errorMessage.value = 'Initialization failed: $e';
        status.value = AuthStatus.error;
      }
    }, onError: (e) {
      errorMessage.value = 'Auth stream error: $e';
      status.value = AuthStatus.error;
    });

    // Keep "loading" until we get first auth event
    ever<AuthStatus>(status, (s) {
      if (!_gotFirstAuthEvent && s != AuthStatus.error) {
        status.value = AuthStatus.loading;
      }
    });
  }

  Future<void> _initGoogleSignIn() async {
    try {
      await _gsi.initialize(
        clientId: clientId,
        serverClientId: serverClientId,
      );
      // Do NOT call attemptLightweightAuthentication() here.
    } catch (e) {
      errorMessage.value = 'Failed to initialize Google Sign-In: $e';
      status.value = AuthStatus.error;
      log('GSI init error: $e');
    }
  }

  /// v7 flow: authenticate() -> account.authentication.idToken -> Firebase credential
  Future<void> signInWithGoogle() async {
    try {
      status.value = AuthStatus.loading;

      if (!await _gsi.supportsAuthenticate()) {
        throw 'Platform does not support Google authenticate()';
      }

      final GoogleSignInAccount? account = await _gsi.authenticate();
      if (account == null) {
        status.value = AuthStatus.unauthenticated;
        return;
      }

      final GoogleSignInAuthentication tokens = await account.authentication;
      final String? idToken = tokens.idToken;
      if (idToken == null) throw 'Google idToken is null';

      final credential = GoogleAuthProvider.credential(idToken: idToken);
      final result = await _auth.signInWithCredential(credential);
      final u = result.user;
      if (u == null) throw 'Firebase user is null';

      await _ensureUserDoc(u);

      status.value = AuthStatus.authenticated;
    } catch (e) {
      errorMessage.value = 'Sign-in failed: $e';
      status.value = AuthStatus.error;
      log('signInWithGoogle error: $e');
    }
  }

  /// Full logout: stop all streams/controllers, then sign out of Firebase & Google.
  Future<void> signOut() async {
    try {
      status.value = AuthStatus.loading;

      // 1) Stop Firestore stream sources BEFORE auth goes null
      _cleanupAppState();

      // 2) Sign out of Firebase
      await _auth.signOut();

      // 3) Disconnect Google (clears chooser cache)
      try {
        await _gsi.disconnect();
      } catch (_) {}

      // 4) Done – AuthGate will rebuild to Login
      status.value = AuthStatus.unauthenticated;
    } catch (e) {
      errorMessage.value = 'Error signing out: $e';
      status.value = AuthStatus.error;
    }
  }

  void _cleanupAppState() {
    // Expenses
    if (Get.isRegistered<ExpensesController>(tag: 'my')) {
      Get.delete<ExpensesController>(tag: 'my', force: true);
    }
    if (Get.isRegistered<ExpensesController>(tag: 'shared')) {
      Get.delete<ExpensesController>(tag: 'shared', force: true);
    }

    // Summaries
    if (Get.isRegistered<ExpenseSummaryController>(tag: 'my')) {
      Get.delete<ExpenseSummaryController>(tag: 'my', force: true);
    }
    if (Get.isRegistered<ExpenseSummaryController>(tag: 'shared')) {
      Get.delete<ExpenseSummaryController>(tag: 'shared', force: true);
    }

    // Mic (defensive; usually disposed by screen)
    if (Get.isRegistered<MicController>()) {
      Get.delete<MicController>(force: true);
    }

    // Wallet (permanent) – delete to stop its snapshots immediately
    if (Get.isRegistered<WalletController>()) {
      Get.delete<WalletController>(force: true);
    }
  }

  Future<void> _ensureUserDoc(User u) async {
    final ref = _db.collection('users').doc(u.uid);
    final snap = await ref.get();
    if (!snap.exists) {
  await ref.set({
    'uid': u.uid,
    'name': u.displayName,
    'email': u.email,
    'joinedAt': FieldValue.serverTimestamp(),
    'has_seen_tutorial': false, // 👈 add this
  });
}
  }
}

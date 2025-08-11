// lib/controllers/auth_controller.dart
import 'dart:developer';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'wallet_controller.dart';

enum AuthStatus { loading, authenticated, unauthenticated, error }

class AuthController extends GetxController {
  AuthController({
    this.clientId,        // optional iOS client ID
    this.serverClientId,  // optional Web client ID (recommended)
  });

  final String? clientId;
  final String? serverClientId;

  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  final GoogleSignIn _gsi = GoogleSignIn.instance;

  final Rx<AuthStatus> status = AuthStatus.loading.obs;
  final Rxn<User> user = Rxn<User>();
  final RxString errorMessage = ''.obs;

  @override
  void onInit() {
    super.onInit();
    _initGoogleSignIn();

    // React to Firebase auth state
    _auth.authStateChanges().listen((u) async {
      user.value = u;
      if (u == null) {
        status.value = AuthStatus.unauthenticated;
        return;
      }
      try {
        await _ensureUserDoc(u);
      if (!Get.isRegistered<WalletController>()) {
  Get.put(WalletController(), permanent: true);
}
        status.value = AuthStatus.authenticated;
      } catch (e) {
        errorMessage.value = 'Initialization failed: $e';
        status.value = AuthStatus.error;
      }
    });
  }

  Future<void> _initGoogleSignIn() async {
    try {
      await _gsi.initialize(
        clientId: clientId,
        serverClientId: serverClientId,
      );
      // IMPORTANT: do NOT call attemptLightweightAuthentication() here.
      // It may show a chooser automatically and you’re not handling its result.
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

      // Wallet will be ensured by the authStateChanges listener
      status.value = AuthStatus.authenticated;
    } catch (e) {
      errorMessage.value = 'Sign-in failed: $e';
      status.value = AuthStatus.error;
      log('signInWithGoogle error: $e');
    }
  }

  Future<void> signOut() async {
    try {
      await _gsi.disconnect(); // clears local GSI session
      await _auth.signOut();
      status.value = AuthStatus.unauthenticated;
    } catch (e) {
      errorMessage.value = 'Error signing out: $e';
      status.value = AuthStatus.error;
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
      });
    }
  }
}

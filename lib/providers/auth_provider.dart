import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum AuthStatus { loading, authenticated, unauthenticated, error }

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  User? user;
  String? walletId;
  AuthStatus status = AuthStatus.loading;
  String? errorMessage;
  bool _isInitialized = false;

  AuthProvider() {
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await initGoogleSignIn();
      await _checkAuthStatus();
      _isInitialized = true;
    } catch (e) {
      status = AuthStatus.error;
      errorMessage = 'Initialization failed: $e';
      print('AuthProvider initialize: Error - $e');
    }
    notifyListeners();
  }

  Future<void> waitForInitialization() async {
    if (!_isInitialized) {
      await Future.doWhile(() async {
        await Future.delayed(const Duration(milliseconds: 100));
        return !_isInitialized;
      });
    }
  }

  Future<void> initGoogleSignIn() async {
    try {
      await _googleSignIn.initialize(
        clientId: '522253883024-cla8rlb3sonuqnokh2jhvairj3iri49t.apps.googleusercontent.com',
        serverClientId: '522253883024-cla8rlb3sonuqnokh2jhvairj3iri49t.apps.googleusercontent.com',
      );
      print('initGoogleSignIn: GoogleSignIn initialized');
    } catch (e) {
      errorMessage = 'Failed to initialize GoogleSignIn: $e';
      status = AuthStatus.error;
      print('initGoogleSignIn: Error - $e');
      notifyListeners();
      throw e;
    }
  }

  Future<void> _checkAuthStatus() async {
    try {
      user = _auth.currentUser;
      if (user != null) {
        await _loadWallet(user!);
        status = AuthStatus.authenticated;
        print('AuthStatus set to authenticated. User UID: ${user!.uid}, Wallet ID: $walletId');
      } else {
        status = AuthStatus.unauthenticated;
        print('AuthStatus set to unauthenticated');
      }
    } catch (e) {
      status = AuthStatus.error;
      errorMessage = 'Error checking auth status: $e';
      print('checkAuthStatus: Error - $e');
      notifyListeners();
      throw e;
    }
  }

  Future<void> signInWithGoogle() async {
    try {
      status = AuthStatus.loading;
      notifyListeners();

      if (!await _googleSignIn.supportsAuthenticate()) {
        errorMessage = 'Platform does not support Google authenticate()';
        status = AuthStatus.error;
        notifyListeners();
        return;
      }

      final GoogleSignInAccount? account = await _googleSignIn.authenticate();
      if (account == null) {
        status = AuthStatus.unauthenticated;
        notifyListeners();
        return;
      }

      final GoogleSignInAuthentication auth = await account.authentication;

      final credential = GoogleAuthProvider.credential(
        idToken: auth.idToken,
      );

      final result = await _auth.signInWithCredential(credential);
      user = result.user;

      if (user == null) {
        status = AuthStatus.error;
        errorMessage = 'Firebase user is null';
        notifyListeners();
        return;
      }

      final userDoc = _firestore.collection('users').doc(user!.uid);
      if (!(await userDoc.get()).exists) {
        await userDoc.set({
          'uid': user!.uid,
          'name': user!.displayName,
          'email': user!.email,
          'joinedAt': FieldValue.serverTimestamp(),
        });
      }

      final walletsQuery = await _firestore
          .collection('wallets')
          .where('members', arrayContains: user!.uid)
          .limit(1)
          .get();

      if (walletsQuery.docs.isEmpty) {
        final walletRef = _firestore.collection('wallets').doc();
        await walletRef.set({
          'name': "${user!.displayName}'s Wallet",
          'members': [user!.uid],
          'createdAt': FieldValue.serverTimestamp(),
        });
        walletId = walletRef.id;
        print('New wallet created with ID: $walletId');
      } else {
        walletId = walletsQuery.docs.first.id;
        print('Existing wallet found with ID: $walletId');
      }

      status = AuthStatus.authenticated;
      print('AuthStatus set to authenticated. User UID: ${user!.uid}');
      notifyListeners();
    } catch (e) {
      status = AuthStatus.error;
      errorMessage = 'Sign-in failed: $e';
      print('signInWithGoogle: Error - $e');
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
      user = null;
      walletId = null;
      status = AuthStatus.unauthenticated;
      errorMessage = null;
      print('signOut: User signed out');
      notifyListeners();
    } catch (e) {
      errorMessage = 'Error signing out: $e';
      print('signOut: Error - $e');
      notifyListeners();
    }
  }

  Future<void> updateWalletId(String? newWalletId) async {
    walletId = newWalletId;
    print('updateWalletId: Wallet ID set to $newWalletId');
    notifyListeners();
  }

  Future<void> _loadWallet(User user) async {
    try {
      final walletsQuery = await _firestore
          .collection('wallets')
          .where('members', arrayContains: user.uid)
          .limit(1)
          .get();

      if (walletsQuery.docs.isNotEmpty) {
        walletId = walletsQuery.docs.first.id;
        print('loadWallet: Wallet ID loaded - $walletId');
      } else {
        walletId = null;
        status = AuthStatus.error;
        errorMessage = 'Wallet not found for user ${user.uid}';
        print('loadWallet: Wallet not found for user ${user.uid}');
      }
    } catch (e) {
      status = AuthStatus.error;
      errorMessage = 'Error loading wallet: $e';
      print('loadWallet: Error - $e');
      notifyListeners();
    }
  }

  void showError(BuildContext context) {
    if (errorMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage!),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 5),
          ),
        );
      });
    }
  }
}
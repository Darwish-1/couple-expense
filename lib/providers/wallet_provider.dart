import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'auth_provider.dart';

class WalletProvider extends ChangeNotifier {
   String _partnerName = '';
  String get partnerName => _partnerName;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? walletId;
  String? errorMessage;
  DocumentSnapshot? wallet;
  List<Map<String, String>> memberData = [];
  bool loading = false;

  WalletProvider() {
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user != null) {
        fetchWallet(user.uid);
      } else {
        wallet = null;
        walletId = null;
        memberData.clear();
        notifyListeners();
      }
    });
  }

  Future<bool> createWallet(String userId, String userDisplayName, BuildContext context) async {
    try {
      loading = true;
      notifyListeners();
      final walletRef = _firestore.collection('wallets').doc();
      await walletRef.set({
        'name': "$userDisplayName's Wallet",
        'members': [userId],
        'ownerUid': userId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      walletId = walletRef.id;
      await Provider.of<AuthProvider>(context, listen: false).updateWalletId(walletId);
      await fetchWallet(userId);
      errorMessage = null;
      loading = false;
      debugPrint('Wallet created with ID: $walletId');
      notifyListeners();
      return true;
    } catch (e) {
      errorMessage = 'Failed to create wallet';
      loading = false;
      debugPrint('Create wallet error: $e');
      notifyListeners();
      return false;
    }
  }

  Future<bool> joinWallet(String walletIdToJoin, String userId, BuildContext context) async {
    try {
      loading = true;
      notifyListeners();
      final walletRef = _firestore.collection('wallets').doc(walletIdToJoin);
      final walletDoc = await walletRef.get();

      if (!walletDoc.exists) {
        errorMessage = 'Wallet not found';
        loading = false;
        debugPrint('Wallet not found: $walletIdToJoin');
        notifyListeners();
        return false;
      }

      final members = List<String>.from(walletDoc['members'] ?? []);
      if (!members.contains(userId)) {
        members.add(userId);
        await walletRef.update({'members': members});
      }
    _updatePartnerName();  // ← and also here

      walletId = walletIdToJoin;
      await Provider.of<AuthProvider>(context, listen: false).updateWalletId(walletId);
      await fetchWallet(userId);
      errorMessage = null;
      loading = false;
      debugPrint('Joined wallet with ID: $walletId');
      notifyListeners();
      return true;
    } catch (e) {
      errorMessage = 'Error joining wallet';
      loading = false;
      debugPrint('Join wallet error: $e');
      
      notifyListeners();
      return false;
      
    }
  }

  Future<bool> addUserByEmail(String email, String walletId, String currentUserId) async {
    try {
      loading = true;
      notifyListeners();
      final walletRef = _firestore.collection('wallets').doc(walletId);
      final walletDoc = await walletRef.get();
      if (!walletDoc.exists) {
        errorMessage = 'Wallet not found';
        loading = false;
        debugPrint('Wallet not found: $walletId');
        notifyListeners();
        return false;
      }
      if (walletDoc['ownerUid'] != currentUserId) {
        errorMessage = 'Only the wallet owner can add members';
        loading = false;
        debugPrint('Permission denied: Not wallet owner');
        notifyListeners();
        return false;
      }

      final userQuery = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) {
        errorMessage = 'No user found with that email';
        loading = false;
        debugPrint('No user found for email: $email');
        notifyListeners();
        return false;
      }

      final uid = userQuery.docs.first['uid'];
      await walletRef.update({
        'members': FieldValue.arrayUnion([uid]),
      });

      await fetchWallet(currentUserId);
      errorMessage = null;
      loading = false;
      debugPrint('User added to wallet: $uid');
      notifyListeners();
      return true;
    } catch (e) {
      errorMessage = 'Failed to add user';
      loading = false;
      debugPrint('Add user error: $e');
      notifyListeners();
      return false;
    }
  }

  Future<bool> removeUserByUid(String uidToRemove, String walletId, String currentUserId) async {
    if (uidToRemove == currentUserId) {
      errorMessage = "You can't remove yourself";
      loading = false;
      debugPrint('Cannot remove self: $uidToRemove');
      notifyListeners();
      return false;
    }

    try {
      loading = true;
      notifyListeners();
      final walletRef = _firestore.collection('wallets').doc(walletId);
      await walletRef.update({
        'members': FieldValue.arrayRemove([uidToRemove]),
      });

      await fetchWallet(currentUserId);
      errorMessage = null;
      loading = false;
      debugPrint('User removed: $uidToRemove');
      notifyListeners();
      return true;
    } catch (e) {
      errorMessage = 'Failed to remove user';
      loading = false;
      debugPrint('Remove user error: $e');
      notifyListeners();
      return false;
    }
  }

  Future<bool> leaveWallet(String userId, BuildContext context) async {
    try {
      loading = true;
      notifyListeners();
      final walletRef = _firestore.collection('wallets').doc(walletId);
      final walletDoc = await walletRef.get();
      if (!walletDoc.exists) {
        errorMessage = 'Wallet not found';
        loading = false;
        debugPrint('Wallet not found: $walletId');
        notifyListeners();
        return false;
      }

      if (walletDoc['ownerUid'] == userId && List<String>.from(walletDoc['members'] ?? []).length > 1) {
        errorMessage = 'Owner cannot leave unless they are the last member';
        loading = false;
        debugPrint('Owner cannot leave: $userId');
        notifyListeners();
        return false;
      }

      await walletRef.update({
        'members': FieldValue.arrayRemove([userId]),
      });

      final updatedDoc = await walletRef.get();
      if (updatedDoc.exists && List<String>.from(updatedDoc['members'] ?? []).isEmpty) {
        final transactions = await _firestore.collection('transactions').where('walletId', isEqualTo: walletId).get();
        if (transactions.docs.isEmpty) {
          await walletRef.delete();
          debugPrint('Wallet deleted: $walletId');
        }
      }

      wallet = null;
      walletId = null;
      memberData.clear();
      await Provider.of<AuthProvider>(context, listen: false).updateWalletId(null);
      errorMessage = null;
      loading = false;
      debugPrint('User left wallet: $userId');
      notifyListeners();
      return true;
    } catch (e) {
      errorMessage = 'Failed to leave wallet';
      loading = false;
      debugPrint('Leave wallet error: $e');
      notifyListeners();
      return false;
    }
  }

  Future<void> fetchWallet(String userId) async {
    try {
      loading = true;
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 50)); // Prevent main thread blocking
      final query = await _firestore
          .collection('wallets')
          .where('members', arrayContains: userId)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        wallet = query.docs.first;
        walletId = wallet!.id;
        await fetchMemberEmails(wallet!['members']);
   _updatePartnerName();                   // ← now that memberData is ready
       debugPrint('Wallet fetched with ID: $walletId (partner: $_partnerName)');
      } else {
        wallet = null;
        walletId = null;
        memberData.clear();
        _partnerName = '';                      // ← no partner when no wallet

        debugPrint('No wallet found for user: $userId');
      }
      errorMessage = null;
      loading = false;
      notifyListeners();
    } catch (e) {
      errorMessage = 'Failed to load wallet';
      loading = false;
      debugPrint('Fetch wallet error: $e');
      notifyListeners();
    }
  }

     Future<void> fetchMemberEmails(List<dynamic> memberUids) async {
     memberData.clear();
     const batchSize = 10;
     for (var i = 0; i < memberUids.length; i += batchSize) {
       final batchUids = memberUids.sublist(
         i,
         i + batchSize > memberUids.length
             ? memberUids.length
             : i + batchSize,
       );
       try {
         await Future.delayed(const Duration(milliseconds: 50));
         final query = await _firestore
             .collection('users')
             .where(FieldPath.documentId, whereIn: batchUids)
             .get();

         for (var doc in query.docs) {

          final data = doc.data() as Map<String, dynamic>;
          final email = (data['email'] as String?) ?? 'unknown@…';
          // if you store full name under "name", fall back to the part before the @
          final name =
              (data['name'] as String?)?.split(' ').first.trim() ??
              email.split('@').first;
          memberData.add({
            'uid': doc.id,
            'email': email,
            'name': name[0].toUpperCase() + name.substring(1).toLowerCase(),
          });
        }
       debugPrint('Fetched member profiles for UIDs: $batchUids');
      } catch (e) {
        for (var uid in batchUids) {
          memberData.add({
            'uid': uid.toString(),
            'email': 'unknown@…',
            'name': 'Unknown',
          });
         }
         debugPrint('Fetch member emails error: $e');
       }
     }
     notifyListeners();
   }
    void _updatePartnerName() {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final other = memberData.firstWhere(
      (m) => m['uid'] != currentUid,
      orElse: () => {'name': 'Partner'},
    );
    _partnerName = other['name']!;
    notifyListeners();
  }

}  
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class WalletProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? walletId;
  String? errorMessage;
  DocumentSnapshot? wallet;
  List<Map<String, String>> memberData = [];
  bool loading = false;

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
      notifyListeners();
      return true;
    } catch (e) {
      errorMessage = 'Failed to create wallet: $e';
      loading = false;
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
        notifyListeners();
        return false;
      }

      final members = List<String>.from(walletDoc['members'] ?? []);
      if (!members.contains(userId)) {
        members.add(userId);
        await walletRef.update({'members': members});
      }

      walletId = walletIdToJoin;
      await Provider.of<AuthProvider>(context, listen: false).updateWalletId(walletId);
      await fetchWallet(userId);
      errorMessage = null;
      loading = false;
      notifyListeners();
      return true;
    } catch (e) {
      errorMessage = 'Error joining wallet: $e';
      loading = false;
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
      if (!walletDoc.exists || walletDoc['ownerUid'] != currentUserId) {
        errorMessage = 'Only the wallet owner can add members';
        loading = false;
        notifyListeners();
        return false;
      }

      final userQuery = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) {
        errorMessage = 'No user found with email: $email';
        loading = false;
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
      notifyListeners();
      return true;
    } catch (e) {
      errorMessage = 'Failed to add user: $e';
      loading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> removeUserByUid(String uidToRemove, String walletId, String currentUserId) async {
    if (uidToRemove == currentUserId) {
      errorMessage = "You can't remove yourself";
      loading = false;
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
      notifyListeners();
      return true;
    } catch (e) {
      errorMessage = 'Failed to remove user: $e';
      loading = false;
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
        notifyListeners();
        return false;
      }

      if (walletDoc['ownerUid'] == userId && List<String>.from(walletDoc['members'] ?? []).length > 1) {
        errorMessage = 'Owner cannot leave unless they are the last member';
        loading = false;
        notifyListeners();
        return false;
      }

      await walletRef.update({
        'members': FieldValue.arrayRemove([userId]),
      });

      // Delete wallet if empty
      final updatedDoc = await walletRef.get();
      if (updatedDoc.exists && List<String>.from(updatedDoc['members'] ?? []).isEmpty) {
        await walletRef.delete();
      }

      wallet = null;
      walletId = null;
      memberData.clear();
      await Provider.of<AuthProvider>(context, listen: false).updateWalletId(null);
      errorMessage = null;
      loading = false;
      notifyListeners();
      return true;
    } catch (e) {
      errorMessage = 'Failed to leave wallet: $e';
      loading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> fetchWallet(String userId) async {
    try {
      loading = true;
      notifyListeners();
      final query = await _firestore
          .collection('wallets')
          .where('members', arrayContains: userId)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        wallet = query.docs.first;
        walletId = wallet!.id;
        await fetchMemberEmails(wallet!['members']);
      } else {
        wallet = null;
        walletId = null;
        memberData.clear();
      }
      errorMessage = null;
      loading = false;
      notifyListeners();
    } catch (e) {
      errorMessage = 'Failed to load wallet: $e';
      loading = false;
      notifyListeners();
    }
  }

  Future<void> fetchMemberEmails(List<dynamic> memberUids) async {
    memberData.clear();
    for (var uid in memberUids) {
      try {
        final doc = await _firestore.collection('users').doc(uid).get();
        if (doc.exists) {
          final String email = (doc.data() as Map<String, dynamic>?)?['email']?.toString() ?? 'Unknown User';
          memberData.add({'uid': uid.toString(), 'email': email});
        } else {
          memberData.add({'uid': uid.toString(), 'email': 'Unknown User'});
        }
      } catch (e) {
        memberData.add({'uid': uid.toString(), 'email': 'Unknown User'});
      }
    }
    notifyListeners();
  }
}
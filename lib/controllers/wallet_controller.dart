// lib/controllers/wallet_controller.dart
import 'dart:async';
import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:async/async.dart';

class WalletMember {
  final String uid;
  final String email;
  final String name;
  WalletMember({required this.uid, required this.email, required this.name});

  @override
  String toString() => 'WalletMember($uid, $email, $name)';
}

class WalletInvite {
  final String id;
  final String walletId;
  final String fromUid;
  final String toUid;
  final String toEmail;
  final String status; // pending | accepted | rejected | cancelled
  final Timestamp createdAt;

  WalletInvite({
    required this.id,
    required this.walletId,
    required this.fromUid,
    required this.toUid,
    required this.toEmail,
    required this.status,
    required this.createdAt,
  });
}

class WalletController extends GetxController {
  final _db = FirebaseFirestore.instance;

  // Reactive state
  final RxnString walletId = RxnString();
  final Rxn<DocumentSnapshot<Map<String, dynamic>>> walletDoc = Rxn(null);
  final RxList<WalletMember> members = <WalletMember>[].obs;
  final RxString errorMessage = ''.obs;
  final RxBool loading = false.obs;
  final RxBool joining = false.obs;
  final RxString partnerName = ''.obs;
  final RxBool isMember = false.obs;

  // Invites
  final RxList<WalletInvite> incomingInvites = <WalletInvite>[].obs;
  final RxList<WalletInvite> outgoingInvites = <WalletInvite>[].obs;

  StreamSubscription? _walletSub;
  StreamSubscription? _incomingInvSub;
  StreamSubscription? _outgoingInvSub;

  Future<void>? _bootFuture;

  @override
  void onInit() {
    super.onInit();
    log('🔧 WalletController onInit');

    FirebaseAuth.instance.idTokenChanges().listen((user) async {
      log('🔧 Auth state changed: ${user?.uid}');
      _cancelStreams();
      _clearAll();

      if (user != null) {
        await Future.delayed(const Duration(milliseconds: 500));
        await fetchOrCreateWalletForUser(user.uid);
        _listenInvites(user.uid);
      }
    });
  }

  @override
  void onClose() {
    _cancelStreams();
    super.onClose();
  }

  void _cancelStreams() {
    _walletSub?.cancel();
    _incomingInvSub?.cancel();
    _outgoingInvSub?.cancel();
    _walletSub = null;
    _incomingInvSub = null;
    _outgoingInvSub = null;
  }

  void _clearAll() {
    walletId.value = null;
    walletDoc.value = null;
    members.clear();
    partnerName.value = '';
    isMember.value = false;
    incomingInvites.clear();
    outgoingInvites.clear();
    errorMessage.value = '';
    loading.value = false;
    joining.value = false;
  }

  Future<void> fetchOrCreateWalletForUser(String uid) async {
    if (_bootFuture != null) return _bootFuture!;
    final completer = Completer<void>();
    _bootFuture = completer.future;

    try {
      loading.value = true;
      await FirebaseAuth.instance.currentUser?.getIdToken(true);

      final userRef = _db.collection('users').doc(uid);

      // Step 1: pointer (permission-safe)
      final userSnap = await userRef.get();
      final String? pointer = userSnap.data()?['primaryWalletId'] as String?;

      if (pointer != null && pointer.isNotEmpty) {
        try {
          final walletSnap = await _db.collection('wallets').doc(pointer).get();
          if (walletSnap.exists) {
            final m = List<String>.from(walletSnap.data()?['members'] ?? []);
            if (m.contains(uid)) {
              _bindWalletDoc(pointer);
              return;
            } else {
              await userRef.update({'primaryWalletId': FieldValue.delete()});
            }
          } else {
            await userRef.update({'primaryWalletId': FieldValue.delete()});
          }
        } on FirebaseException catch (e) {
          if (e.code == 'permission-denied') {
            await userRef.update({'primaryWalletId': FieldValue.delete()});
          } else {
            rethrow;
          }
        }
      }

      // Step 2: discovery
      try {
        final query = await _db
            .collection('wallets')
            .where('members', arrayContains: uid)
            .limit(1)
            .get();

        if (query.docs.isNotEmpty) {
          final foundWalletId = query.docs.first.id;
          await userRef.set({'primaryWalletId': foundWalletId}, SetOptions(merge: true));
          _bindWalletDoc(foundWalletId);
          return;
        }
      } catch (_) {}

      // Step 3: create personal wallet
final user = FirebaseAuth.instance.currentUser;
final displayName = user?.displayName ?? user?.email?.split('@').first ?? 'User';
final walletRef = _db.collection('wallets').doc();

await walletRef.set({
  'name': "$displayName's Wallet",
  'members': [uid],
  'memberDetails': {
    uid: {
      'name': displayName,
      'email': user?.email ?? '',
      'joinedAt': FieldValue.serverTimestamp(),
    }
  },
  'createdAt': FieldValue.serverTimestamp(),
  'updatedAt': FieldValue.serverTimestamp(),
});

await userRef.set({'primaryWalletId': walletRef.id}, SetOptions(merge: true));
_bindWalletDoc(walletRef.id);
log('🔧 Created wallet: ${walletRef.id}');
    } catch (e) {
      errorMessage.value = 'Failed to initialize wallet: $e';
      log('🔧 fetchOrCreateWalletForUser error: $e');
    } finally {
      loading.value = false;
      completer.complete();
      _bootFuture = null;
    }
  }

  void _bindWalletDoc(String id) {
    log('🔧 Binding to wallet: $id');
    walletId.value = id;

    _walletSub?.cancel();
    _walletSub = _db.collection('wallets').doc(id).snapshots().listen(
      (doc) async {
        if (FirebaseAuth.instance.currentUser == null) return;

        if (!doc.exists) {
          final me = FirebaseAuth.instance.currentUser?.uid;
          if (me != null) {
            await _db.collection('users').doc(me).update({'primaryWalletId': FieldValue.delete()});
            await fetchOrCreateWalletForUser(me);
          }
          return;
        }

        walletDoc.value = doc;
        _updateIsMember();
              await _migrateWalletMemberDetails();

        await _refreshMembers();
        _updatePartnerName();
      },
      onError: (e) {
        if (FirebaseAuth.instance.currentUser != null) {
          errorMessage.value = 'Wallet sync error: $e';
        }
      },
    );
  }
/// Migrate existing wallet to include memberDetails (call this once after updating)
Future<void> _migrateWalletMemberDetails() async {
  final wId = walletId.value;
  if (wId == null) return;

  try {
    final walletRef = _db.collection('wallets').doc(wId);
    final doc = await walletRef.get();
    if (!doc.exists) return;

    final data = doc.data()!;
    final members = List<String>.from(data['members'] ?? []);
    final existingDetails = data['memberDetails'] as Map<String, dynamic>?;

    // If memberDetails already exists, don't migrate
    if (existingDetails != null && existingDetails.isNotEmpty) return;

    log('🔧 Migrating wallet memberDetails for ${members.length} members');

    final Map<String, Map<String, dynamic>> newMemberDetails = {};
    
    for (final memberUid in members) {
      if (memberUid == FirebaseAuth.instance.currentUser?.uid) {
        // Current user
        final me = FirebaseAuth.instance.currentUser!;
        newMemberDetails[memberUid] = {
          'name': me.displayName ?? me.email?.split('@').first ?? 'User',
          'email': me.email ?? '',
          'joinedAt': FieldValue.serverTimestamp(),
        };
      } else {
        // Other users - use fallback
        newMemberDetails[memberUid] = {
          'name': 'Member',
          'email': '',
          'joinedAt': FieldValue.serverTimestamp(),
        };
      }
    }

    await walletRef.update({
      'memberDetails': newMemberDetails,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    log('🔧 Wallet migration complete');
  } catch (e) {
    log('🔧 Wallet migration error: $e');
  }
}
  void _updateIsMember() {
    final me = FirebaseAuth.instance.currentUser?.uid;
    final m = List<String>.from(walletDoc.value?.data()?['members'] ?? []);
    isMember.value = (me != null && m.contains(me));
  }

Future<void> _refreshMembers() async {
  members.clear();
  final data = walletDoc.value?.data();
  if (data == null) return;

  final List<dynamic> uids = (data['members'] ?? []) as List<dynamic>;
  final Map<String, dynamic> memberDetails = (data['memberDetails'] ?? {}) as Map<String, dynamic>;
  final me = FirebaseAuth.instance.currentUser;
  final myUid = me?.uid;

  log('🔧 _refreshMembers: Found ${uids.length} members with details: $memberDetails');

  for (final uid in uids) {
    final uidStr = uid.toString();
    
    if (uidStr == myUid) {
      // Current user - use Firebase Auth data as primary source
      final email = me?.email ?? '';
      final name = (me?.displayName?.trim().isNotEmpty == true)
          ? me!.displayName!
          : (email.isNotEmpty ? StringCaps (email.split('@').first).capFirst : 'Me');
      members.add(WalletMember(uid: uidStr, email: email, name: name));
    } else {
      // Other users - read from wallet's memberDetails
      final memberInfo = memberDetails[uidStr] as Map<String, dynamic>?;
      if (memberInfo != null) {
        final name = memberInfo['name'] as String? ?? '';
        final email = memberInfo['email'] as String? ?? '';
        final displayName = name.isNotEmpty 
            ? name 
            : (email.isNotEmpty 
                ? StringCaps (email.split('@').first).capFirst 
                : 'Member');
        members.add(WalletMember(uid: uidStr, email: email, name: displayName));
      } else {
        // Fallback for old wallets without memberDetails
        members.add(WalletMember(uid: uidStr, email: '', name: 'Member'));
      }
    }
  }
  
  log('🔧 Final members list: ${members.map((m) => '${m.name} (${m.uid})').toList()}');
}


Future<void> _addMemberDetailsToWallet(String walletId, String memberUid) async {
  try {
    // Get member's info from Firebase Auth or user collection
    final memberUser = FirebaseAuth.instance.currentUser;
    String memberName = 'Member';
    String memberEmail = '';
    
    if (memberUser != null && memberUser.uid == memberUid) {
      // If it's the current user, get from Firebase Auth
      memberName = memberUser.displayName ?? memberUser.email?.split('@').first ?? 'Member';
      memberEmail = memberUser.email ?? '';
    } else {
      // For other users, try to get from user document (if accessible)
      try {
        final userDoc = await _db.collection('users').doc(memberUid).get();
        if (userDoc.exists) {
          final userData = userDoc.data()!;
          memberName = userData['name'] as String? ?? userData['displayName'] as String? ?? 'Member';
          memberEmail = userData['email'] as String? ?? '';
        }
      } catch (e) {
        log('🔧 Could not fetch user details for $memberUid, using defaults: $e');
        // Use defaults set above
      }
    }
    
    // Update wallet with member details
    await _db.collection('wallets').doc(walletId).update({
      'memberDetails.$memberUid': {
        'name': memberName,
        'email': memberEmail,
        'joinedAt': FieldValue.serverTimestamp(),
      },
      'updatedAt': FieldValue.serverTimestamp(),
    });
    
    log('🔧 Added member details to wallet: $memberUid -> $memberName ($memberEmail)');
  } catch (e) {
    log('🔧 Error adding member details: $e');
  }
}

  void _updatePartnerName() {
    final me = FirebaseAuth.instance.currentUser?.uid;
    WalletMember? partner;
    for (final member in members) {
      if (member.uid != me) {
        partner = member;
        break;
      }
    }
    partnerName.value = partner?.name ?? '';
  }

  // ===== Invites =====
void _listenInvites(String myUid) {
  _incomingInvSub?.cancel();
  _outgoingInvSub?.cancel();

  final myEmailLower = FirebaseAuth.instance.currentUser?.email?.toLowerCase();

  final byUid = _db
      .collection('wallet_invites')
      .where('toUid', isEqualTo: myUid)
      .where('status', isEqualTo: 'pending') // Only pending invites
      .orderBy('createdAt', descending: true);

  final streams = <Stream<QuerySnapshot<Map<String, dynamic>>>>[
    byUid.snapshots(),
    if (myEmailLower != null)
      _db
          .collection('wallet_invites')
          .where('toEmailLower', isEqualTo: myEmailLower)
          .where('status', isEqualTo: 'pending') // Only pending invites
          .orderBy('createdAt', descending: true)
          .snapshots(),
  ];

  _incomingInvSub = StreamGroup.merge(streams).listen((snap) {
    if (FirebaseAuth.instance.currentUser == null) return;

    final map = {for (final d in snap.docs) d.id: d};
    final invites = map.values
        .map((d) {
          final data = d.data();
          return WalletInvite(
            id: d.id,
            walletId: data['walletId'] as String,
            fromUid: data['fromUid'] as String,
            toUid: (data['toUid'] ?? '') as String,
            toEmail: (data['toEmail'] ?? '') as String,
            status: (data['status'] ?? 'pending') as String,
            createdAt: (data['createdAt'] ?? Timestamp.now()) as Timestamp,
          );
        })
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    incomingInvites.assignAll(invites);
  }, onError: (e) {
    if (FirebaseAuth.instance.currentUser != null) {
      if (e is FirebaseException && e.code == 'permission-denied') return;
      errorMessage.value = 'Failed to load invites: $e';
    }
  });

  _outgoingInvSub = _db
      .collection('wallet_invites')
      .where('fromUid', isEqualTo: myUid)
      .where('status', isEqualTo: 'pending') // Only pending invites
      .orderBy('createdAt', descending: true)
      .snapshots()
      .listen((snap) {
    if (FirebaseAuth.instance.currentUser == null) return;

    final invites = snap.docs.map((d) {
      final data = d.data();
      return WalletInvite(
        id: d.id,
        walletId: data['walletId'] as String,
        fromUid: data['fromUid'] as String,
        toUid: (data['toUid'] ?? '') as String,
        toEmail: (data['toEmail'] ?? '') as String,
        status: (data['status'] ?? 'pending') as String,
        createdAt: (data['createdAt'] ?? Timestamp.now()) as Timestamp,
      );
    }).toList();

    outgoingInvites.assignAll(invites);
  }, onError: (e) {
    if (FirebaseAuth.instance.currentUser != null) {
      if (e is FirebaseException && e.code == 'permission-denied') return;
      errorMessage.value = 'Failed to load sent invites: $e';
    }
  });
}
  /// Send invite by email (ownerless; any member can invite)
  Future<void> sendInviteByEmail(String email) async {
    final me = FirebaseAuth.instance.currentUser;
    final wId = walletId.value;

    if (me == null || wId == null) {
      errorMessage.value = 'Not ready to send invite';
      return;
    }

    try {
      loading.value = true;
      final emailLower = email.trim().toLowerCase();

      final dup = await _db
          .collection('wallet_invites')
          .where('walletId', isEqualTo: wId)
          .where('fromUid', isEqualTo: me.uid)
          .where('toEmailLower', isEqualTo: emailLower)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();
      if (dup.docs.isNotEmpty) {
        errorMessage.value = 'Invite already pending for this email';
        return;
      }

      await _db.collection('wallet_invites').add({
        'walletId': wId,
        'fromUid': me.uid,
        'fromEmail': me.email ?? '',
        'toUid': null,
        'toEmail': emailLower,
        'toEmailLower': emailLower,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      errorMessage.value = '';
      log('🔧 Invite created');
    } catch (e) {
      errorMessage.value = e.toString();
      log('🔧 Send invite error: $e');
    } finally {
      loading.value = false;
    }
  }

  /// Accept invite and (optionally) move my previous receipts into the shared wallet.
  /// If [moveMyOldToShared] is true (default), any receipts authored by me in my previous wallet
  /// are migrated into the target (shared) wallet. Then I'm removed from the previous wallet
  /// (and it may be deleted if empty).
  Future<void> acceptInvite(
  WalletInvite invite, {
  bool moveMyOldToShared = true,
}) async {
  final me = FirebaseAuth.instance.currentUser?.uid;
  if (me == null) return;

  try {
    loading.value = true;
    joining.value = true;

    // Capture the previous wallet before switching
    final prevId = walletId.value;

    // Join target first; do NOT migrate-to-personal here
    await joinWalletAndCleanup(
      invite.walletId,
      migrateMineToPersonalOnLeave: false,
    );

    // If requested, migrate my receipts from previous -> shared
    if (moveMyOldToShared && prevId != null && prevId != invite.walletId) {
      await _migrateMyReceipts(
        fromWalletId: prevId,
        toWalletId: invite.walletId,
        myUid: me,
      );

      // After migration, remove me from previous wallet (unless it was a single-member personal)
      await _removeMeFromWalletIfNotSinglePersonal(prevId, me);
    }

    // Mark invite as accepted
    await _db.collection('wallet_invites').doc(invite.id).update({
      'status': 'accepted',
      'toUid': me,
      'respondedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // IMPORTANT: Update my member details in the wallet after joining
    await _updateMyMemberDetails(invite.walletId);

    // Optimistic local update so UI changes immediately
    final i = incomingInvites.indexWhere((x) => x.id == invite.id);
    if (i != -1) {
      incomingInvites[i] = WalletInvite(
        id: invite.id,
        walletId: invite.walletId,
        fromUid: invite.fromUid,
        toUid: me,
        toEmail: invite.toEmail,
        status: 'accepted',
        createdAt: invite.createdAt,
      );
    }

    // Reattach invite streams (join canceled them)
    _listenInvites(me);

    errorMessage.value = '';
    log('🔧 Invite accepted successfully (moveMyOldToShared=$moveMyOldToShared)');
  } catch (e) {
    errorMessage.value = 'Failed to accept invite: $e';
    log('🔧 Accept invite error: $e');
  } finally {
    loading.value = false;
    joining.value = false;
  }
}

/// Update my member details in the wallet with current user info
Future<void> _updateMyMemberDetails(String walletId) async {
  final me = FirebaseAuth.instance.currentUser;
  if (me == null) return;

  try {
    final myName = me.displayName ?? me.email?.split('@').first ?? 'User';
    
    await _db.collection('wallets').doc(walletId).update({
      'memberDetails.${me.uid}': {
        'name': myName,
        'email': me.email ?? '',
        'joinedAt': FieldValue.serverTimestamp(),
      },
      'updatedAt': FieldValue.serverTimestamp(),
    });
    
    log('🔧 Updated my member details: $myName (${me.email})');
  } catch (e) {
    log('🔧 Error updating my member details: $e');
  }
}

  Future<void> rejectInvite(WalletInvite invite) async {
    try {
      await _db.collection('wallet_invites').doc(invite.id).update({
        'status': 'rejected',
        'respondedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      errorMessage.value = 'Failed to reject invite: $e';
    }
  }

  /// Self-leave the current wallet, optionally migrating *my* receipts to a personal wallet.
  Future<void> leaveCurrentWallet({bool migrateReceipts = true}) async {
    final me = FirebaseAuth.instance.currentUser?.uid;
    final oldWalletId = walletId.value;
    if (me == null || oldWalletId == null) return;

    try {
      loading.value = true;
      joining.value = true;

      final personalId = await _ensurePersonalWalletFor(me);

      if (migrateReceipts && personalId != oldWalletId) {
        await _migrateMyReceipts(fromWalletId: oldWalletId, toWalletId: personalId, myUid: me);
      }

      // Remove from old wallet only if it's not a single-member personal wallet
      await _removeMeFromWalletIfNotSinglePersonal(oldWalletId, me);

      await _setPrimaryAndBind(me, personalId);
    } catch (e) {
      errorMessage.value = 'Failed to leave wallet: $e';
      log('🔧 leaveCurrentWallet error: $e');
    } finally {
      loading.value = false;
      joining.value = false;
    }
  }

  /// Remove a member (no migration here).
  Future<void> removeMember(String memberUid) async {
  final me = FirebaseAuth.instance.currentUser?.uid;
  final wId = walletId.value;
  if (me == null || wId == null) return;

  try {
    loading.value = true;

    final walletRef = _db.collection('wallets').doc(wId);
    final doc = await walletRef.get();
    if (!doc.exists) throw Exception('Wallet not found');

    final currentMembers = List<String>.from(doc.data()?['members'] ?? []);
    if (!currentMembers.contains(memberUid)) {
      errorMessage.value = 'User is not a member';
      return;
    }

    currentMembers.remove(memberUid);

    await walletRef.update({
      'members': currentMembers,
      'memberDetails.$memberUid': FieldValue.delete(), // Remove member details
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Clear their primary pointer
    await _db.collection('users').doc(memberUid).set(
      {'primaryWalletId': FieldValue.delete()},
      SetOptions(merge: true),
    );

    errorMessage.value = '';
  } on FirebaseException catch (e) {
    if (e.code != 'permission-denied') {
      errorMessage.value = e.message ?? e.toString();
    }
    log('🔧 removeMember FirebaseException: ${e.code} ${e.message}');
  } catch (e) {
    errorMessage.value = e.toString();
    log('🔧 removeMember error: $e');
  } finally {
    loading.value = false;
  }
}

  /// Join a wallet and (optionally) migrate my receipts out of the previous wallet to my personal wallet first.
  Future<void> joinWalletAndCleanup(
    String targetWalletId, {
    bool migrateMineToPersonalOnLeave = true,
  }) async {
    final mes = FirebaseAuth.instance.currentUser?.uid;
    if (mes == null) throw Exception('Not signed in');

    final previousWalletId = walletId.value;

    try {
      joining.value = true;
      // stop reads during transition
      _cancelStreams();

      if (previousWalletId != null && previousWalletId != targetWalletId && migrateMineToPersonalOnLeave) {
        final personalId = await _ensurePersonalWalletFor(mes);

        if (personalId != previousWalletId) {
          await _migrateMyReceipts(fromWalletId: previousWalletId, toWalletId: personalId, myUid: mes);
        }

        await _removeMeFromWalletIfNotSinglePersonal(previousWalletId, mes);
      }

      // Add me to target & make it primary
      final batch = _db.batch();
final targetRef = _db.collection('wallets').doc(targetWalletId);

final me = FirebaseAuth.instance.currentUser!;
final myName = me.displayName ?? me.email?.split('@').first ?? 'User';

batch.update(targetRef, {
  'members': FieldValue.arrayUnion([me.uid]),
  'memberDetails.${me.uid}': {
    'name': myName,
    'email': me.email ?? '',
    'joinedAt': FieldValue.serverTimestamp(),
  },
  'updatedAt': FieldValue.serverTimestamp(),
});

batch.set(
  _db.collection('users').doc(me.uid), 
  {'primaryWalletId': targetWalletId}, 
  SetOptions(merge: true)
);

await batch.commit();

      _bindWalletDoc(targetWalletId);
      log('🔧 Successfully joined wallet');
    } catch (e) {
      errorMessage.value = 'Failed to join wallet: $e';
      log('🔧 joinWalletAndCleanup error: $e');
    } finally {
      joining.value = false;
    }
  }

  Future<void> joinWalletById(String targetWalletId) =>
      joinWalletAndCleanup(targetWalletId, migrateMineToPersonalOnLeave: true);

  // ===== helpers =====

  Future<String> _ensurePersonalWalletFor(String uid) async {
    try {
      final q = await _db
          .collection('wallets')
          .where('members', arrayContains: uid)
          .limit(10)
          .get();

      for (final d in q.docs) {
        final members = List<String>.from(d.data()['members'] ?? []);
        if (members.length == 1 && members.first == uid) {
          return d.id; // found existing personal wallet
        }
      }
    } catch (_) {}

    final me = FirebaseAuth.instance.currentUser;
    final displayName = me?.displayName ?? me?.email?.split('@').first ?? 'User';
    final newRef = _db.collection('wallets').doc();
    await newRef.set({
      'name': "$displayName's Wallet",
      'members': [uid],
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return newRef.id;
  }

  Future<void> _migrateMyReceipts({
    required String fromWalletId,
    required String toWalletId,
    required String myUid,
  }) async {
    if (fromWalletId == toWalletId) {
      log('🔧 Skip migration: from == to ($fromWalletId)');
      return;
    }

    log('🔧 Migrating receipts for $myUid from $fromWalletId → $toWalletId');

    const int chunkSize = 200;
    DocumentSnapshot? last;
    while (true) {
      Query query = _db
          .collection('wallets')
          .doc(fromWalletId)
          .collection('receipts')
          .where('userId', isEqualTo: myUid)
          .orderBy(FieldPath.documentId)
          .limit(chunkSize);

      if (last != null) query = query.startAfterDocument(last);

      final snap = await query.get();
      if (snap.docs.isEmpty) break;

      final batch = _db.batch();
      for (final d in snap.docs) {
        final data = d.data();

        final newDoc = _db.collection('wallets').doc(toWalletId).collection('receipts').doc();
        batch.set(newDoc, data);
        batch.delete(d.reference);
      }
      await batch.commit();
      last = snap.docs.last;
    }

    log('🔧 Migration complete.');
  }

  Future<void> _removeMeFromWalletIfNotSinglePersonal(String walletId, String me) async {
    final ref = _db.collection('wallets').doc(walletId);
    final snap = await ref.get();
    if (!snap.exists) return;

    final m = List<String>.from(snap.data()?['members'] ?? []);
    final wasSingleMember = (m.length == 1 && m.first == me);

    if (!wasSingleMember) {
      m.remove(me);
      if (m.isEmpty) {
        await ref.delete();
      } else {
        await ref.update({'members': m, 'updatedAt': FieldValue.serverTimestamp()});
      }
    }
  }

  Future<void> _setPrimaryAndBind(String uid, String wid) async {
    await _db.collection('users').doc(uid).set({'primaryWalletId': wid}, SetOptions(merge: true));
    _bindWalletDoc(wid);
  }
}

// Extension for string capitalization
extension StringCaps on String {
  String get capFirst {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1).toLowerCase()}';
  }
}

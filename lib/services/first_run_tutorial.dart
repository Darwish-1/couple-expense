import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FirstRunTutorial {
  static Future<bool> shouldShow() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;

    // local fallback (works offline)
    final prefs = await SharedPreferences.getInstance();
    final localSeen = prefs.getBool('tutorial_seen_$uid') ?? false;

    // remote (cross-device)
    bool remoteSeen = false;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      remoteSeen = (doc.data()?['has_seen_tutorial'] == true);
    } catch (_) {}

    return !(localSeen || remoteSeen);
  }

  static Future<void> markSeen() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('tutorial_seen_$uid', true);
    await FirebaseFirestore.instance
        .collection('users').doc(uid)
        .set({'has_seen_tutorial': true}, SetOptions(merge: true));
  }
}

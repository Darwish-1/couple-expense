// lib/services/first_run_tutorial.dart
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

class FirstRunTutorial {
  static String? _uid;
  static void configure(String uid) => _uid = uid;

  static String _keyFirstRun() => 'tutorial_first_run_seen_${_uid ?? "anon"}';
  static String _keyMy()       => 'tutorial_my_expenses_seen_${_uid ?? "anon"}';
  static String _keyWallet()   => 'tutorial_wallet_seen_${_uid ?? "anon"}';
  static String _keyShared()   => 'tutorial_shared_expenses_seen_${_uid ?? "anon"}';

  // sequence guard (overall)
  static Future<bool> shouldShow() async {
    final p = await SharedPreferences.getInstance();
    final hasSeen = p.getBool(_keyFirstRun()) ?? false;
    debugPrint('FirstRunTutorial.shouldShow(): hasSeen = $hasSeen (uid=$_uid)');
    return !hasSeen;
  }

  static Future<bool> shouldShowMyExpenses() async {
    final p = await SharedPreferences.getInstance();
    final seen = p.getBool(_keyMy()) ?? false;
    debugPrint('FirstRunTutorial.shouldShowMyExpenses(): hasSeenMy = $seen');
    return !seen;
  }

  static Future<bool> shouldShowWallet() async {
    final p = await SharedPreferences.getInstance();
    final seen = p.getBool(_keyWallet()) ?? false;
    debugPrint('FirstRunTutorial.shouldShowWallet(): hasSeenWallet = $seen');
    return !seen;
  }

  static Future<bool> shouldShowSharedExpenses() async {
    final p = await SharedPreferences.getInstance();
    final seen = p.getBool(_keyShared()) ?? false;
    debugPrint('FirstRunTutorial.shouldShowSharedExpenses(): hasSeenShared = $seen');
    return !seen;
  }

  static Future<void> markMyExpensesSeen() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_keyMy(), true);
    debugPrint('FirstRunTutorial.markMyExpensesSeen(): uid=$_uid');
  }

  static Future<void> markWalletSeen() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_keyWallet(), true);
    debugPrint('FirstRunTutorial.markWalletSeen(): uid=$_uid');
  }

  static Future<void> markSharedExpensesSeen() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_keyShared(), true);
    debugPrint('FirstRunTutorial.markSharedExpensesSeen(): uid=$_uid');
  }

  // Mark the entire sequence as completed
  static Future<void> markSeen() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_keyFirstRun(), true);
    await p.setBool(_keyMy(), true);
    await p.setBool(_keyWallet(), true);
    await p.setBool(_keyShared(), true);
    debugPrint('FirstRunTutorial.markSeen(): All tutorials marked as seen (uid=$_uid)');
  }

  static Future<void> reset() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_keyFirstRun());
    await p.remove(_keyMy());
    await p.remove(_keyWallet());
    await p.remove(_keyShared());
    debugPrint('FirstRunTutorial.reset(): cleared for uid=$_uid');
  }

  static Future<Map<String, bool>> getDebugState() async {
    final p = await SharedPreferences.getInstance();
    return {
      'firstRunSeen': p.getBool(_keyFirstRun()) ?? false,
      'myExpensesSeen': p.getBool(_keyMy()) ?? false,
      'walletSeen': p.getBool(_keyWallet()) ?? false,
      'sharedExpensesSeen': p.getBool(_keyShared()) ?? false,
    };
  }
}

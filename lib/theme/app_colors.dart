import 'package:flutter/material.dart';

/// Single source of truth for your palette.
abstract class AppColors {
  // Brand / base
  static const background = Color.fromRGBO(250, 247, 240, 1); // your cream
  static const primary    = Color(0xFF1E88E5); // blue seed (tweak if you like)
  static const onPrimary  = Colors.white;

  // Text
  static const textPrimary   = Colors.black87;
  static const textSecondary = Colors.black54;

  // Surfaces
  static const surface      = Colors.white;   // cards, list items
  static const onSurface    = Colors.black87; // text on cards

  // States / feedback
  static const success = Color(0xFF2E7D32);
  static const warning = Color(0xFFF9A825);
  static const error   = Color(0xFFD32F2F);

  // Accents used in your UI bits
  static const chip      = Color(0xFFEDEDED);
  static const chipText  = Colors.black87;
  static const divider   = Color(0x1F000000); // 12% black
}

import 'package:flutter/material.dart';

/// Maps many possible labels/synonyms to a canonical key
String _normalize(String input) {
  final s = input.trim().toLowerCase();
  // quick synonyms
  if (['gas', 'petrol', 'fuel', 'diesel'].contains(s)) return 'fuel';
  if (['grocery', 'groceries', 'supermarket', 'market'].contains(s)) return 'grocery';
  if (['clothes', 'cloths', 'clothing', 'apparel', 'wardrobe'].contains(s)) return 'clothing';
  if (['food', 'restaurant', 'dining', 'eat out'].contains(s)) return 'food';
  if (['transport', 'transportation', 'uber', 'taxi', 'bus', 'metro'].contains(s)) return 'transportation';
  if (['health', 'medical', 'pharmacy', 'medicine'].contains(s)) return 'health';
  if (['shopping', 'retail', 'mall'].contains(s)) return 'shopping';
  if (['entertainment', 'movies', 'cinema', 'games', 'subscriptions'].contains(s)) return 'entertainment';
  return s.isEmpty ? 'general' : s;
}


/// Map synonyms -> canonical keys that match filenames
String _canonicalKey(String raw) {
  final s = _normalize(raw);
  if (['gas','petrol','fuel','diesel'].contains(s)) return 'fuel';
  if (['grocery','groceries','supermarket','market'].contains(s)) return 'grocery';
  if (['clothes','cloths','clothing','apparel','wardrobe'].contains(s)) return 'clothing';
  if (['food','restaurant','dining','eat out'].contains(s)) return 'food';
  if (['transport','transportation','uber','taxi','bus','metro'].contains(s)) return 'transportation';
  if (['health','medical','pharmacy','medicine'].contains(s)) return 'health';
  if (['shopping','retail','mall'].contains(s)) return 'shopping';
  if (['entertainment','movies','cinema','games','subscriptions'].contains(s)) return 'entertainment';
  return s.isEmpty ? 'general' : s;
}

String assetPathForCategory(String raw) {
  const base = 'assets/icons/categories/';
  const valid = {
    'fuel','grocery','clothing','food','transportation',
    'entertainment','health','shopping','general',
  };
  final key = _canonicalKey(raw);        // <- lowercase + synonyms
  final safe = valid.contains(key) ? key : 'general';
  return '$base$safe.png';               // filenames are lowercase
}
/// Resolves to an asset path (PNG/SVG). Falls back to general.
String _assetFor(String key) {
  const base = 'assets/icons/categories/';
  const validKeys = {
    'fuel',
    'grocery',
    'clothing',
    'food',
    'transportation',
    'entertainment',
    'health',
    'shopping',
    'general',
  };

  // If key is valid, return its asset path, else use general
  final safeKey = validKeys.contains(key) ? key : 'general';
  return '$base$safeKey.png';
}


/// A tiny widget that renders the matched category icon (SVG or PNG).
class CategoryIcon extends StatelessWidget {
  final String category;
  const CategoryIcon(this.category, {super.key});

  @override
  Widget build(BuildContext context) {
    final path = assetPathForCategory(category);
    return ClipOval(
      child: Image.asset(
        path,
        fit: BoxFit.cover, // fills the circle completely
        errorBuilder: (_, __, ___) => Image.asset(
          'assets/icons/categories/general.png',
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}


// // lib/services/gpt_parser.dart
// import 'dart:convert';
// import 'dart:io';

// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter/foundation.dart';
// import 'package:flutter_dotenv/flutter_dotenv.dart';
// import 'package:http/http.dart' as http;
// import 'package:http_parser/http_parser.dart';

// class GptParser {
//   static final String _apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';
//   static final http.Client _client = http.Client();

//   // ---- Models ----
//   static const String _asrPrimaryModel = 'gpt-4o-mini-transcribe';
//   static const String _asrFallbackModel = 'whisper-1';
//   static const String _parseModel      = 'gpt-4o-mini';

//   // ---- Parser system prompt (kept to your 7 categories) ----
//   static const String _parserSystem = r'''
// You extract expense entries from casual speech in Egyptian Arabic, Arabizi (Franco-Arabic), or English.
// Return a single JSON object ONLY, with this exact schema:

// {
//   "expenses": [
//     {
//       "item_name": "string",           // required, concise
//       "unit_price": 123.45,            // required, number only (no currency symbol)
//       "category": "Fuel|Food|Health|Beauty|Beverages|Clothing|General",
//       "date_of_purchase": "YYYY-MM-DD" // if missing, use today's date
//     }
//   ]
// }

// Mapping examples:
// - fuel, petrol, بنزين → Fuel
// - groceries, lunch, مطعم, akalt/aklt/أكلت/اكلت → Food
// - meds, vitamins, دواء → Health
// - makeup, مستحضرات → Beauty
// - drinks, coffee, قهوة → Beverages
// - clothes, تيشيرت, بنطلون → Clothing
// - transport words like مواصلات / mwaslat / mwasalat / mowasalat / rekebt/rakabt (rode transport) → General
// - generic going out words like kharagt/5aragt/خرجت (went out) → General
// - otherwise → General

// Rules:
// - If price is spoken with a currency (e.g. جنيه, EGP, $, ليرة), keep numbers only for unit_price.
// - If no date is given, set date_of_purchase to today's date in YYYY-MM-DD.
// - Output exactly one JSON object, no markdown, no commentary.
// ''';

//   // ───────────────────────────────────────────
//   // STEP 1: Audio → Text (fast + fallback)
//   // ───────────────────────────────────────────
//   static Future<String?> transcribeAudio(File audioFile) async {
//     if (_apiKey.isEmpty) {
//       debugPrint('OpenAI API key is missing');
//       return null;
//     }

//     Future<String?> _callTranscribe({
//       required String model,
//       required MediaType ct,
//     }) async {
//       final uri = Uri.parse('https://api.openai.com/v1/audio/transcriptions');
//       final req = http.MultipartRequest('POST', uri)
//         ..headers['Authorization'] = 'Bearer $_apiKey'
//         ..fields['model'] = model
//         ..fields['language'] = 'ar' // bias to AR; still handles EN
//         ..files.add(await http.MultipartFile.fromPath(
//           'file',
//           audioFile.path,
//           contentType: ct,
//         ));

//       final streamed = await req.send().timeout(const Duration(seconds: 30));
//       final resp = await http.Response.fromStream(streamed);

//       if (resp.statusCode == 200) {
//         final data = jsonDecode(resp.body);
//         return (data['text'] as String?)?.trim();
//       }

//       debugPrint('Transcription $model error ${resp.statusCode}: ${resp.body}');
//       return null;
//     }

//     final ct = _guessCt(audioFile.path);

//     // Try fast model
//     String? text = await _callTranscribe(model: _asrPrimaryModel, ct: ct);

//     // If it's an .m4a and failed, flip m4a<->mp4 once (some servers are picky)
//     if (text == null && audioFile.path.toLowerCase().endsWith('.m4a')) {
//       final flipped = (ct.subtype == 'm4a')
//           ? MediaType('audio', 'mp4')
//           : MediaType('audio', 'm4a');
//       text = await _callTranscribe(model: _asrPrimaryModel, ct: flipped);
//     }

//     // Fallback to Whisper
//     text ??= await _callTranscribe(model: _asrFallbackModel, ct: ct);

//     return (text != null && text.isNotEmpty) ? text : null;
//   }

//   static MediaType _guessCt(String path) {
//     final p = path.toLowerCase();
//     if (p.endsWith('.m4a')) return MediaType('audio', 'm4a');
//     if (p.endsWith('.mp3') || p.endsWith('.mpga') || p.endsWith('.mpeg')) {
//       return MediaType('audio', 'mpeg');
//     }
//     if (p.endsWith('.mp4')) return MediaType('audio', 'mp4');
//     if (p.endsWith('.wav')) return MediaType('audio', 'wav');
//     if (p.endsWith('.webm')) return MediaType('audio', 'webm');
//     return MediaType('application', 'octet-stream');
//   }

//   // ───────────────────────────────────────────
//   // FAST-LANE: local parser for simple utterances
//   //  - supports multiple items separated by , / و / and / & / +
//   //  - each chunk must contain exactly one price
//   //  - understands Arabizi: 5=kh, 7=h, etc.
//   //  - special words: rekebt/rakabt + mwaslat → General,
//   //                  akalt/aklt → Food,
//   //                  5aragt/kharagt → General
//   // ───────────────────────────────────────────
//   static List<Map<String, dynamic>>? fastLaneExtract(String text) {
//     final raw = text.trim();
//     if (raw.isEmpty) return null;

//     final normalized = _normalizeDigits(raw).toLowerCase();

//     // If it looks like a list but has only one number, let LLM decide splitting.
//     final allNums = RegExp(r'([0-9]+(?:[.,][0-9]+)?)').allMatches(normalized).toList();
//     final hasSeparators = RegExp(r'(,| و | and |&|\+)').hasMatch(normalized);
//     if (hasSeparators && allNums.length == 1) return null;

//     final chunks = normalized
//         .split(RegExp(r'(?:,| و | and |&|\+)+'))
//         .map((s) => s.trim())
//         .where((s) => s.isNotEmpty)
//         .toList();

//     final today = _toIsoDate(DateTime.now());
//     final out = <Map<String, dynamic>>[];

//     for (final chunk in chunks) {
//       final m = RegExp(r'([0-9]+(?:[.,][0-9]+)?)').firstMatch(chunk);
//       if (m == null) continue;

//       final price = _coercePrice(m.group(1));
//       if (price <= 0) continue;

//       var itemText = chunk.replaceFirst(m.group(1)!, '');
//       itemText = itemText
//           .replaceAll(RegExp(r'(egp|usd|tl|try|sar|eur|جنيه|ريال|ليرة|\$|€|£|pounds?|dollars?)'), '')
//           .replaceAll(RegExp(r'\b(for|على|ب|في|عن)\b'), '')
//           .trim();

//       final basis = itemText.isNotEmpty ? itemText : chunk;
//       final category = _guessCategory(basis);
//       final name = _guessItemName(basis, category);

//       out.add({
//         'item_name': name,
//         'unit_price': price,
//         'category': category,
//         'date_of_purchase': today,
//       });
//     }

//     return out.isNotEmpty ? out : null;
//   }

//   // ───────────────────────────────────────────
//   // STEP 2: Text → structured JSON (LLM)
//   // ───────────────────────────────────────────
//   static Future<List<Map<String, dynamic>>?> extractStructuredData(
//     String speechText,
//   ) async {
//     if (_apiKey.isEmpty) {
//       debugPrint('OpenAI API key is missing');
//       return [];
//     }

//     final uri = Uri.parse('https://api.openai.com/v1/chat/completions');

//     final body = <String, dynamic>{
//       'model': _parseModel,
//       'temperature': 0.0,
//       'response_format': {'type': 'json_object'},
//       'messages': [
//         {'role': 'system', 'content': _parserSystem},
//         {'role': 'user', 'content': speechText},
//       ],
//     };

//     http.Response resp;
//     try {
//       resp = await _client
//           .post(
//             uri,
//             headers: {
//               'Content-Type': 'application/json',
//               'Authorization': 'Bearer $_apiKey',
//             },
//             body: jsonEncode(body),
//           )
//           .timeout(const Duration(seconds: 30));
//     } catch (e) {
//       debugPrint('GPT parsing exception: $e');
//       return [];
//     }

//     if (resp.statusCode != 200) {
//       debugPrint('GPT parsing error ${resp.statusCode}: ${resp.body}');
//       return [];
//     }

//     final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
//     final choice = (decoded['choices'] as List).first as Map<String, dynamic>;
//     final message = (choice['message'] as Map<String, dynamic>?) ?? {};

//     final contentStr = (message['content'] as String?)?.trim();

//     Map<String, dynamic> jsonOut = {};
//     if (contentStr != null && contentStr.isNotEmpty) {
//       try {
//         jsonOut = jsonDecode(contentStr) as Map<String, dynamic>;
//       } catch (_) {
//         final start = contentStr.indexOf('{');
//         final end = contentStr.lastIndexOf('}');
//         if (start >= 0 && end > start) {
//           final candidate = contentStr.substring(start, end + 1);
//           try { jsonOut = jsonDecode(candidate) as Map<String, dynamic>; } catch (_) {}
//         }
//       }
//     }

//     if (jsonOut.isEmpty && message.containsKey('function_call')) {
//       try {
//         final fnCall = message['function_call'] as Map<String, dynamic>;
//         final args = jsonDecode(fnCall['arguments'] as String) as Map<String, dynamic>;
//         jsonOut = args;
//       } catch (_) {}
//     }

//     if (jsonOut.isEmpty) {
//       debugPrint('⚠️ Could not parse JSON. Raw message:\n${message['content']}');
//       return [];
//     }

//     final rawList = (jsonOut['expenses'] ?? jsonOut['items'] ?? []) as List<dynamic>;
//     final now = DateTime.now();

//     final out = <Map<String, dynamic>>[];
//     for (final e in rawList) {
//       if (e is! Map) continue;
//       final m = Map<String, dynamic>.from(e as Map);

//       final name = (m['item_name'] ?? m['name'] ?? '').toString().trim();
//       if (name.isEmpty) continue;

//       final priceVal = _coercePrice(m['unit_price']);

//       String category = (m['category'] ?? 'General').toString().trim();
//       category = _normalizeCategory(category);

//       String dateStr = (m['date_of_purchase'] ?? '').toString().trim();
//       DateTime dt;
//       if (dateStr.isEmpty || _looksLikeToday(dateStr)) {
//         dt = now;
//       } else {
//         dt = DateTime.tryParse(dateStr) ?? now;
//       }

//       final tooOld = dt.year < now.year - 1;
//       final tooFuture = dt.isAfter(now.add(const Duration(days: 60)));
//       if (tooOld || tooFuture) dt = now;

//       dateStr = _toIsoDate(dt);

//       out.add({
//         'item_name': name,
//         'unit_price': priceVal,
//         'category': category,
//         'date_of_purchase': dateStr,
//       });
//     }

//     return out;
//   }

//   // ───────────────────────────────────────────
//   // Utility
//   // ───────────────────────────────────────────
//   static DateTime? normalizeDate(dynamic dateInput) {
//     if (dateInput == null) return DateTime.now();

//     if (dateInput is Timestamp) return dateInput.toDate();
//     if (dateInput is DateTime) return dateInput;

//     if (dateInput is String) {
//       try {
//         final s = dateInput.trim();
//         final today = DateTime.now();
//         final todayStr = '${today.year.toString().padLeft(4, '0')}-'
//             '${today.month.toString().padLeft(2, '0')}-'
//             '${today.day.toString().padLeft(2, '0')}';

//         if (s == todayStr) return DateTime.now(); // keep time-of-day
//         return DateTime.parse(s);
//       } catch (_) {
//         return DateTime.now();
//       }
//     }
//     return DateTime.now();
//   }

//   // ───────────────────────────────────────────
//   // Helpers
//   // ───────────────────────────────────────────
//   static bool _looksLikeToday(String s) {
//     final lower = s.toLowerCase().trim();
//     return lower == 'today' ||
//            lower == 'اليوم' ||
//            lower == 'النهاردة' ||
//            lower == 'النهارده';
//   }

//   static double _coercePrice(dynamic v) {
//     if (v == null) return 0.0;
//     if (v is num) return v.toDouble();
//     final s = _normalizeDigits(v.toString());
//     final cleaned = s.replaceAll(RegExp(r'[^0-9.,\-]'), '');
//     String normalized = cleaned;
//     if (cleaned.contains(',') && !cleaned.contains('.')) {
//       normalized = cleaned.replaceAll(',', '.');
//     } else {
//       normalized = cleaned.replaceAll(',', '');
//     }
//     return double.tryParse(normalized) ?? 0.0;
//   }

//   static String _normalizeCategory(String raw) {
//     final r = raw.toLowerCase();

//     // Food forms (Arabic + Arabizi)
//     if (_hasAny(r, [
//       'food','مطعم','اكل','أكل','akalt','aklt','akalet','akl','lunch','dinner','breakfast','grocer'
//     ])) return 'Food';

//     // Fuel
//     if (_hasAny(r, ['fuel','gas','petrol','بنزين'])) return 'Fuel';

//     // Beverages
//     if (_hasAny(r, ['drink','drinks','coffee','قهوة','latte'])) return 'Beverages';

//     // Health
//     if (_hasAny(r, ['health','دواء','علاج','med','medicine','vitamin','panadol','ibuprofen'])) return 'Health';

//     // Beauty
//     if (_hasAny(r, ['beauty','makeup','مكياج','مستحضرات','shampoo','cream'])) return 'Beauty';

//     // Clothing
//     if (_hasAny(r, ['cloth','clothing','تيشيرت','بنطلون','tshirt','jeans','shirt'])) return 'Clothing';

//     // Transport words → General (keep 7-category schema)
//     if (_hasAny(r, [
//       'مواصلات','mwaslat','mwasalat','mowasalat','mowaslat',
//       'rekebt','rakabt','rakebt','rkabt','ركبت','موصلات'
//     ])) return 'General';

//     // Generic going out → General
//     if (_hasAny(r, ['kharagt','5aragt','خرجت','khargt','khrgt'])) return 'General';

//     return 'General';
//   }

//   static String _guessCategory(String basis) => _normalizeCategory(basis);

//   static String _guessItemName(String basis, String category) {
//     final t = basis.toLowerCase();

//     // Explicit transport mentions
//     if (_hasAny(t, ['مواصلات','mwaslat','mwasalat','mowasalat','mowaslat'])) {
//       return 'مواصلات';
//     }
//     // Riding transport
//     if (_hasAny(t, ['rekebt','rakabt','rakebt','rkabt','ركبت'])) {
//       return 'مواصلات';
//     }
//     // Food-ish verbs
//     if (_hasAny(t, ['akalt','aklt','akl','اكل','أكل'])) {
//       return 'Food';
//     }
//     // Going out
//     if (_hasAny(t, ['kharagt','5aragt','خرجت','khargt','khrgt'])) {
//       return 'Outing';
//     }

//     switch (category) {
//       case 'Fuel':
//         return t.contains('بنزين') ? 'بنزين' : 'Fuel';
//       case 'Beverages':
//         if (t.contains('قهوة')) return 'قهوة';
//         if (t.contains('coffee')) return 'Coffee';
//         if (t.contains('latte')) return 'Latte';
//         return 'Drink';
//       case 'Food':
//         if (t.contains('مطعم')) return 'مطعم';
//         if (t.contains('pizza')) return 'Pizza';
//         if (t.contains('burger')) return 'Burger';
//         if (t.contains('grocer')) return 'Groceries';
//         return 'Food';
//       case 'Health':
//         if (t.contains('دواء')) return 'دواء';
//         if (t.contains('vitamin')) return 'Vitamins';
//         return 'Health';
//       case 'Beauty':
//         if (t.contains('مكياج')) return 'مكياج';
//         if (t.contains('shampoo')) return 'Shampoo';
//         return 'Beauty';
//       case 'Clothing':
//         if (t.contains('تيشيرت')) return 'تيشيرت';
//         if (t.contains('بنطلون')) return 'بنطلون';
//         if (t.contains('tshirt')) return 'T-Shirt';
//         return 'Clothes';
//       default:
//         return 'Purchase';
//     }
//   }

//   static bool _hasAny(String haystack, List<String> needles) {
//     for (final n in needles) {
//       if (haystack.contains(n)) return true;
//     }
//     return false;
//   }

//   static String _toIsoDate(DateTime dt) =>
//       '${dt.year.toString().padLeft(4, '0')}-'
//       '${dt.month.toString().padLeft(2, '0')}-'
//       '${dt.day.toString().padLeft(2, '0')}';

//   /// Convert Arabic-Indic digits to ASCII digits
//   static String _normalizeDigits(String s) {
//     const arabicIndic = {'٠':'0','١':'1','٢':'2','٣':'3','٤':'4','٥':'5','٦':'6','٧':'7','٨':'8','٩':'9'};
//     const easternArabicIndic = {'۰':'0','۱':'1','۲':'2','۳':'3','۴':'4','۵':'5','۶':'6','۷':'7','۸':'8','۹':'9'};
//     final buf = StringBuffer();
//     for (final ch in s.split('')) {
//       buf.write(arabicIndic[ch] ?? easternArabicIndic[ch] ?? ch);
//     }
//     return buf.toString();
//   }
// }

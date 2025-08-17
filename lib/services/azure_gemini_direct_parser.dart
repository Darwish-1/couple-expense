// lib/services/azure_gemini_direct_parser.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

// IMPORTANT: use the IO helpers variant so we can do service-account auth.
import 'package:googleapis_auth/auth_io.dart' as gauth;

class AzureGeminiDirectParser {
  // ------- ENV -------
  static String get _azureKey => dotenv.env['AZURE_SPEECH_KEY']?.trim() ?? '';
  static String get _azureRegion =>
      dotenv.env['AZURE_SPEECH_REGION']?.trim() ?? 'uaenorth';

  static String get _gcpProjectId =>
      dotenv.env['GCP_PROJECT_ID']?.trim() ?? '';
 static String get _gcpLocation =>
dotenv.env['GCP_VERTEX_LOCATION']?.trim() ?? 'us-central1';
  static String get _gcpModelShort =>
      dotenv.env['GCP_GEMINI_MODEL']?.trim() ?? 'gemini-2.5-flash-lite';
  static String get _gcpSaPath =>
      dotenv.env['GOOGLE_APPLICATION_CREDENTIALS']?.trim() ?? '';

  static String get _vertexGenerateUrl {
    // Vertex publisher model endpoint:
    // https://{location}-aiplatform.googleapis.com/v1/projects/{project}/locations/{location}/publishers/google/models/{model}:generateContent
    final base = 'https://aiplatform.googleapis.com';
    final path =
        '/v1/projects/${_gcpProjectId}/locations/${_gcpLocation}/publishers/google/models/${_gcpModelShort}:generateContent';
    return '$base$path';
  }

  // ------- PUBLIC API -------
  /// Returns { 'transcript': String, 'expenses': List<Map<String,dynamic>> }
 static Future<Map<String, dynamic>?> transcribeAndParse(File audioFile) async {
  if (_azureKey.isEmpty || _gcpProjectId.isEmpty) {
    debugPrint('❌ Missing AZURE_SPEECH_KEY or GCP_PROJECT_ID');
    return null;
  }

  // Start both tasks in parallel
  final transcriptFuture = _azureTranscribe(audioFile);
  final tokenFuture = _getGcpAccessToken();

  // Wait for Azure STT first (since we need transcript anyway)
  final transcript = await transcriptFuture;
  if (transcript == null || transcript.isEmpty) {
    return {
      'transcript': '',
      'expenses': <Map<String, dynamic>>[],
    };
  }

  // Get GCP token (may already be ready if it finished while Azure was running)
  final token = await tokenFuture;
  if (token == null) {
    debugPrint('❌ Could not obtain Google access token');
    return {
      'transcript': transcript,
      'expenses': <Map<String, dynamic>>[],
    };
  }

  // Parse with Gemini (Vertex AI) using structured output
  final expenses = await _geminiParseWithToken(transcript, token);

  return {
    'transcript': transcript,
    'expenses': expenses ?? <Map<String, dynamic>>[],
  };
}
static Future<List<Map<String, dynamic>>?> _geminiParseWithToken(
    String transcript, String token) async {
  try {
    final body = {
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': transcript}
          ]
        }
      ],
      'system_instruction': {
        'role': 'system',
        'parts': [
          {'text': _systemRules}
        ]
      },
      'generation_config': {
        'temperature': 0.0,
        'response_mime_type': 'application/json',
        'response_schema': _responseSchema,
      }
    };

    final resp = await http
        .post(
          Uri.parse(_vertexGenerateUrl),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 15));

    if (resp.statusCode != 200) {
      debugPrint('❌ Vertex generateContent error ${resp.statusCode}: ${resp.body}');
      return null;
    }

    final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
    final candidates = (decoded['candidates'] as List?) ?? const [];
    if (candidates.isEmpty) return null;

    String? jsonStr;
    try {
      final content = candidates.first['content'] as Map<String, dynamic>;
      final parts = (content['parts'] as List?) ?? const [];
      if (parts.isNotEmpty) {
        final firstPart = parts.first as Map<String, dynamic>;
        jsonStr = (firstPart['text'] ?? '').toString();
      }
    } catch (_) {}

    if (jsonStr == null || jsonStr.isEmpty) return null;

    Map<String, dynamic> obj;
    try {
      obj = jsonDecode(jsonStr) as Map<String, dynamic>;
    } catch (_) {
      final start = jsonStr.indexOf('{');
      final end = jsonStr.lastIndexOf('}');
      if (start >= 0 && end > start) {
        obj = jsonDecode(jsonStr.substring(start, end + 1))
            as Map<String, dynamic>;
      } else {
        return null;
      }
    }

    final list = (obj['expenses'] ?? []) as List<dynamic>;
    final out = <Map<String, dynamic>>[];
    for (final e in list) {
      if (e is! Map) continue;
      out.add(Map<String, dynamic>.from(e as Map));
    }
    return out;
  } catch (e) {
    debugPrint('❌ Gemini parse exception: $e');
    return null;
  }
}


  // ------- AZURE STT -------
  static Future<String?> _azureTranscribe(File audioFile) async {
    final uri = Uri.parse(
      'https://${_azureRegion}.stt.speech.microsoft.com'
      '/speech/recognition/conversation/cognitiveservices/v1?language=ar-EG',
    );

    final bytes = await audioFile.readAsBytes();
    final ct = _guessCt(audioFile.path);

    final headers = <String, String>{
      'Ocp-Apim-Subscription-Key': _azureKey,
      'Content-Type': '${ct.type}/${ct.subtype}',
      'Accept': 'application/json',
    };

    http.Response resp;
    try {
      resp = await http
          .post(uri, headers: headers, body: bytes)
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      debugPrint('Azure STT exception: $e');
      return null;
    }

    if (resp.statusCode != 200) {
      debugPrint('Azure STT error ${resp.statusCode}: ${resp.body}');
      return null;
    }

    try {
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final tx = (data['DisplayText'] ?? data['Text'] ?? '').toString().trim();
      return tx.isNotEmpty ? tx : null;
    } catch (_) {
      return null;
    }
  }

  // ------- GEMINI (Vertex AI) -------
 static Future<List<Map<String, dynamic>>?> _geminiParse(
    String transcript) async {
  try {
    // fetch token in parallel with request prep
    final tokenFuture = _getGcpAccessToken();

    final body = {
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': transcript}
          ]
        }
      ],
      'system_instruction': {
        'role': 'system',
        'parts': [
          {'text': _systemRules}
        ]
      },
      'generation_config': {
        'temperature': 0.0,
        'response_mime_type': 'application/json',
        'response_schema': _responseSchema,
      }
    };

    debugPrint('Vertex URL: $_vertexGenerateUrl');

    final token = await tokenFuture;
    if (token == null) {
      debugPrint('❌ Could not obtain Google access token');
      return null;
    }

    final resp = await http
        .post(
          Uri.parse(_vertexGenerateUrl),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 15));

    if (resp.statusCode != 200) {
      debugPrint(
          '❌ Vertex generateContent error ${resp.statusCode}: ${resp.body}');
      return null;
    }

    final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
    final candidates = (decoded['candidates'] as List?) ?? const [];
    if (candidates.isEmpty) {
      debugPrint('⚠️ No candidates returned from Gemini');
      return null;
    }

    String? jsonStr;
    try {
      final content = candidates.first['content'] as Map<String, dynamic>;
      final parts = (content['parts'] as List?) ?? const [];
      if (parts.isNotEmpty) {
        final firstPart = parts.first as Map<String, dynamic>;
        jsonStr = (firstPart['text'] ?? '').toString();
      }
    } catch (e) {
      debugPrint('⚠️ Failed to extract JSON text: $e');
    }

    if (jsonStr == null || jsonStr.isEmpty) {
      debugPrint('⚠️ Gemini returned empty JSON string');
      return null;
    }

    Map<String, dynamic> obj;
    try {
      obj = jsonDecode(jsonStr) as Map<String, dynamic>;
    } catch (_) {
      final start = jsonStr.indexOf('{');
      final end = jsonStr.lastIndexOf('}');
      if (start >= 0 && end > start) {
        obj = jsonDecode(jsonStr.substring(start, end + 1))
            as Map<String, dynamic>;
      } else {
        debugPrint('❌ Could not recover valid JSON from response');
        return null;
      }
    }

    final list = (obj['expenses'] ?? []) as List<dynamic>;
    final out = <Map<String, dynamic>>[];
    for (final e in list) {
      if (e is! Map) continue;
      out.add(Map<String, dynamic>.from(e as Map));
    }

    return out;
  } catch (e) {
    debugPrint('❌ Gemini parse exception: $e');
    return null;
  }
}

  // Obtain an OAuth2 access token for Vertex using the service account JSON
  // Using googleapis_auth/auth_io.dart (client-side for dev; not safe for prod)
static Future<String?> _getGcpAccessToken() async {
  try {
    // Load the JSON key from bundled assets (path comes from .env)
    final saAssetPath = dotenv.env['GCP_SA_ASSET'];
    if (saAssetPath == null || saAssetPath.isEmpty) {
      debugPrint('GCP_SA_ASSET not set in .env');
      return null;
    }

    final jsonStr = await rootBundle.loadString(saAssetPath);
    final jsonMap = jsonDecode(jsonStr) as Map<String, dynamic>;

    final creds = gauth.ServiceAccountCredentials.fromJson(jsonMap);
    debugPrint('Using SA: ${creds.email}');

    final scopes = ['https://www.googleapis.com/auth/cloud-platform'];

    final authClient = await gauth.clientViaServiceAccount(creds, scopes);
    try {
      final token = authClient.credentials.accessToken.data;
      return token;
    } finally {
      authClient.close();
    }
  } catch (e) {
    debugPrint('Token exchange failed (asset): $e');
    return null;
  }
}


  // ------- Helpers -------
  static MediaType _guessCt(String path) {
    final p = path.toLowerCase();
    if (p.endsWith('.webm')) return MediaType('audio', 'webm');
    if (p.endsWith('.m4a')) return MediaType('audio', 'mp4'); // AAC in MP4
    if (p.endsWith('.mp4')) return MediaType('audio', 'mp4');
    if (p.endsWith('.ogg') || p.endsWith('.opus')) {
      return MediaType('audio', 'ogg');
    }
    if (p.endsWith('.mp3') || p.endsWith('.mpga') || p.endsWith('.mpeg')) {
      return MediaType('audio', 'mpeg');
    }
    if (p.endsWith('.wav')) return MediaType('audio', 'wav');
    return MediaType('application', 'octet-stream');
  }

  static const String _systemRules = '''
You extract expense entries from casual speech in Egyptian Arabic, Arabizi, or English.
Return ONLY a single JSON object matching the provided schema.
Rules:
- Map prices to numbers only (no currency symbols).
- Category enum: Fuel, Food, Health, Beauty, Beverages, Clothing, General.
- Examples: بنزين→Fuel, مطعم/أكل→Food, قهوة/coffee→Beverages, مواصلات/rekebt→General.
''';

  static Map<String, dynamic> get _responseSchema => {
        'type': 'object',
        'properties': {
          'expenses': {
            'type': 'array',
            'items': {
              'type': 'object',
              'properties': {
                'item_name': {'type': 'string'},
                'unit_price': {'type': 'number'},
                'category': {
                  'type': 'string',
                  'enum': [
                    'Fuel',
                    'Food',
                    'Health',
                    'Beauty',
                    'Beverages',
                    'Clothing',
                    'General'
                  ]
                },
                'date_of_purchase': {'type': 'string', 'format': 'date'}
              },
              'required': [
                'item_name',
                'unit_price',
                'category',
                'date_of_purchase'
              ],
              'additionalProperties': false
            }
          }
        },
        'required': ['expenses'],
        'additionalProperties': false
      };
}

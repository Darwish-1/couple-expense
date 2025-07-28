import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class GptParser {
  static final String _apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';
  static final String _todayDate =
    DateTime.now().toIso8601String().split('T').first;

  /// Step 1: Transcribe audio using gpt‑4o‑mini‑transcribe
  static Future<String?> transcribeAudio(File audioFile) async {
    if (_apiKey.isEmpty) {
      print('OpenAI API key is missing');
      return null;
    }

    final uri = Uri.parse('https://api.openai.com/v1/audio/transcriptions');
    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $_apiKey'
      ..fields['model'] = 'gpt-4o-mini-transcribe'
      ..fields['language'] = 'ar'
      ..files.add(await http.MultipartFile.fromPath(
        'file',
        audioFile.path,
        contentType: MediaType('audio', 'mpeg'),
      ));

    final streamed = await request.send();
    final resp = await http.Response.fromStream(streamed);
    if (resp.statusCode == 200) {
      final decoded = jsonDecode(resp.body);
      return decoded['text'] as String?;
    } else {
      print('Transcription Error: ${resp.statusCode} - ${resp.body}');
      return null;
    }
  }

  /// Step 2: Parse transcript into structured data using gpt‑4o‑mini
  static Future<List<Map<String, dynamic>>?> extractStructuredData(
      String speechText) async {
    if (_apiKey.isEmpty) {
      print('OpenAI API key is missing');
      return [];
    }

    final chatResp = await http.post(
      Uri.parse('https://api.openai.com/v1/chat/completions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
      },
      body: jsonEncode({
        'model': 'gpt-4o-mini',
        'messages': [
          {
            'role': 'system',
            'content': '''
You are a smart voice assistant that extracts structured **expense data** from casual spoken input in EGYPTIAN Arabic or English.

Return only a JSON array. Each expense includes:
- "item_name": string
- "unit_price": number
- "category": string
- "date_of_purchase": string (YYYY-MM-DD)

Use today's date ("$_todayDate") if none mentioned.
Convert Egyptian slang numbers to numeric values, divide shared prices if grouped, skip items with unclear price. Output only raw JSON array.
'''
          },
          {
            'role': 'user',
            'content': speechText,
          }
        ],
        'temperature': 0.2,
      }),
    );

    print('Raw API response: ${chatResp.body}');
    if (chatResp.statusCode == 200) {
      final decoded = jsonDecode(chatResp.body);
      var content = decoded['choices'][0]['message']['content'] as String;
      content = content.replaceAll(RegExp(r'```json\n|```|\n'), '').trim();

      try {
        final result = jsonDecode(content);
        if (result is List) {
          return result.whereType<Map<String, dynamic>>().toList();
        } else {
          print('Error: Expected JSON array, got: $content');
          return [];
        }
      } catch (e) {
        print('Error parsing JSON: $e\nRaw content: $content');
        return [];
      }
    } else {
      print('GPT API Error: ${chatResp.statusCode} - ${chatResp.body}');
      return [];
    }
  }

  static DateTime? normalizeDate(dynamic dateInput) {
    if (dateInput == null) return DateTime.now();
    if (dateInput is Timestamp) return dateInput.toDate();
    if (dateInput is DateTime) return dateInput;
    if (dateInput is String) {
      try {
        return DateTime.parse(dateInput);
      } catch (e) {
        print('Error parsing date "$dateInput": $e');
        return DateTime.now();
      }
    }
    print('Unexpected dateInput type: ${dateInput.runtimeType}');
    return DateTime.now();
  }
}

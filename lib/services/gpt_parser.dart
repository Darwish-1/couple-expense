import 'dart:io';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class GptParser {
  static final String _apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';
 
  /// STEP 1: Audio → Text with Whisper-1 (fast & accurate)
  static Future<String?> transcribeAudio(File audioFile) async {
    if (_apiKey.isEmpty) {
      print('OpenAI API key is missing');
      return null;
    }
    final uri = Uri.parse('https://api.openai.com/v1/audio/transcriptions');
    final req = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $_apiKey'
      ..fields['model'] = 'whisper-1'
      ..fields['language'] = 'ar'
      ..files.add(await http.MultipartFile.fromPath(
        'file',
        audioFile.path,
        contentType: MediaType('audio', 'mpeg'),
      ));

    final streamed = await req.send();
    final resp = await http.Response.fromStream(streamed);
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body)['text'] as String?;
    }
    print('Transcription error ${resp.statusCode}: ${resp.body}');
    return null;
  }

  /// STEP 2: Text → Structured using gpt-3.5-turbo + function calling
  static Future<List<Map<String, dynamic>>?> extractStructuredData(
      String speechText) async {
    if (_apiKey.isEmpty) {
      print('OpenAI API key is missing');
      return [];
    }

    final uri = Uri.parse('https://api.openai.com/v1/chat/completions');
    final body = {
      'model': 'gpt-3.5-turbo',
      'messages': [
        {
          'role': 'system',
          'content': '''
You are an assistant that extracts expense items from casual spoken input in Egyptian Arabic or English.
For each item, return:
• item_name: string  
• unit_price: number  
• category: one of [Fuel, Food, Health, Beauty, Beverages, Clothing, General]  
• date_of_purchase: string YYYY-MM-DD (use today if no date)

Map things like:
- fuel, petrol, بنزين → Fuel  
- groceries, lunch, مطعم → Food  
- meds, vitamins → Health  
- makeup, مستحضرات → Beauty  
- drinks, coffee → Beverages  
- clothes, تيشيرت, بنطلون → Clothing  
- anything else → General  

Return exactly:
{"expenses":[{…},…]}
'''
        },
        {'role': 'user', 'content': speechText}
      ],
      'functions': [
        {
          'name': 'extract_expenses',
          'description': 'Return parsed expenses as JSON.',
          'parameters': {
            'type': 'object',
            'properties': {
              'expenses': {
                'type': 'array',
                'items': {
                  'type': 'object',
                  'properties': {
                    'item_name': {'type': 'string'},
                    'unit_price': {'type': 'number'},
                    'category': {'type': 'string'},
                    'date_of_purchase': {
                      'type': 'string',
                      'format': 'date'
                    }
                  },
                  'required': ['item_name', 'unit_price']
                }
              }
            },
            'required': ['expenses']
          }
        }
      ],
      'function_call': {'name': 'extract_expenses'},
      'temperature': 0.2,
    };

    final resp = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
      },
      body: jsonEncode(body),
    );
    if (resp.statusCode != 200) {
      print('GPT parsing error ${resp.statusCode}: ${resp.body}');
      return [];
    }

    final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
    final choice = (decoded['choices'] as List).first as Map<String, dynamic>;
    final message = choice['message'] as Map<String, dynamic>;

    // Defensive check
    if (!message.containsKey('function_call')) {
      print('⚠️ No function_call in response; raw content:\n${message['content']}');
      return [];
    }

    final fnCall = message['function_call'] as Map<String, dynamic>;
    final args = jsonDecode(fnCall['arguments'] as String) as Map<String, dynamic>;

    return (args['expenses'] as List)
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  /// Utility: normalize Firestore Timestamp or String to DateTime
  static DateTime? normalizeDate(dynamic dateInput) {
    if (dateInput == null) return DateTime.now();
    if (dateInput is Timestamp) return dateInput.toDate();
    if (dateInput is DateTime) return dateInput;
    if (dateInput is String) {
      try {
        return DateTime.parse(dateInput);
      } catch (_) {}
    }
    return DateTime.now();
  }
}

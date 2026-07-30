import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class AiResult {
  final bool isValid;
  final String category;
  final String reason;

  AiResult({
    required this.isValid,
    required this.category,
    required this.reason,
  });
}

class AiService {
  static final AiService _instance = AiService._internal();
  factory AiService() => _instance;
  AiService._internal();

  static const String _apiKeyPrefsKey = 'gemini_api_key';

  Future<String?> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_apiKeyPrefsKey);
  }

  Future<void> saveApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiKeyPrefsKey, key.trim());
  }

  String _normalizeCategory(String? raw) {
    if (raw == null) return 'Mountains';
    final lower = raw.trim().toLowerCase();
    if (lower.contains('waterfall') || lower.contains('fall')) {
      return 'Waterfalls';
    } else if (lower.contains('river') || lower.contains('lake') || lower.contains('pond') || lower.contains('stream') || lower.contains('water')) {
      return 'Rivers';
    } else {
      // Default fallback to Mountains so it shows in explore section
      return 'Mountains';
    }
  }

  Future<AiResult> detectPlace(File mediaFile) async {
    final apiKey = await getApiKey() ?? '';
    
    if (apiKey.isEmpty) {
      debugPrint('[AIService] No Gemini API Key set. Falling back to local heuristic/approval.');
      final path = mediaFile.path.toLowerCase();
      String suggestedCat = 'Mountains';
      if (path.contains('water') || path.contains('fall')) {
        suggestedCat = 'Waterfalls';
      } else if (path.contains('river') || path.contains('lake') || path.contains('stream')) {
        suggestedCat = 'Rivers';
      }
      
      return AiResult(
        isValid: true,
        category: suggestedCat,
        reason: 'Place approved (Local heuristics fallback - configure Gemini API Key in settings to enable full AI check).',
      );
    }

    try {
      final bytes = await mediaFile.readAsBytes();
      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: apiKey,
      );

      const prompt = '''
      Analyze the provided image/frame and determine if it represents a valid outdoor travel, nature, or historical/cultural monument destination (like waterfalls, mountains, rivers, historical monuments, beaches, forests, lakes, parks, etc.).
      
      Respond strictly in JSON format matching this schema:
      {
        "isValid": true or false,
        "category": "Waterfalls" or "Mountains" or "Rivers",
        "reason": "short explanation of what was detected"
      }
      ''';

      final content = [
        Content.multi([
          TextPart(prompt),
          DataPart('image/jpeg', bytes),
        ])
      ];

      final response = await model.generateContent(content).timeout(const Duration(seconds: 8));
      final responseText = response.text ?? '';
      
      // Extract JSON structure from code blocks if present
      String jsonString = responseText.trim();
      if (jsonString.contains('```json')) {
        jsonString = jsonString.split('```json').last.split('```').first.trim();
      } else if (jsonString.contains('```')) {
        jsonString = jsonString.split('```').last.split('```').first.trim();
      }

      final Map<String, dynamic> data = json.decode(jsonString);
      
      return AiResult(
        isValid: data['isValid'] as bool? ?? false,
        category: _normalizeCategory(data['category'] as String?),
        reason: data['reason'] as String? ?? 'Scanned successfully.',
      );
    } catch (e) {
      debugPrint('[AIService] Gemini detection failed: $e. Falling back to local approval.');
      return AiResult(
        isValid: true,
        category: 'Mountains',
        reason: 'Network/API error. Location accepted automatically.',
      );
    }
  }
}

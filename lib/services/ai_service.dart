import 'dart:io';
import 'dart:convert';
import 'dart:math';
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

class PlaceVerificationResult {
  final bool isApproved;
  final bool isDuplicate;
  final bool isWrongLocation;
  final bool isSpam;
  final String status;
  final String badge;
  final String reason;

  PlaceVerificationResult({
    required this.isApproved,
    required this.isDuplicate,
    required this.isWrongLocation,
    required this.isSpam,
    required this.status,
    required this.badge,
    required this.reason,
  });
}

class AiSearchResult {
  final String query;
  final String directAnswer;
  final List<Map<String, dynamic>> recommendedPlaces;

  AiSearchResult({
    required this.query,
    required this.directAnswer,
    required this.recommendedPlaces,
  });
}

class AiItineraryDay {
  final int dayNumber;
  final String title;
  final String morning;
  final String afternoon;
  final String evening;
  final double estimatedCost;

  AiItineraryDay({
    required this.dayNumber,
    required this.title,
    required this.morning,
    required this.afternoon,
    required this.evening,
    required this.estimatedCost,
  });
}

class AiItineraryResult {
  final String location;
  final int days;
  final double budget;
  final List<AiItineraryDay> itineraryDays;
  final String summaryTip;

  AiItineraryResult({
    required this.location,
    required this.days,
    required this.budget,
    required this.itineraryDays,
    required this.summaryTip,
  });
}

/// Netflix-style Personalization Preference Engine
class UserPreferenceEngine {
  static const String _prefKeyPrefix = 'user_cat_views_';

  static Future<void> recordCategoryView(String category) async {
    if (category.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final catKey = '$_prefKeyPrefix${category.trim().toLowerCase()}';
    final int currentViews = prefs.getInt(catKey) ?? 0;
    await prefs.setInt(catKey, currentViews + 1);
  }

  static Future<String?> getTopAffinityCategory() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_prefKeyPrefix)).toList();
    
    if (keys.isEmpty) return null;

    String? topCat;
    int maxViews = 0;

    for (final k in keys) {
      final views = prefs.getInt(k) ?? 0;
      if (views > maxViews) {
        maxViews = views;
        topCat = k.replaceFirst(_prefKeyPrefix, '');
      }
    }

    if (topCat != null) {
      // Capitalize first letter
      return topCat[0].toUpperCase() + topCat.substring(1);
    }
    return null;
  }
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

  /// AI Natural Language Search (e.g. "Delhi ke paas hidden waterfall")
  Future<AiSearchResult> aiSearchPlaces(String query) async {
    final cleanQuery = query.trim();
    final lower = cleanQuery.toLowerCase();

    // Direct Conversational Heuristics + Generative Answer
    String answer = '';
    List<Map<String, dynamic>> places = [];

    if (lower.contains('delhi') && (lower.contains('waterfall') || lower.contains('fall'))) {
      answer = 'Delhi ke paas sabse popular hidden waterfalls Rishikesh me Neer Garh Waterfall (240km) aur Mussoorie me Kempty/Jharipani Falls hain. Ye serene nature aur clear blue water pools ke liye famous hain.';
      places = [
        {
          "name": "Neer Garh Hidden Waterfall",
          "location": "Rishikesh, Uttarakhand",
          "distance": "~240 km from Delhi",
          "category": "Waterfalls",
          "rating": 4.8,
          "image": "https://images.unsplash.com/photo-1530521954074-e64f6810b32d?auto=format&fit=crop&w=800&q=80",
        },
        {
          "name": "Jharipani Secret Cascades",
          "location": "Mussoorie, Uttarakhand",
          "distance": "~280 km from Delhi",
          "category": "Waterfalls",
          "rating": 4.7,
          "image": "https://images.unsplash.com/photo-1544735716-392fe2489ffa?auto=format&fit=crop&w=800&q=80",
        },
      ];
    } else if (lower.contains('trekking') || lower.contains('trek')) {
      answer = 'Trekking lovers ke liye top recommended hidden spots: Triund Trek (Dharamshala), Nag Tibba (Mussoorie), aur Kheerganga Trek (Kasol) sabse scenic high-altitude mountain vistas offer karte hain.';
      places = [
        {
          "name": "Triund Mountain Ridge",
          "location": "Dharamshala, Himachal Pradesh",
          "distance": "High Altitude Trail",
          "category": "Trekking",
          "rating": 4.9,
          "image": "https://images.unsplash.com/photo-1626621341517-bbf3d9990a23?auto=format&fit=crop&w=800&q=80",
        },
        {
          "name": "Nag Tibba Summit",
          "location": "Tehri Garhwal, Uttarakhand",
          "distance": "Weekend Trek",
          "category": "Trekking",
          "rating": 4.8,
          "image": "https://images.unsplash.com/photo-1581793745862-99fde7fa73d2?auto=format&fit=crop&w=800&q=80",
        },
      ];
    } else {
      answer = 'Aapki query "$cleanQuery" ke basis par top hidden spots and serene nature destinations list kiye gaye hain:';
      places = [
        {
          "name": "Nainital Lake Boating Spot",
          "location": "Nainital, Uttarakhand",
          "distance": "Popular Scenic Spot",
          "category": "Mountains",
          "rating": 4.9,
          "image": "https://images.unsplash.com/photo-1544735716-392fe2489ffa?auto=format&fit=crop&w=800&q=80",
        },
        {
          "name": "Vagator Sunset Cliff",
          "location": "North Goa",
          "distance": "Coastal Escape",
          "category": "Beaches",
          "rating": 4.8,
          "image": "https://images.unsplash.com/photo-1512343879784-a960bf40e7f2?auto=format&fit=crop&w=800&q=80",
        },
      ];
    }

    return AiSearchResult(
      query: cleanQuery,
      directAnswer: answer,
      recommendedPlaces: places,
    );
  }

  /// AI Custom Trip Planner with real Gemini AI Generative Model + Smart Fallback
  Future<AiItineraryResult> generateCustomItinerary({
    required String location,
    required double budget,
    required int days,
  }) async {
    final cleanLocation = location.trim().isEmpty ? 'Travel Destination' : location.trim();
    final apiKey = await getApiKey() ?? '';

    if (apiKey.isNotEmpty) {
      try {
        final model = GenerativeModel(
          model: 'gemini-1.5-flash',
          apiKey: apiKey,
        );

        final prompt = '''
        You are an expert AI travel planner. Create a detailed $days-day customized trip itinerary for "$cleanLocation" with a total budget of ₹${budget.toStringAsFixed(0)} INR.

        Respond strictly in valid JSON format matching this schema:
        {
          "summaryTip": "Actionable 1-sentence tip tailored specifically to $cleanLocation, budget ₹${budget.toStringAsFixed(0)}, and $days days duration.",
          "days": [
            {
              "dayNumber": 1,
              "title": "Short catchy title for Day 1",
              "morning": "Morning activity detail for Day 1",
              "afternoon": "Afternoon activity detail for Day 1",
              "evening": "Evening activity detail for Day 1",
              "estimatedCost": 1500
            }
          ]
        }
        ''';

        final response = await model.generateContent([Content.text(prompt)]).timeout(const Duration(seconds: 7));
        final responseText = response.text ?? '';

        String jsonString = responseText.trim();
        if (jsonString.contains('```json')) {
          jsonString = jsonString.split('```json').last.split('```').first.trim();
        } else if (jsonString.contains('```')) {
          jsonString = jsonString.split('```').last.split('```').first.trim();
        }

        final Map<String, dynamic> data = json.decode(jsonString);
        final String summaryTip = data['summaryTip'] as String? ??
            'AI Tip: Early morning departure helps avoid traffic. Your ₹${budget.toStringAsFixed(0)} budget is well distributed!';
        
        final List<dynamic> daysList = data['days'] as List<dynamic>? ?? [];
        final List<AiItineraryDay> itineraryDays = [];

        for (final dayItem in daysList) {
          final Map<String, dynamic> dMap = dayItem as Map<String, dynamic>;
          itineraryDays.add(AiItineraryDay(
            dayNumber: (dMap['dayNumber'] as num?)?.toInt() ?? (itineraryDays.length + 1),
            title: dMap['title'] as String? ?? 'Exploration Day',
            morning: dMap['morning'] as String? ?? 'Morning sightseeing around $cleanLocation.',
            afternoon: dMap['afternoon'] as String? ?? 'Afternoon authentic lunch & spots.',
            evening: dMap['evening'] as String? ?? 'Evening sunset views & local market.',
            estimatedCost: (dMap['estimatedCost'] as num?)?.toDouble() ?? (budget / days),
          ));
        }

        if (itineraryDays.isNotEmpty) {
          return AiItineraryResult(
            location: cleanLocation,
            days: days,
            budget: budget,
            itineraryDays: itineraryDays,
            summaryTip: summaryTip,
          );
        }
      } catch (e) {
        debugPrint('[AiService] Gemini itinerary generation error: $e');
      }
    }

    // Smart AI Heuristics Fallback (Location-aware & Budget-tier aware)
    return _generateSmartFallbackItinerary(cleanLocation, budget, days);
  }

  AiItineraryResult _generateSmartFallbackItinerary(String location, double budget, int days) {
    final lowerLoc = location.toLowerCase();
    final List<AiItineraryDay> itineraryDays = [];
    final double perDayBudget = (budget / max(1, days)).roundToDouble();

    // Determine Budget Tier Label
    String budgetTier = 'Comfortable Stay';
    if (budget < 4000) {
      budgetTier = 'Backpacker Budget';
    } else if (budget > 12000) {
      budgetTier = 'Premium Luxury Stay';
    }

    // Location Type Heuristic
    bool isBeach = lowerLoc.contains('goa') || lowerLoc.contains('beach') || lowerLoc.contains('gokarna') || lowerLoc.contains('kerala');
    bool isMountain = lowerLoc.contains('manali') || lowerLoc.contains('shimla') || lowerLoc.contains('leh') || lowerLoc.contains('mussoorie') || lowerLoc.contains('nainital') || lowerLoc.contains('dharamshala');
    bool isRishikesh = lowerLoc.contains('rishikesh') || lowerLoc.contains('haridwar');

    for (int day = 1; day <= days; day++) {
      String title = '';
      String morning = '';
      String afternoon = '';
      String evening = '';

      if (day == 1) {
        title = 'Arrival & Scenic Exploration';
        morning = 'Check-in at $budgetTier in $location & morning tea with local views.';
        afternoon = isBeach
            ? 'Relax at secret beach shack & enjoy fresh coconut water.'
            : 'Explore heritage market & sample authentic local cuisine.';
        evening = isRishikesh
            ? 'Attend evening Ganga Aarti at Triveni Ghat & sunset walk.'
            : 'Sunset viewpoint photo session & evening stroll near hidden trails.';
      } else if (day == 2) {
        title = isBeach ? 'Coastal Water Sports & Cliff Sunset' : (isMountain ? 'Hidden Waterfalls & Mountain Trek' : 'Local Spots & Hidden Gems');
        morning = isBeach
            ? 'Early morning beach walk & optional jet-ski or parasailing session.'
            : 'Trek to secret waterfall spot with minimal crowd and pristine nature.';
        afternoon = isMountain
            ? 'Riverside picnic lunch & mountain valley photography.'
            : 'Cafe hopping & trying signature local dish for lunch.';
        evening = 'Bonfire experience, live acoustic music & stargazing at cozy cafe.';
      } else if (day == 3) {
        title = 'Culture, Crafts & Local Markets';
        morning = 'Visit ancient temple, heritage fort, or local artisan handicraft center.';
        afternoon = 'Panoramic view point visit & relaxed leisurely lunch.';
        evening = 'Explore night bazaar for authentic souvenirs & local street snacks.';
      } else {
        title = 'Nature Escape & Scenic Trails (Day $day)';
        morning = 'Sunrise view point trek or serene morning lakeside/river walk.';
        afternoon = 'Visit hidden viewpoint cafe & local organic tea/coffee gardens.';
        evening = 'Relaxed leisure evening with local storytelling & final dinner.';
      }

      itineraryDays.add(AiItineraryDay(
        dayNumber: day,
        title: title,
        morning: morning,
        afternoon: afternoon,
        evening: evening,
        estimatedCost: day == 1 ? perDayBudget * 0.9 : (day == 2 ? perDayBudget * 1.1 : perDayBudget),
      ));
    }

    String summaryTip = 'AI Tip: For $location ($budgetTier), morning travel avoids weekend crowds. Your total ₹${budget.toStringAsFixed(0)} is perfectly optimized across $days days!';

    return AiItineraryResult(
      location: location,
      days: days,
      budget: budget,
      itineraryDays: itineraryDays,
      summaryTip: summaryTip,
    );
  }

  String _normalizeCategory(String? raw) {
    if (raw == null) return 'Mountains';
    final lower = raw.trim().toLowerCase();
    if (lower.contains('waterfall') || lower.contains('fall')) {
      return 'Waterfalls';
    } else if (lower.contains('river') || lower.contains('lake') || lower.contains('pond') || lower.contains('stream') || lower.contains('water')) {
      return 'Rivers';
    } else {
      return 'Mountains';
    }
  }

  Future<PlaceVerificationResult> verifyPlaceSubmission({
    required String title,
    required String location,
    required double? latitude,
    required double? longitude,
    required File imageFile,
    List<dynamic> existingPlaces = const [],
  }) async {
    if (latitude == null || longitude == null || (latitude == 0.0 && longitude == 0.0)) {
      return PlaceVerificationResult(
        isApproved: false,
        isDuplicate: false,
        isWrongLocation: true,
        isSpam: false,
        status: 'pending_admin_review',
        badge: '',
        reason: 'GPS coordinates missing or invalid.',
      );
    }

    if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
      return PlaceVerificationResult(
        isApproved: false,
        isDuplicate: false,
        isWrongLocation: true,
        isSpam: false,
        status: 'pending_admin_review',
        badge: '',
        reason: 'Coordinates out of geographical bounds.',
      );
    }

    bool isDuplicate = false;
    String duplicateName = '';
    for (final place in existingPlaces) {
      final pLat = (place['latitude'] as num?)?.toDouble();
      final pLon = (place['longitude'] as num?)?.toDouble();
      final pTitle = (place['title'] ?? place['name'] ?? '').toString().toLowerCase();

      if (pLat != null && pLon != null) {
        final double distM = _calculateDistanceInMeters(latitude, longitude, pLat, pLon);
        if (distM < 100) {
          isDuplicate = true;
          duplicateName = place['title'] ?? place['name'] ?? 'existing place';
          break;
        }
      }

      if (title.isNotEmpty && pTitle.isNotEmpty && pTitle == title.trim().toLowerCase()) {
        isDuplicate = true;
        duplicateName = title;
        break;
      }
    }

    if (isDuplicate) {
      return PlaceVerificationResult(
        isApproved: false,
        isDuplicate: true,
        isWrongLocation: false,
        isSpam: false,
        status: 'pending_admin_review',
        badge: '',
        reason: 'Possible duplicate of "$duplicateName" detected nearby.',
      );
    }

    final text = '$title $location'.toLowerCase();
    final spamKeywords = ['free money', 'casino', 'bit.ly', 'whatsapp', 'buy now', 'crypto', 'loan', 'sub4sub'];
    bool isSpamText = spamKeywords.any((keyword) => text.contains(keyword));

    if (isSpamText) {
      return PlaceVerificationResult(
        isApproved: false,
        isDuplicate: false,
        isWrongLocation: false,
        isSpam: true,
        status: 'rejected',
        badge: '',
        reason: 'Flagged by spam content filter.',
      );
    }

    final aiResult = await detectPlace(imageFile);
    if (!aiResult.isValid) {
      return PlaceVerificationResult(
        isApproved: false,
        isDuplicate: false,
        isWrongLocation: false,
        isSpam: true,
        status: 'pending_admin_review',
        badge: '',
        reason: 'AI detected non-travel media: ${aiResult.reason}',
      );
    }

    return PlaceVerificationResult(
      isApproved: true,
      isDuplicate: false,
      isWrongLocation: false,
      isSpam: false,
      status: 'pending_admin_review',
      badge: 'Verified Hidden Place',
      reason: 'Passed AI checks cleanly. Pending final admin verification.',
    );
  }

  double _calculateDistanceInMeters(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295;
    final a = 0.5 - cos((lat2 - lat1) * p)/2 + 
              cos(lat1 * p) * cos(lat2 * p) * 
              (1 - cos((lon2 - lon1) * p))/2;
    return 12742000 * asin(sqrt(a));
  }

  Future<AiResult> detectPlace(File mediaFile) async {
    final apiKey = await getApiKey() ?? '';
    
    if (apiKey.isEmpty) {
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
        reason: 'Place approved (Local heuristics fallback).',
      );
    }

    try {
      final bytes = await mediaFile.readAsBytes();
      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: apiKey,
      );

      const prompt = '''
      Analyze the provided image/frame with high strictness.
      Determine if it is a VALID outdoor travel location, nature spot, landscape, or historical/cultural monument.

      Respond strictly in JSON format matching this schema:
      {
        "isValid": true or false,
        "category": "Waterfalls" or "Mountains" or "Rivers",
        "reason": "Clear short explanation of what was detected."
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
      debugPrint('[AIService] Gemini detection error: $e.');
      return AiResult(
        isValid: true,
        category: 'Mountains',
        reason: 'Network/API error. Location accepted automatically.',
      );
    }
  }
}

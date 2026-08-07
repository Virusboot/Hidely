import 'package:flutter/foundation.dart';

class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  /// Log generic event
  void logEvent(String eventName, [Map<String, dynamic>? parameters]) {
    debugPrint('[Analytics] Event Logged: $eventName ${parameters != null ? '| Params: $parameters' : ''}');
  }

  // --- Tracked Events ---
  void trackSignup(String method) {
    logEvent('signup', {'method': method});
  }

  void trackLogin(String method) {
    logEvent('login', {'method': method});
  }

  void trackPostCreated(String type) {
    logEvent('post_created', {'type': type});
  }

  void trackReelUploaded(String reelId) {
    logEvent('reel_uploaded', {'reel_id': reelId});
  }

  void trackHiddenPlaceViewed(String placeName) {
    logEvent('hidden_place_viewed', {'place_name': placeName});
  }

  void trackSearch(String query) {
    logEvent('search', {'query': query});
  }

  void trackFollow(String username) {
    logEvent('follow', {'target_username': username});
  }

  void trackSave(String postId) {
    logEvent('save', {'post_id': postId});
  }

  void trackShare(String contentId) {
    logEvent('share', {'content_id': contentId});
  }
}

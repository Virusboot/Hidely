import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hidely_new/services/notification_polling_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  AuthService._internal();
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  bool _isLoggedIn = false;
  String? _token;
  Map<String, dynamic>? _user;

  bool get isLoggedIn => _isLoggedIn;
  bool get isGuest => !_isLoggedIn;
  String? get token => _token;
  Map<String, dynamic>? get user => _user;

  String get userId {
    if (_user == null) return '';
    final id = _user!['id']?.toString() ?? _user!['_id']?.toString() ?? _user!['user_id']?.toString();
    if (id != null && id.isNotEmpty) return id;
    
    final username = _user!['username']?.toString();
    if (username != null && username.isNotEmpty) {
      return username.hashCode.abs().toString();
    }
    return '';
  }
  String get userName => _user?['name'] ?? '';
  String get userUsername => _user?['username'] ?? '';
  String get userGender => _user?['gender'] ?? '';
  String get userPronouns => _user?['pronouns'] ?? '';
  String get userEmail => _user?['email'] ?? '';
  String get userBio => _user?['bio'] ?? '';
  String get userProfilePicture => _user?['profile_picture'] ?? '';

  Set<String> _deletedPostIds = {};
  Set<String> get deletedPostIds => _deletedPostIds;

  Future<void> markPostAsDeletedLocally(String postIdStr) async {
    if (postIdStr.isEmpty) return;
    _deletedPostIds.add(postIdStr);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('deleted_post_ids', _deletedPostIds.toList());
  }

  bool isPostDeletedLocally(dynamic postId) {
    if (postId == null) return false;
    return _deletedPostIds.contains(postId.toString());
  }

  List<dynamic>? _cachedFeed;
  List<dynamic>? get cachedFeed => _cachedFeed;

  String get _userFeedCacheKey => userId.isNotEmpty ? 'cached_feed_posts_$userId' : 'cached_feed_posts_guest';

  Future<void> saveCachedFeed(List<dynamic> posts) async {
    if (posts.isEmpty) return;
    final boundedList = posts.length > 50 ? posts.sublist(0, 50) : posts;
    _cachedFeed = boundedList;
    try {
      final jsonStr = jsonEncode(boundedList);
      if (jsonStr.length > 500 * 1024) {
        final smallerList = boundedList.length > 25 ? boundedList.sublist(0, 25) : boundedList;
        _cachedFeed = smallerList;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_userFeedCacheKey, jsonEncode(smallerList));
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userFeedCacheKey, jsonStr);
    } catch (e) {
      debugPrint('[AuthService] Feed cache write error: $e');
    }
  }

  Future<List<dynamic>> loadCachedFeed() async {
    if (_cachedFeed != null && _cachedFeed!.isNotEmpty) return _cachedFeed!;
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_userFeedCacheKey);
      if (str != null && str.isNotEmpty) {
        final decoded = jsonDecode(str);
        if (decoded is List) {
          _cachedFeed = decoded;
          return decoded;
        }
      }
    } catch (_) {}
    return [];
  }

  /// Initialize and load saved session from Secure Storage with legacy migration
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();

    String? secureToken;
    try {
      secureToken = await _secureStorage.read(key: 'auth_token');
    } catch (e) {
      debugPrint('[AuthService] SecureStorage read error: $e');
    }

    if (secureToken == null || secureToken.isEmpty) {
      final legacyToken = prefs.getString('auth_token');
      if (legacyToken != null && legacyToken.isNotEmpty) {
        secureToken = legacyToken;
        try {
          await _secureStorage.write(key: 'auth_token', value: legacyToken);
          await prefs.remove('auth_token');
          debugPrint('[AuthService] Migrated legacy auth_token to FlutterSecureStorage.');
        } catch (_) {}
      }
    }

    _token = secureToken;
    final userJson = prefs.getString('auth_user');
    final deleted = prefs.getStringList('deleted_post_ids') ?? [];
    _deletedPostIds = Set<String>.from(deleted);

    if (_token != null && _token!.isNotEmpty && userJson != null) {
      try {
        _user = jsonDecode(userJson);
        _isLoggedIn = true;
        await loadCachedFeed();
        NotificationPollingService().startPolling();
      } catch (e) {
        await logout();
      }
    }
  }

  /// Call this when the user logs in successfully
  Future<void> login(String token, Map<String, dynamic> userData) async {
    _token = token;
    _user = Map<String, dynamic>.from(userData);
    _isLoggedIn = true;

    try {
      await _secureStorage.write(key: 'auth_token', value: token);
    } catch (e) {
      debugPrint('[AuthService] SecureStorage write error: $e');
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.setString('auth_user', jsonEncode(_user));

    List<Map<String, dynamic>> sessions = await getSessions();
    sessions.removeWhere((s) {
      final u = s['user'];
      return u != null && (u['id'] == userData['id'] || u['username'] == userData['username']);
    });
    sessions.add({'token': token, 'user': _user});

    try {
      await _secureStorage.write(key: 'auth_sessions', value: jsonEncode(sessions));
      await prefs.remove('auth_sessions');
    } catch (_) {}

    NotificationPollingService().startPolling();
  }

  /// Clear the local authentication session securely
  Future<void> logout() async {
    final activeUserKey = _userFeedCacheKey;

    _token = null;
    _user = null;
    _isLoggedIn = false;
    _cachedFeed = null;

    try {
      await _secureStorage.delete(key: 'auth_token');
      await _secureStorage.delete(key: 'auth_sessions');
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('auth_user');
    await prefs.remove('auth_sessions');
    await prefs.remove(activeUserKey);
    await prefs.remove('cached_feed_posts');

    NotificationPollingService().stopPolling();
  }

  /// Get list of all logged-in sessions securely
  Future<List<Map<String, dynamic>>> getSessions() async {
    String? jsonStr;
    try {
      jsonStr = await _secureStorage.read(key: 'auth_sessions');
    } catch (_) {}

    if (jsonStr == null || jsonStr.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      final sessionStrings = prefs.getStringList('auth_sessions') ?? [];
      List<Map<String, dynamic>> legacySessions = [];
      for (final s in sessionStrings) {
        try {
          legacySessions.add(jsonDecode(s) as Map<String, dynamic>);
        } catch (_) {}
      }
      return legacySessions;
    }

    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is List) {
        return decoded.map((item) => Map<String, dynamic>.from(item as Map)).toList();
      }
    } catch (_) {}
    return [];
  }

  /// Switch the active session to the one at specified index
  Future<void> switchAccount(int index) async {
    final sessions = await getSessions();
    if (index >= 0 && index < sessions.length) {
      final selected = sessions[index];
      _token = selected['token'];
      _user = selected['user'];
      _isLoggedIn = true;
      _cachedFeed = null;

      try {
        await _secureStorage.write(key: 'auth_token', value: _token!);
      } catch (_) {}

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_user', jsonEncode(_user));
      await loadCachedFeed();
    }
  }

  /// Remove a session by index
  Future<void> removeSession(int index) async {
    final sessions = await getSessions();
    if (index >= 0 && index < sessions.length) {
      final targetUser = sessions[index]['user'];
      final isActive = _user != null && (_user!['id'] == targetUser['id'] || _user!['username'] == targetUser['username']);

      sessions.removeAt(index);
      try {
        await _secureStorage.write(key: 'auth_sessions', value: jsonEncode(sessions));
      } catch (_) {}

      if (isActive) {
        if (sessions.isNotEmpty) {
          await switchAccount(0);
        } else {
          await logout();
        }
      }
    }
  }

  /// Get list of blocked usernames
  Future<List<String>> getBlockedUsers() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('blocked_users') ?? [];
  }

  /// Block a username
  Future<void> blockUser(String username) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('blocked_users') ?? [];
    if (!list.contains(username)) {
      list.add(username);
      await prefs.setStringList('blocked_users', list);
    }
  }

  /// Unblock a username
  Future<void> unblockUser(String username) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('blocked_users') ?? [];
    if (list.contains(username)) {
      list.remove(username);
      await prefs.setStringList('blocked_users', list);
    }
  }

  /// Check if a user is blocked
  Future<bool> isUserBlocked(String username) async {
    final list = await getBlockedUsers();
    return list.contains(username);
  }
}

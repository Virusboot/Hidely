import 'dart:convert';
import 'package:hidely_new/services/notification_polling_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  AuthService._internal();
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;

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

  /// Initialize and load saved session from SharedPreferences
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    final userJson = prefs.getString('auth_user');
    final deleted = prefs.getStringList('deleted_post_ids') ?? [];
    _deletedPostIds = Set<String>.from(deleted);

    if (_token != null && userJson != null) {
      try {
        _user = jsonDecode(userJson);
        _isLoggedIn = true;
        NotificationPollingService().startPolling();
      } catch (e) {
        // Clear corrupt data
        await logout();
      }
    }
  }

  /// Call this when the user logs in successfully
  Future<void> login(String token, Map<String, dynamic> userData) async {
    _token = token;
    


    if (_user != null) {
      _user = {..._user!, ...userData};
    } else {
      _user = userData;
    }
    _isLoggedIn = true;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
    await prefs.setString('auth_user', jsonEncode(_user));

    // Update sessions list
    final List<String> sessionStrings = prefs.getStringList('auth_sessions') ?? [];
    final sessionData = jsonEncode({'token': token, 'user': _user});
    
    // Avoid duplicates by comparing user id or username
    sessionStrings.removeWhere((s) {
      try {
        final decoded = jsonDecode(s);
        return decoded['user']['id'] == userData['id'] || decoded['user']['username'] == userData['username'];
      } catch (_) {
        return false;
      }
    });

    sessionStrings.add(sessionData);
    await prefs.setStringList('auth_sessions', sessionStrings);

    NotificationPollingService().startPolling();
  }

  /// Clear the local authentication session
  Future<void> logout() async {
    _token = null;
    _user = null;
    _isLoggedIn = false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('auth_user');
    await prefs.remove('auth_sessions');

    NotificationPollingService().stopPolling();
  }

  /// Get list of all logged-in sessions
  Future<List<Map<String, dynamic>>> getSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> sessionStrings = prefs.getStringList('auth_sessions') ?? [];
    List<Map<String, dynamic>> sessions = [];
    for (final s in sessionStrings) {
      try {
        sessions.add(jsonDecode(s) as Map<String, dynamic>);
      } catch (_) {}
    }
    return sessions;
  }

  /// Switch the active session to the one at specified index
  Future<void> switchAccount(int index) async {
    final sessions = await getSessions();
    if (index >= 0 && index < sessions.length) {
      final selected = sessions[index];
      _token = selected['token'];
      _user = selected['user'];
      _isLoggedIn = true;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', _token!);
      await prefs.setString('auth_user', jsonEncode(_user));
    }
  }

  /// Remove a session by index
  Future<void> removeSession(int index) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> sessionStrings = prefs.getStringList('auth_sessions') ?? [];
    if (index >= 0 && index < sessionStrings.length) {
      // Check if we are removing the active session
      final sessions = await getSessions();
      final targetUser = sessions[index]['user'];
      final isActive = _user != null && (_user!['id'] == targetUser['id'] || _user!['username'] == targetUser['username']);

      sessionStrings.removeAt(index);
      await prefs.setStringList('auth_sessions', sessionStrings);

      if (isActive) {
        if (sessionStrings.isNotEmpty) {
          // Switch to first remaining session
          await switchAccount(0);
        } else {
          // No sessions left, fully log out
          _token = null;
          _user = null;
          _isLoggedIn = false;
          await prefs.remove('auth_token');
          await prefs.remove('auth_user');
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

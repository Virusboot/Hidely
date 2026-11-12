import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hidely_new/services/api_service.dart';
import 'package:hidely_new/services/chat_socket_service.dart';
import 'package:hidely_new/services/notification_polling_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  AuthService._internal();
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      resetOnError: true,
    ),
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

  bool get isOfficialOrAdmin {
    if (_user == null) return false;
    final u = (_user?['username'] ?? '').toString().toLowerCase();
    final role = (_user?['role'] ?? '').toString().toLowerCase();
    final isOfficial = _user?['is_official'] == true || _user?['isOfficial'] == true;
    return u == 'hidely' ||
        u == 'hidely_official' ||
        u == 'admin' ||
        role == 'admin' ||
        isOfficial;
  }

  Set<String> _deletedPostIds = {};
  Set<String> get deletedPostIds => _deletedPostIds;

  final ValueNotifier<Set<String>> blockedUsersNotifier =
      ValueNotifier<Set<String>>(<String>{});

  final ValueNotifier<int> sessionEpochNotifier = ValueNotifier<int>(0);
  Set<String> _blockedUsernames = <String>{};

  static const Map<String, dynamic> defaultTagMentionSettings = <String, dynamic>{
    'allow_tags_from': 'everyone',
    'allow_mentions_from': 'everyone',
    'manually_approve_tags': false,
  };

  final ValueNotifier<Map<String, dynamic>> tagMentionSettingsNotifier =
      ValueNotifier<Map<String, dynamic>>(
    Map<String, dynamic>.from(defaultTagMentionSettings),
  );

  static String normalizeTagMentionPolicy(String? raw) {
    final clean = (raw ?? '').trim().toLowerCase();
    if (clean == 'following' || clean == 'people_you_follow') return 'following';
    if (clean == 'no_one' || clean == 'noone' || clean == 'none') return 'no_one';
    return 'everyone';
  }

  static String audiencePolicyLabel(String? policy) {
    switch (normalizeTagMentionPolicy(policy)) {
      case 'following':
        return 'People you follow';
      case 'no_one':
        return 'No one';
      case 'everyone':
      default:
        return 'Everyone';
    }
  }

  String get allowTagsFrom =>
      normalizeTagMentionPolicy(tagMentionSettingsNotifier.value['allow_tags_from']?.toString());

  String get allowMentionsFrom =>
      normalizeTagMentionPolicy(tagMentionSettingsNotifier.value['allow_mentions_from']?.toString());

  bool get manuallyApproveTags =>
      tagMentionSettingsNotifier.value['manually_approve_tags'] == true;

  String get tagMentionSummaryText =>
      'Tags: ${audiencePolicyLabel(allowTagsFrom)} · Mentions: ${audiencePolicyLabel(allowMentionsFrom)}';

  String get _tagMentionSettingsKey =>
      userId.isNotEmpty ? 'privacy_tags_mentions_$userId' : 'privacy_tags_mentions_guest';

  String get _pendingTagMentionSyncKey =>
      userId.isNotEmpty ? 'pending_privacy_tags_mentions_$userId' : 'pending_privacy_tags_mentions_guest';

  static String normalizeBlockedUsername(String? raw) {
    if (raw == null) return '';
    return raw.trim().replaceFirst(RegExp(r'^@+'), '').toLowerCase();
  }

  String get _blockedUsersKey =>
      userId.isNotEmpty ? 'blocked_users_$userId' : 'blocked_users_guest';

  String get _pendingBlockOpsKey =>
      userId.isNotEmpty ? 'pending_block_ops_$userId' : 'pending_block_ops_guest';

  /// Synchronous check whether [username] is currently blocked by this user.
  bool isUserBlockedSync(String? username) {
    final normalized = normalizeBlockedUsername(username);
    if (normalized.isEmpty) return false;
    return _blockedUsernames.contains(normalized);
  }

  /// Convenience filter for post maps across feeds, explore, reels, and post views.
  bool isPostFromBlockedUser(dynamic post) {
    if (post is! Map) return false;
    final author = post['author_username'] ??
        post['username'] ??
        post['author'] ??
        (post['user'] is Map ? post['user']['username'] : null);
    return isUserBlockedSync(author?.toString());
  }

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

  Future<void> _loadBlockedUsersFromStorage([SharedPreferences? prefs]) async {
    final sp = prefs ?? await SharedPreferences.getInstance();
    final scopedList = sp.getStringList(_blockedUsersKey);
    final legacyList = sp.getStringList('blocked_users');

    final Set<String> normalizedSet = <String>{};
    if (scopedList != null) {
      for (final entry in scopedList) {
        final clean = normalizeBlockedUsername(entry);
        if (clean.isNotEmpty) normalizedSet.add(clean);
      }
    }

    if (legacyList != null && legacyList.isNotEmpty) {
      final pending = List<String>.from(sp.getStringList(_pendingBlockOpsKey) ?? <String>[]);
      for (final entry in legacyList) {
        final clean = normalizeBlockedUsername(entry);
        if (clean.isNotEmpty) {
          normalizedSet.add(clean);
          final op = 'block:$clean';
          if (userId.isNotEmpty && !pending.contains(op)) {
            pending.add(op);
          }
        }
      }
      if (userId.isNotEmpty) {
        await sp.setStringList(_blockedUsersKey, normalizedSet.toList());
        await sp.setStringList(_pendingBlockOpsKey, pending);
        await sp.remove('blocked_users');
      }
    }

    _blockedUsernames = normalizedSet;
    blockedUsersNotifier.value = Set<String>.unmodifiable(normalizedSet);
  }

  Future<void> _loadTagMentionSettingsFromStorage([SharedPreferences? prefs]) async {
    final sp = prefs ?? await SharedPreferences.getInstance();
    final raw = sp.getString(_tagMentionSettingsKey);
    if (raw == null || raw.isEmpty) {
      tagMentionSettingsNotifier.value = Map<String, dynamic>.unmodifiable(
        Map<String, dynamic>.from(defaultTagMentionSettings),
      );
      return;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        final normalized = <String, dynamic>{
          'allow_tags_from': normalizeTagMentionPolicy(decoded['allow_tags_from']?.toString()),
          'allow_mentions_from': normalizeTagMentionPolicy(decoded['allow_mentions_from']?.toString()),
          'manually_approve_tags': decoded['manually_approve_tags'] == true,
        };
        tagMentionSettingsNotifier.value = Map<String, dynamic>.unmodifiable(normalized);
        return;
      }
    } catch (_) {}

    tagMentionSettingsNotifier.value = Map<String, dynamic>.unmodifiable(
      Map<String, dynamic>.from(defaultTagMentionSettings),
    );
  }

  /// Initialize and load saved session from Secure Storage with legacy migration
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();

    String? secureToken;
    try {
      secureToken = await _secureStorage.read(key: 'auth_token').timeout(
        const Duration(seconds: 2),
        onTimeout: () => null,
      );
    } catch (e) {
      debugPrint('[AuthService] SecureStorage read error: $e');
    }

    if (secureToken == null || secureToken.isEmpty) {
      final legacyToken = prefs.getString('auth_token');
      if (legacyToken != null && legacyToken.isNotEmpty) {
        secureToken = legacyToken;
        try {
          await _secureStorage
              .write(key: 'auth_token', value: legacyToken)
              .timeout(const Duration(seconds: 2));
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
        NotificationPollingService().startPolling();
      } catch (e) {
        await logout();
      }
    } else {
      _user = null;
      _isLoggedIn = false;
    }

    await _loadBlockedUsersFromStorage(prefs);
    await _loadTagMentionSettingsFromStorage(prefs);
    await loadCachedFeed();
  }

  /// Call this when the user logs in successfully
  Future<void> login(String token, Map<String, dynamic> userData) async {
    _token = token;
    _user = Map<String, dynamic>.from(userData);
    _isLoggedIn = true;

    try {
      await _secureStorage
          .write(key: 'auth_token', value: token)
          .timeout(const Duration(seconds: 2));
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
      await _secureStorage
          .write(key: 'auth_sessions', value: jsonEncode(sessions))
          .timeout(const Duration(seconds: 2));
      await prefs.remove('auth_sessions');
    } catch (_) {}

    await _loadBlockedUsersFromStorage(prefs);
    await _loadTagMentionSettingsFromStorage(prefs);
    ChatSocketService().disconnect();
    sessionEpochNotifier.value++;
    NotificationPollingService().restartPolling();
  }

  /// Update active JWT token after security rotation (e.g. password change)
  Future<void> updateSessionToken(String newToken) async {
    if (newToken.isEmpty || !_isLoggedIn) return;
    _token = newToken;
    try {
      await _secureStorage
          .write(key: 'auth_token', value: newToken)
          .timeout(const Duration(seconds: 2));
    } catch (_) {}

    final sessions = await getSessions();
    bool changed = false;
    for (int i = 0; i < sessions.length; i++) {
      final u = sessions[i]['user'];
      if (u != null && _user != null && (u['id'] == _user!['id'] || u['username'] == _user!['username'])) {
        sessions[i]['token'] = newToken;
        changed = true;
      }
    }
    if (changed) {
      try {
        await _secureStorage
            .write(key: 'auth_sessions', value: jsonEncode(sessions))
            .timeout(const Duration(seconds: 2));
      } catch (_) {}
    }
  }

  /// Permanently delete current user account on backend and purge local session data
  Future<ApiResult> deleteAccount({required String password}) async {
    final activeToken = _token;
    if (!_isLoggedIn || activeToken == null || activeToken.isEmpty) {
      return ApiResult(
        success: false,
        message: 'You must be signed in to delete your account.',
      );
    }

    final res = await ApiService().deleteAccount(
      token: activeToken,
      password: password,
    );

    if (!res.success) {
      return res;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_blockedUsersKey);
    await prefs.remove(_pendingBlockOpsKey);
    await prefs.remove(_tagMentionSettingsKey);
    await prefs.remove(_pendingTagMentionSyncKey);
    await prefs.remove(_userFeedCacheKey);

    final sessions = await getSessions();
    final activeId = _user?['id'];
    final activeUsername = _user?['username'];
    sessions.removeWhere((s) {
      final u = s['user'];
      return u != null && (u['id'] == activeId || u['username'] == activeUsername);
    });
    try {
      await _secureStorage
          .write(key: 'auth_sessions', value: jsonEncode(sessions))
          .timeout(const Duration(seconds: 2));
    } catch (_) {}

    await logout();
    return res;
  }

  /// Clear the local authentication session securely
  Future<void> logout() async {
    final activeUserKey = _userFeedCacheKey;

    _token = null;
    _user = null;
    _isLoggedIn = false;
    _cachedFeed = null;
    _blockedUsernames = <String>{};
    blockedUsersNotifier.value = <String>{};
    tagMentionSettingsNotifier.value = Map<String, dynamic>.unmodifiable(
      Map<String, dynamic>.from(defaultTagMentionSettings),
    );

    try {
      await _secureStorage.delete(key: 'auth_token').timeout(const Duration(seconds: 2));
      await _secureStorage.delete(key: 'auth_sessions').timeout(const Duration(seconds: 2));
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('auth_user');
    await prefs.remove('auth_sessions');
    await prefs.remove(activeUserKey);
    await prefs.remove('cached_feed_posts');

    ChatSocketService().disconnect();
    sessionEpochNotifier.value++;
    NotificationPollingService().stopPolling();
  }

  /// Get list of all logged-in sessions securely
  Future<List<Map<String, dynamic>>> getSessions() async {
    String? jsonStr;
    try {
      jsonStr = await _secureStorage.read(key: 'auth_sessions').timeout(
        const Duration(seconds: 2),
        onTimeout: () => null,
      );
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
        await _secureStorage
            .write(key: 'auth_token', value: _token!)
            .timeout(const Duration(seconds: 2));
      } catch (_) {}

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_user', jsonEncode(_user));
      await _loadBlockedUsersFromStorage(prefs);
      await _loadTagMentionSettingsFromStorage(prefs);
      await loadCachedFeed();
      ChatSocketService().disconnect();
      sessionEpochNotifier.value++;
      NotificationPollingService().restartPolling();
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
        await _secureStorage
            .write(key: 'auth_sessions', value: jsonEncode(sessions))
            .timeout(const Duration(seconds: 2));
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

  /// Update local user data fields and persist to storage
  Future<void> updateUserData(Map<String, dynamic> newFields) async {
    if (_user == null) return;
    _user!.addAll(newFields);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_user', jsonEncode(_user));
  }

  /// Get list of blocked usernames
  Future<List<String>> getBlockedUsers() async {
    if (_blockedUsernames.isEmpty) {
      await _loadBlockedUsersFromStorage();
    }
    return _blockedUsernames.toList();
  }

  Future<void> _recordPendingBlockOp(SharedPreferences prefs, String op, String cleanUsername) async {
    final list = List<String>.from(prefs.getStringList(_pendingBlockOpsKey) ?? <String>[]);
    list.remove('block:$cleanUsername');
    list.remove('unblock:$cleanUsername');
    list.add('$op:$cleanUsername');
    await prefs.setStringList(_pendingBlockOpsKey, list);
  }

  Future<void> _clearPendingBlockOp(SharedPreferences prefs, String cleanUsername) async {
    final list = List<String>.from(prefs.getStringList(_pendingBlockOpsKey) ?? <String>[]);
    final beforeLen = list.length;
    list.remove('block:$cleanUsername');
    list.remove('unblock:$cleanUsername');
    if (list.length != beforeLen) {
      await prefs.setStringList(_pendingBlockOpsKey, list);
    }
  }

  /// Block a username locally (immediately) and sync to backend when available
  Future<void> blockUser(String username) async {
    final clean = normalizeBlockedUsername(username);
    if (clean.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    if (_blockedUsernames.isEmpty) {
      await _loadBlockedUsersFromStorage(prefs);
    }

    _blockedUsernames = <String>{..._blockedUsernames, clean};
    await prefs.setStringList(_blockedUsersKey, _blockedUsernames.toList());
    blockedUsersNotifier.value = Set<String>.unmodifiable(_blockedUsernames);

    final activeToken = _token;
    if (activeToken != null && activeToken.isNotEmpty) {
      final res = await ApiService().blockUser(token: activeToken, identifier: clean);
      if (res.success) {
        await _clearPendingBlockOp(prefs, clean);
      } else if (res.statusCode != 400 && res.statusCode != 404) {
        await _recordPendingBlockOp(prefs, 'block', clean);
      } else if (res.statusCode == 404 && !res.message.toLowerCase().contains('target user')) {
        // Older backend without /api/users/block route returns HTML 404 or generic error
        await _recordPendingBlockOp(prefs, 'block', clean);
      }
    }
  }

  /// Unblock a username locally (immediately) and sync to backend when available
  Future<void> unblockUser(String username) async {
    final clean = normalizeBlockedUsername(username);
    if (clean.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    if (_blockedUsernames.isEmpty) {
      await _loadBlockedUsersFromStorage(prefs);
    }

    final nextSet = Set<String>.from(_blockedUsernames)..remove(clean);
    _blockedUsernames = nextSet;
    await prefs.setStringList(_blockedUsersKey, nextSet.toList());
    blockedUsersNotifier.value = Set<String>.unmodifiable(nextSet);

    final activeToken = _token;
    if (activeToken != null && activeToken.isNotEmpty) {
      final res = await ApiService().unblockUser(token: activeToken, identifier: clean);
      if (res.success) {
        await _clearPendingBlockOp(prefs, clean);
      } else {
        await _recordPendingBlockOp(prefs, 'unblock', clean);
      }
    }
  }

  /// Sync blocked users list with backend, flushing any offline/pending block ops first
  Future<void> syncBlockedUsersFromServer() async {
    final activeToken = _token;
    if (!_isLoggedIn || activeToken == null || activeToken.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final pendingOps = List<String>.from(prefs.getStringList(_pendingBlockOpsKey) ?? <String>[]);
    final List<String> remainingOps = <String>[];

    for (final entry in pendingOps) {
      final sep = entry.indexOf(':');
      if (sep <= 0) continue;
      final op = entry.substring(0, sep);
      final target = entry.substring(sep + 1);
      if (target.isEmpty) continue;

      if (op == 'block') {
        final res = await ApiService().blockUser(token: activeToken, identifier: target);
        if (!res.success && !(res.statusCode == 404 && res.message.toLowerCase().contains('target user'))) {
          remainingOps.add(entry);
        }
      } else if (op == 'unblock') {
        final res = await ApiService().unblockUser(token: activeToken, identifier: target);
        if (!res.success && !(res.statusCode == 404 && res.message.toLowerCase().contains('target user'))) {
          remainingOps.add(entry);
        }
      }
    }
    await prefs.setStringList(_pendingBlockOpsKey, remainingOps);

    final res = await ApiService().getBlockedUsers(token: activeToken);
    if (res.success && res.data != null) {
      final serverRaw = res.data?['blocked_users'] as List? ?? [];
      final Set<String> serverSet = <String>{};
      for (final item in serverRaw) {
        final clean = normalizeBlockedUsername(item?.toString());
        if (clean.isNotEmpty) serverSet.add(clean);
      }
      for (final opEntry in remainingOps) {
        final sep = opEntry.indexOf(':');
        if (sep <= 0) continue;
        final op = opEntry.substring(0, sep);
        final target = opEntry.substring(sep + 1);
        if (op == 'block') serverSet.add(target);
        if (op == 'unblock') serverSet.remove(target);
      }
      _blockedUsernames = serverSet;
      await prefs.setStringList(_blockedUsersKey, serverSet.toList());
      blockedUsersNotifier.value = Set<String>.unmodifiable(serverSet);
    }
  }

  /// Check if a user is blocked (case-insensitive)
  Future<bool> isUserBlocked(String username) async {
    final clean = normalizeBlockedUsername(username);
    if (clean.isEmpty) return false;
    if (_blockedUsernames.contains(clean)) return true;
    await _loadBlockedUsersFromStorage();
    return _blockedUsernames.contains(clean);
  }

  /// Sync Tags & Mentions privacy settings from backend (flushing any offline edits first)
  Future<void> syncTagMentionSettingsFromServer() async {
    final activeToken = _token;
    if (!_isLoggedIn || activeToken == null || activeToken.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    if (tagMentionSettingsNotifier.value == defaultTagMentionSettings) {
      await _loadTagMentionSettingsFromStorage(prefs);
    }

    final hasPendingSync = prefs.getBool(_pendingTagMentionSyncKey) == true;
    if (hasPendingSync) {
      final putRes = await ApiService().updateTagMentionSettings(
        token: activeToken,
        allowTagsFrom: allowTagsFrom,
        allowMentionsFrom: allowMentionsFrom,
        manuallyApproveTags: manuallyApproveTags,
      );
      if (putRes.success) {
        await prefs.remove(_pendingTagMentionSyncKey);
      }
    }

    final res = await ApiService().getTagMentionSettings(token: activeToken);
    if (res.success && res.data != null && res.data!['settings'] is Map) {
      final serverMap = Map<String, dynamic>.from(res.data!['settings'] as Map);
      final normalized = <String, dynamic>{
        'allow_tags_from': normalizeTagMentionPolicy(serverMap['allow_tags_from']?.toString()),
        'allow_mentions_from': normalizeTagMentionPolicy(serverMap['allow_mentions_from']?.toString()),
        'manually_approve_tags': serverMap['manually_approve_tags'] == true,
      };
      await prefs.setString(_tagMentionSettingsKey, jsonEncode(normalized));
      tagMentionSettingsNotifier.value = Map<String, dynamic>.unmodifiable(normalized);
    }
  }

  /// Update Tags & Mentions privacy settings locally immediately and sync to backend
  Future<ApiResult> updateTagMentionSettings({
    String? allowTagsFrom,
    String? allowMentionsFrom,
    bool? manuallyApproveTags,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final next = <String, dynamic>{
      'allow_tags_from': allowTagsFrom != null
          ? normalizeTagMentionPolicy(allowTagsFrom)
          : this.allowTagsFrom,
      'allow_mentions_from': allowMentionsFrom != null
          ? normalizeTagMentionPolicy(allowMentionsFrom)
          : this.allowMentionsFrom,
      'manually_approve_tags': manuallyApproveTags ?? this.manuallyApproveTags,
    };

    await prefs.setString(_tagMentionSettingsKey, jsonEncode(next));
    tagMentionSettingsNotifier.value = Map<String, dynamic>.unmodifiable(next);

    final activeToken = _token;
    if (activeToken == null || activeToken.isEmpty) {
      return ApiResult(
        success: true,
        message: 'Saved locally.',
        data: {'synced': false, 'settings': next},
      );
    }

    final res = await ApiService().updateTagMentionSettings(
      token: activeToken,
      allowTagsFrom: next['allow_tags_from'] as String,
      allowMentionsFrom: next['allow_mentions_from'] as String,
      manuallyApproveTags: next['manually_approve_tags'] as bool,
    );

    if (res.success) {
      await prefs.remove(_pendingTagMentionSyncKey);
      if (res.data?['settings'] is Map) {
        final serverMap = Map<String, dynamic>.from(res.data!['settings'] as Map);
        final confirmed = <String, dynamic>{
          'allow_tags_from': normalizeTagMentionPolicy(serverMap['allow_tags_from']?.toString()),
          'allow_mentions_from': normalizeTagMentionPolicy(serverMap['allow_mentions_from']?.toString()),
          'manually_approve_tags': serverMap['manually_approve_tags'] == true,
        };
        await prefs.setString(_tagMentionSettingsKey, jsonEncode(confirmed));
        tagMentionSettingsNotifier.value = Map<String, dynamic>.unmodifiable(confirmed);
      }
      return ApiResult(
        success: true,
        message: res.message,
        data: {'synced': true, 'settings': tagMentionSettingsNotifier.value},
        statusCode: res.statusCode,
      );
    }

    await prefs.setBool(_pendingTagMentionSyncKey, true);
    return ApiResult(
      success: true,
      message: 'Saved on device. Will sync when server is ready.',
      data: {'synced': false, 'settings': next},
      statusCode: res.statusCode,
    );
  }
}

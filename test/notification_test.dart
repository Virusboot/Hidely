import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidely_new/screens/creator_profile_screen.dart';
import 'package:hidely_new/screens/notification_screen.dart';
import 'package:hidely_new/services/api_service.dart';
import 'package:hidely_new/services/auth_service.dart';
import 'package:hidely_new/services/notification_polling_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockResponseConfig {
  final int statusCode;
  final String body;
  const _MockResponseConfig(this.statusCode, this.body);
}

class _FakeHttpOverrides extends HttpOverrides {
  final _MockResponseConfig Function(String method, Uri uri) responder;
  _FakeHttpOverrides(this.responder);

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return _FakeHttpClient(responder);
  }
}

class _FakeHttpClient implements HttpClient {
  final _MockResponseConfig Function(String method, Uri uri) responder;
  _FakeHttpClient(this.responder);

  @override
  bool autoUncompress = true;

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async =>
      _FakeHttpClientRequest(responder(method, url));

  @override
  Future<HttpClientRequest> getUrl(Uri url) => openUrl('GET', url);

  @override
  Future<HttpClientRequest> postUrl(Uri url) => openUrl('POST', url);

  @override
  Future<HttpClientRequest> patchUrl(Uri url) => openUrl('PATCH', url);

  @override
  Future<HttpClientRequest> deleteUrl(Uri url) => openUrl('DELETE', url);

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpClientRequest implements HttpClientRequest {
  final _MockResponseConfig config;
  @override
  final HttpHeaders headers = _FakeHttpHeaders();
  @override
  bool followRedirects = true;
  @override
  int maxRedirects = 5;
  @override
  int contentLength = -1;
  @override
  bool persistentConnection = true;
  @override
  Encoding encoding = utf8;

  _FakeHttpClientRequest(this.config);

  @override
  void add(List<int> data) {}

  @override
  Future<void> addStream(Stream<List<int>> stream) async {}

  @override
  Future<HttpClientResponse> close() async =>
      _FakeHttpClientResponse(config.statusCode, config.body);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpClientResponse extends Stream<List<int>>
    implements HttpClientResponse {
  @override
  final int statusCode;
  final List<int> _bytes;
  @override
  final HttpHeaders headers = _FakeHttpHeaders();

  _FakeHttpClientResponse(this.statusCode, String body)
      : _bytes = utf8.encode(body);

  @override
  int get contentLength => _bytes.length;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  bool get isRedirect => false;

  @override
  List<RedirectInfo> get redirects => const <RedirectInfo>[];

  @override
  List<Cookie> get cookies => const <Cookie>[];

  @override
  X509Certificate? get certificate => null;

  @override
  HttpConnectionInfo? get connectionInfo => null;

  @override
  bool get persistentConnection => false;

  @override
  String get reasonPhrase => 'OK';

  @override
  Future<Socket> detachSocket() => throw UnimplementedError();

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.fromIterable([_bytes]).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpHeaders implements HttpHeaders {
  final Map<String, List<String>> _map = {};

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    _map[name.toLowerCase()] = [value.toString()];
  }

  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {
    _map.putIfAbsent(name.toLowerCase(), () => []).add(value.toString());
  }

  @override
  void forEach(void Function(String name, List<String> values) action) {
    _map.forEach(action);
  }

  @override
  String? value(String name) => _map[name.toLowerCase()]?.first;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel secureStorageChannel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  const MethodChannel localNotifChannel =
      MethodChannel('dexterous.com/flutter_local_notifications');
  final Map<String, String> fakeSecureStore = <String, String>{};

  setUpAll(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    messenger.setMockMethodCallHandler(secureStorageChannel, (call) async {
      final args = call.arguments is Map ? Map<String, dynamic>.from(call.arguments as Map) : const <String, dynamic>{};
      switch (call.method) {
        case 'read':
          return fakeSecureStore[args['key']?.toString()];
        case 'write':
          final k = args['key']?.toString();
          final v = args['value']?.toString();
          if (k != null && v != null) fakeSecureStore[k] = v;
          return null;
        case 'delete':
          fakeSecureStore.remove(args['key']?.toString());
          return null;
        case 'deleteAll':
          fakeSecureStore.clear();
          return null;
        case 'readAll':
          return Map<String, String>.from(fakeSecureStore);
        case 'containsKey':
          return fakeSecureStore.containsKey(args['key']?.toString());
        default:
          return null;
      }
    });

    messenger.setMockMethodCallHandler(localNotifChannel, (call) async {
      if (call.method == 'initialize' ||
          call.method == 'requestNotificationsPermission' ||
          call.method == 'requestPermissions') {
        return true;
      }
      return null;
    });
  });

  setUp(() async {
    fakeSecureStore.clear();
    NotificationPollingService().stopPolling();
  });

  tearDown(() async {
    HttpOverrides.global = null;
    ApiService().resetClientForTest();
    NotificationPollingService().stopPolling();
  });

  void installFakeHttp(
    _MockResponseConfig Function(String method, Uri uri) responder,
  ) {
    HttpOverrides.global = _FakeHttpOverrides(responder);
    ApiService().resetClientForTest();
  }

  test('NotificationPollingService helpers parse IDs and unread flags accurately', () {
    expect(NotificationPollingService.parseNotificationId({'id': 42}), 42);
    expect(NotificationPollingService.parseNotificationId({'_id': '99'}), 99);
    expect(NotificationPollingService.parseNotificationId({}), 0);

    expect(NotificationPollingService.isUnreadNotification({'is_read': false}), isTrue);
    expect(NotificationPollingService.isUnreadNotification({'is_read': 0}), isTrue);
    expect(NotificationPollingService.isUnreadNotification({'is_read': true}), isFalse);
    expect(NotificationPollingService.isUnreadNotification({'is_read': 1}), isFalse);
    expect(NotificationPollingService.isUnreadNotification({'is_read': 'true'}), isFalse);
  });

  test('AuthService blockUser and unblockUser normalize handles and update notifier', () async {
    SharedPreferences.setMockInitialValues({
      'auth_token': 'valid-jwt',
      'auth_user': jsonEncode({'id': 24, 'username': 'tester', 'name': 'Tester'}),
    });
    installFakeHttp((method, uri) {
      if (uri.path.contains('/api/users/block/')) {
        return const _MockResponseConfig(200, '{"message":"ok","blocked":true}');
      }
      return const _MockResponseConfig(200, '{}');
    });

    await AuthService().init();
    await AuthService().blockUser('  @Alice_Explorer  ');

    expect(AuthService().isUserBlockedSync('alice_explorer'), isTrue);
    expect(AuthService().isUserBlockedSync('@ALICE_EXPLORER'), isTrue);
    expect(AuthService().blockedUsersNotifier.value.contains('alice_explorer'), isTrue);
    expect(
      AuthService().isPostFromBlockedUser({'author_username': '@Alice_Explorer'}),
      isTrue,
    );

    await AuthService().unblockUser('@Alice_Explorer');
    expect(AuthService().isUserBlockedSync('alice_explorer'), isFalse);
    expect(AuthService().blockedUsersNotifier.value.contains('alice_explorer'), isFalse);

    await AuthService().logout();
  });

  testWidgets('NotificationScreen shows Sign In prompt for guests', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await AuthService().logout();

    await tester.pumpWidget(const MaterialApp(home: NotificationScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Sign In for Notifications'), findsOneWidget);
    expect(find.text('No Notifications Yet'), findsNothing);
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Image &&
            w.image is AssetImage &&
            (w.image as AssetImage).assetName == 'assets/images/back_icon.png',
      ),
      findsOneWidget,
    );
    NotificationPollingService().stopPolling();
  });

  testWidgets('NotificationScreen shows Session Expired on 401 when cache is empty', (tester) async {
    SharedPreferences.setMockInitialValues({
      'auth_token': 'expired-jwt',
      'auth_user': jsonEncode({'id': 24, 'username': 'tester', 'name': 'Tester'}),
    });
    installFakeHttp((method, uri) {
      if (uri.path.contains('/api/notifications')) {
        return const _MockResponseConfig(401, '{"error":"Token is invalid or expired."}');
      }
      if (uri.path.contains('/following')) {
        return const _MockResponseConfig(401, '{"error":"Token is invalid or expired."}');
      }
      return const _MockResponseConfig(200, '{}');
    });

    await AuthService().init();

    await tester.pumpWidget(const MaterialApp(home: NotificationScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Session Expired'), findsOneWidget);
    expect(find.text('Log In Again'), findsOneWidget);
    expect(find.text('No Notifications Yet'), findsNothing);
    NotificationPollingService().stopPolling();
  });

  testWidgets('NotificationScreen preserves cached notifications when server returns 401', (tester) async {
    SharedPreferences.setMockInitialValues({
      'auth_token': 'expired-jwt',
      'auth_user': jsonEncode({'id': 24, 'username': 'tester', 'name': 'Tester'}),
      'cached_notifications_24': jsonEncode([
        {
          'id': 85,
          'type': 'points_earned',
          'actor_name': '',
          'actor_username': '',
          'text': '🔥 Daily Check-In Complete! — You earned +10 points',
          'is_read': false,
          'created_at': DateTime.now().toIso8601String(),
        },
        {
          'id': 84,
          'type': 'like',
          'actor_name': 'Arjun',
          'actor_username': 'arjun_travels',
          'text': 'liked your post.',
          'is_read': true,
          'created_at': DateTime.now().toIso8601String(),
        },
      ]),
      'cached_unread_count_24': 1,
    });

    installFakeHttp((method, uri) {
      if (uri.path.contains('/api/notifications')) {
        return const _MockResponseConfig(401, '{"error":"Token is invalid or expired."}');
      }
      return const _MockResponseConfig(401, '{"error":"Token is invalid or expired."}');
    });

    await AuthService().init();

    await tester.pumpWidget(const MaterialApp(home: NotificationScreen()));
    await tester.pumpAndSettle();

    expect(find.text('No Notifications Yet'), findsNothing);
    expect(find.textContaining('Session expired — showing saved notifications'), findsOneWidget);
    expect(find.text('New'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.byWidgetPredicate((w) => w is RichText && w.text.toPlainText().contains('Arjun')), findsOneWidget);
    expect(find.byWidgetPredicate((w) => w is RichText && w.text.toPlainText().contains('Hidely')), findsOneWidget);
    NotificationPollingService().stopPolling();
  });

  testWidgets('NotificationScreen shows genuine empty state on 200 empty list', (tester) async {
    SharedPreferences.setMockInitialValues({
      'auth_token': 'valid-jwt',
      'auth_user': jsonEncode({'id': 24, 'username': 'tester', 'name': 'Tester'}),
    });
    installFakeHttp((method, uri) {
      if (uri.path.contains('/api/notifications')) {
        return const _MockResponseConfig(200, '{"notifications":[],"unread_count":0}');
      }
      if (uri.path.contains('/following')) {
        return const _MockResponseConfig(200, '{"following":[]}');
      }
      return const _MockResponseConfig(200, '{}');
    });

    await AuthService().init();

    await tester.pumpWidget(const MaterialApp(home: NotificationScreen()));
    await tester.pumpAndSettle();

    expect(find.text('No Notifications Yet'), findsOneWidget);
    NotificationPollingService().stopPolling();
  });

  testWidgets('CreatorProfileScreen hides profile completely when user is blocked locally', (tester) async {
    SharedPreferences.setMockInitialValues({
      'auth_token': 'valid-jwt',
      'auth_user': jsonEncode({'id': 24, 'username': 'tester', 'name': 'Tester'}),
      'blocked_users_24': ['blocked_user'],
    });
    installFakeHttp((method, uri) {
      return _MockResponseConfig(
        200,
        jsonEncode({
          'creator': {
            'id': 99,
            'username': 'blocked_user',
            'name': 'Secret Explorer',
            'bio': 'Hidden bio text that must not appear',
            'followers_count': 42,
            'followings_count': 7,
            'posts_count': 3,
          },
          'posts': [],
        }),
      );
    });

    await AuthService().init();

    await tester.pumpWidget(
      const MaterialApp(
        home: CreatorProfileScreen(
          username: 'blocked_user',
          bio: 'Secret passed bio',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('You blocked @blocked_user'), findsOneWidget);
    expect(find.text('Their profile, bio, and posts are hidden.'), findsOneWidget);
    expect(find.text('Unblock'), findsOneWidget);
    expect(find.text('Go Back'), findsOneWidget);
    expect(find.text('Secret Explorer'), findsNothing);
    expect(find.text('Secret passed bio'), findsNothing);
    expect(find.text('Hidden bio text that must not appear'), findsNothing);
    expect(find.text('Follow'), findsNothing);
    expect(find.text('Message'), findsNothing);
    expect(find.text('hidelys'), findsNothing);
    NotificationPollingService().stopPolling();
  });

  testWidgets('CreatorProfileScreen hides profile with no Unblock when blocked by target (403)', (tester) async {
    SharedPreferences.setMockInitialValues({
      'auth_token': 'valid-jwt',
      'auth_user': jsonEncode({'id': 24, 'username': 'tester', 'name': 'Tester'}),
    });
    installFakeHttp((method, uri) {
      if (uri.path.contains('/api/users/profile/')) {
        return _MockResponseConfig(
          403,
          jsonEncode({
            'error': 'This profile is unavailable.',
            'blocked': true,
            'blocked_by_me': false,
            'blocked_me': true,
            'posts': [],
          }),
        );
      }
      return const _MockResponseConfig(200, '{}');
    });

    await AuthService().init();

    await tester.pumpWidget(
      const MaterialApp(
        home: CreatorProfileScreen(
          username: 'hidely_official',
          bio: 'Prefilled bio must stay hidden',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Profile Unavailable'), findsWidgets);
    expect(find.text('This profile is currently unavailable.'), findsOneWidget);
    expect(find.text('Go Back'), findsOneWidget);
    expect(find.text('Unblock'), findsNothing);
    expect(find.text('Prefilled bio must stay hidden'), findsNothing);
    expect(find.text('Hidely Official'), findsNothing);
    expect(find.text('Follow'), findsNothing);
    NotificationPollingService().stopPolling();
  });

  testWidgets('CreatorProfileScreen immediately hides profile on Block and restores on Unblock', (tester) async {
    SharedPreferences.setMockInitialValues({
      'auth_token': 'valid-jwt',
      'auth_user': jsonEncode({'id': 24, 'username': 'tester', 'name': 'Tester'}),
    });
    installFakeHttp((method, uri) {
      if (uri.path.contains('/api/users/profile/alice')) {
        return _MockResponseConfig(
          200,
          jsonEncode({
            'creator': {
              'id': 55,
              'username': 'alice',
              'name': 'Alice Nomad',
              'bio': 'Mountain hiker',
              'followers_count': 10,
              'followings_count': 5,
              'posts_count': 0,
              'is_following': false,
            },
            'posts': [],
          }),
        );
      }
      if (uri.path.contains('/api/posts/user/')) {
        return const _MockResponseConfig(200, '{"posts":[]}');
      }
      if (uri.path.contains('/api/users/block/alice')) {
        return _MockResponseConfig(200, '{"message":"ok","blocked":${method == 'POST'}}');
      }
      return const _MockResponseConfig(200, '{}');
    });

    await AuthService().init();

    await tester.pumpWidget(
      const MaterialApp(
        home: CreatorProfileScreen(username: 'alice'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Alice Nomad'), findsOneWidget);
    expect(find.text('Mountain hiker'), findsOneWidget);
    expect(find.text('Follow'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Block'));
    await tester.pumpAndSettle();

    expect(find.text('You blocked @alice'), findsOneWidget);
    expect(find.text('Alice Nomad'), findsNothing);
    expect(find.text('Mountain hiker'), findsNothing);
    expect(find.text('Follow'), findsNothing);
    expect(AuthService().isUserBlockedSync('alice'), isTrue);

    await tester.tap(find.text('Unblock'));
    await tester.pumpAndSettle();

    expect(find.text('Alice Nomad'), findsOneWidget);
    expect(find.text('Mountain hiker'), findsOneWidget);
    expect(find.text('You blocked @alice'), findsNothing);
    expect(AuthService().isUserBlockedSync('alice'), isFalse);

    NotificationPollingService().stopPolling();
  });
}


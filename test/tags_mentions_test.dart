import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidely_new/screens/feed_screen.dart';
import 'package:hidely_new/screens/post_details_screen.dart';
import 'package:hidely_new/screens/settings_and_privacy_screen.dart';
import 'package:hidely_new/screens/tags_and_mentions_screen.dart';
import 'package:hidely_new/services/api_service.dart';
import 'package:hidely_new/services/auth_service.dart';
import 'package:hidely_new/services/notification_polling_service.dart';
import 'package:hidely_new/widgets/mention_text.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockResponseConfig {
  final int statusCode;
  final String body;
  const _MockResponseConfig(this.statusCode, this.body);
}

typedef _Responder = _MockResponseConfig Function(
  String method,
  Uri uri,
  String body,
);

class _FakeHttpOverrides extends HttpOverrides {
  final _Responder responder;
  _FakeHttpOverrides(this.responder);

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return _FakeHttpClient(responder);
  }
}

class _FakeHttpClient implements HttpClient {
  final _Responder responder;
  _FakeHttpClient(this.responder);

  @override
  bool autoUncompress = true;

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async =>
      _FakeHttpClientRequest(method, url, responder);

  @override
  Future<HttpClientRequest> getUrl(Uri url) => openUrl('GET', url);

  @override
  Future<HttpClientRequest> postUrl(Uri url) => openUrl('POST', url);

  @override
  Future<HttpClientRequest> putUrl(Uri url) => openUrl('PUT', url);

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
  @override
  final String method;
  @override
  final Uri uri;
  final _Responder responder;
  final List<int> _bodyBytes = <int>[];

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

  _FakeHttpClientRequest(this.method, this.uri, this.responder);

  @override
  void add(List<int> data) {
    _bodyBytes.addAll(data);
  }

  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    await for (final chunk in stream) {
      _bodyBytes.addAll(chunk);
    }
  }

  @override
  void write(Object? object) {
    _bodyBytes.addAll(encoding.encode(object?.toString() ?? ''));
  }

  @override
  Future<HttpClientResponse> close() async {
    final bodyStr = _bodyBytes.isEmpty ? '' : utf8.decode(_bodyBytes, allowMalformed: true);
    final cfg = responder(method, uri, bodyStr);
    return _FakeHttpClientResponse(cfg.statusCode, cfg.body);
  }

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
      final args = call.arguments is Map
          ? Map<String, dynamic>.from(call.arguments as Map)
          : const <String, dynamic>{};
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
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await AuthService().logout();
    NotificationPollingService().stopPolling();
  });

  tearDown(() async {
    HttpOverrides.global = null;
    ApiService().resetClientForTest();
    NotificationPollingService().stopPolling();
  });

  void installFakeHttp(_Responder responder) {
    HttpOverrides.global = _FakeHttpOverrides(responder);
    ApiService().resetClientForTest();
  }

  test('AuthService persists and syncs Tags & Mentions privacy settings', () async {
    String serverAllowTags = 'everyone';
    String serverAllowMentions = 'everyone';
    bool serverManual = false;
    final List<String> httpCalls = <String>[];

    installFakeHttp((method, uri, body) {
      httpCalls.add('$method ${uri.path}');
      if (uri.path == '/api/users/privacy/tags-mentions') {
        if (method == 'PUT') {
          final parsed = jsonDecode(body) as Map<String, dynamic>;
          serverAllowTags = parsed['allow_tags_from'] ?? serverAllowTags;
          serverAllowMentions = parsed['allow_mentions_from'] ?? serverAllowMentions;
          if (parsed.containsKey('manually_approve_tags')) {
            serverManual = parsed['manually_approve_tags'] == true;
          }
        }
        return _MockResponseConfig(
          200,
          jsonEncode({
            'success': true,
            'settings': {
              'allow_tags_from': serverAllowTags,
              'allow_mentions_from': serverAllowMentions,
              'manually_approve_tags': serverManual,
            },
          }),
        );
      }
      return const _MockResponseConfig(200, '{}');
    });

    await AuthService().login('tok-1', {
      'id': 11,
      'name': 'Harsh',
      'username': 'harsh',
      'email': 'harsh@example.com',
    });
    NotificationPollingService().stopPolling();

    expect(AuthService().allowTagsFrom, 'everyone');
    expect(AuthService().allowMentionsFrom, 'everyone');
    expect(AuthService().manuallyApproveTags, isFalse);

    final updateRes = await AuthService().updateTagMentionSettings(
      allowTagsFrom: 'following',
      allowMentionsFrom: 'no_one',
      manuallyApproveTags: true,
    );

    expect(updateRes.success, isTrue);
    expect(updateRes.data?['synced'], isTrue);
    expect(AuthService().allowTagsFrom, 'following');
    expect(AuthService().allowMentionsFrom, 'no_one');
    expect(AuthService().manuallyApproveTags, isTrue);
    expect(
      AuthService().tagMentionSummaryText,
      'Tags: People you follow · Mentions: No one',
    );
    expect(httpCalls, contains('PUT /api/users/privacy/tags-mentions'));

    // Re-init from storage should preserve saved preferences before server sync
    await AuthService().init();
    NotificationPollingService().stopPolling();
    expect(AuthService().allowTagsFrom, 'following');
    expect(AuthService().allowMentionsFrom, 'no_one');
    expect(AuthService().manuallyApproveTags, isTrue);
  });

  testWidgets('TagsAndMentionsScreen updates settings and approves/removes tags', (tester) async {
    String allowTags = 'everyone';
    String allowMentions = 'everyone';
    bool manualApprove = false;
    final List<Map<String, dynamic>> serverTaggedPosts = <Map<String, dynamic>>[
      {
        'tag_id': 1,
        'post_id': 42,
        'tag_status': 'pending',
        'caption': 'Sunset hike with @harsh',
        'image_url': '',
        'author_username': 'elena_explorer',
        'author_name': 'Elena Explorer',
        'author_profile_picture': '',
      },
    ];
    final List<String> actionsSent = <String>[];

    installFakeHttp((method, uri, body) {
      if (uri.path == '/api/users/privacy/tags-mentions') {
        if (method == 'PUT') {
          final parsed = jsonDecode(body) as Map<String, dynamic>;
          allowTags = parsed['allow_tags_from'] ?? allowTags;
          allowMentions = parsed['allow_mentions_from'] ?? allowMentions;
          if (parsed.containsKey('manually_approve_tags')) {
            manualApprove = parsed['manually_approve_tags'] == true;
          }
        }
        return _MockResponseConfig(
          200,
          jsonEncode({
            'success': true,
            'settings': {
              'allow_tags_from': allowTags,
              'allow_mentions_from': allowMentions,
              'manually_approve_tags': manualApprove,
            },
          }),
        );
      }
      if (uri.path == '/api/users/tags' && method == 'GET') {
        return _MockResponseConfig(
          200,
          jsonEncode({'success': true, 'tags': serverTaggedPosts}),
        );
      }
      if (uri.path == '/api/users/tags/42' && method == 'PATCH') {
        final parsed = jsonDecode(body) as Map<String, dynamic>;
        final action = parsed['action']?.toString() ?? '';
        actionsSent.add(action);
        if (action == 'approve') {
          serverTaggedPosts[0]['tag_status'] = 'approved';
        } else if (action == 'remove') {
          serverTaggedPosts.clear();
        }
        return _MockResponseConfig(
          200,
          jsonEncode({'success': true, 'status': action == 'approve' ? 'approved' : 'removed'}),
        );
      }
      return const _MockResponseConfig(200, '{}');
    });

    await AuthService().login('tok-2', {
      'id': 11,
      'name': 'Harsh',
      'username': 'harsh',
      'email': 'harsh@example.com',
    });
    NotificationPollingService().stopPolling();

    await tester.pumpWidget(
      const MaterialApp(home: TagsAndMentionsScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tags & Mentions'), findsOneWidget);
    expect(find.text('Allow tags from'), findsOneWidget);
    expect(find.text('Allow @mentions from'), findsOneWidget);
    expect(find.text('Manually approve tags'), findsOneWidget);
    expect(find.text('@elena_explorer'), findsOneWidget);
    expect(find.text('Pending'), findsOneWidget);

    // Change "Allow tags from" -> "People you follow" (first occurrence belongs to Allow tags from card)
    await tester.tap(find.text('People you follow').first);
    await tester.pumpAndSettle();
    expect(allowTags, 'following');
    expect(AuthService().allowTagsFrom, 'following');

    // Toggle Manually approve tags switch
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    expect(manualApprove, isTrue);

    // Dismiss floating SnackBar so it doesn't obscure bottom actions
    ScaffoldMessenger.of(tester.element(find.byType(Scaffold))).clearSnackBars();
    await tester.pumpAndSettle();

    // Approve pending tag
    final approveBtn = find.text('Approve');
    await tester.ensureVisible(approveBtn);
    await tester.pumpAndSettle();
    await tester.tap(approveBtn);
    await tester.pumpAndSettle();
    expect(actionsSent, contains('approve'));
    expect(find.text('Approved'), findsOneWidget);

    ScaffoldMessenger.of(tester.element(find.byType(Scaffold))).clearSnackBars();
    await tester.pumpAndSettle();

    // Remove tag
    final removeBtn = find.text('Remove Tag');
    await tester.ensureVisible(removeBtn);
    await tester.pumpAndSettle();
    await tester.tap(removeBtn);
    await tester.pumpAndSettle();
    expect(actionsSent, contains('remove'));
    expect(find.text('No tagged posts yet'), findsOneWidget);
  });

  testWidgets('SettingsAndPrivacyScreen shows live summary and opens TagsAndMentionsScreen', (tester) async {
    installFakeHttp((method, uri, body) {
      if (uri.path == '/api/users/privacy/tags-mentions') {
        return _MockResponseConfig(
          200,
          jsonEncode({
            'success': true,
            'settings': {
              'allow_tags_from': 'following',
              'allow_mentions_from': 'no_one',
              'manually_approve_tags': true,
            },
          }),
        );
      }
      if (uri.path == '/api/users/tags') {
        return const _MockResponseConfig(200, '{"success":true,"tags":[]}');
      }
      return const _MockResponseConfig(200, '{}');
    });

    await AuthService().login('tok-3', {
      'id': 11,
      'name': 'Harsh',
      'username': 'harsh',
      'email': 'harsh@example.com',
    });
    NotificationPollingService().stopPolling();

    await tester.pumpWidget(
      const MaterialApp(home: SettingsAndPrivacyScreen()),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Tags and Mentions'),
      250.0,
      scrollable: find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tags and Mentions'), findsOneWidget);
    expect(
      find.text('Tags: People you follow · Mentions: No one'),
      findsOneWidget,
    );

    await tester.ensureVisible(find.text('Tags and Mentions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tags and Mentions'));
    await tester.pumpAndSettle();

    expect(find.byType(TagsAndMentionsScreen), findsOneWidget);
  });

  testWidgets('TagPeopleSheet prevents tagging restricted users and allows eligible users', (tester) async {
    List<String> selectedOutput = <String>[];

    installFakeHttp((method, uri, body) {
      if (uri.path == '/api/gamification/leaderboard') {
        return _MockResponseConfig(
          200,
          jsonEncode({
            'success': true,
            'leaderboard': [
              {
                'id': 2,
                'name': 'Alice',
                'username': 'alice',
                'allow_tags_from': 'everyone',
                'can_be_tagged': true,
              },
              {
                'id': 3,
                'name': 'Bob',
                'username': 'bob',
                'allow_tags_from': 'no_one',
                'can_be_tagged': false,
              },
            ],
          }),
        );
      }
      return const _MockResponseConfig(200, '{}');
    });

    await AuthService().login('tok-4', {
      'id': 1,
      'name': 'Harsh',
      'username': 'harsh',
      'email': 'harsh@example.com',
    });
    NotificationPollingService().stopPolling();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TagPeopleSheet(
            initialSelection: const <String>[],
            onSelectionChanged: (list) => selectedOutput = List<String>.from(list),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('@alice'), findsOneWidget);
    expect(find.text('@bob · Tags turned off'), findsOneWidget);

    // Attempt to tap restricted @bob -> should NOT select @bob
    await tester.tap(find.text('Bob'));
    await tester.pump();
    expect(find.text('@bob: Tags turned off'), findsOneWidget);

    // Tap eligible @alice -> should select @alice
    await tester.tap(find.text('Alice'));
    await tester.pump();

    await tester.tap(find.text('Done'));
    await tester.pump();

    expect(selectedOutput, equals(<String>['alice']));
  });

  testWidgets('CommentSheetWidget surfaces 403 mention restriction error banner', (tester) async {
    installFakeHttp((method, uri, body) {
      if (uri.path == '/api/posts/55/comments' && method == 'GET') {
        return const _MockResponseConfig(200, '{"comments":[]}');
      }
      if (uri.path == '/api/posts/55/comment' && method == 'POST') {
        return _MockResponseConfig(
          403,
          jsonEncode({
            'error': "@bob doesn't allow @mentions from anyone.",
            'mention_restricted': true,
            'restricted_usernames': ['bob'],
          }),
        );
      }
      if (uri.path == '/api/users/search' && method == 'GET') {
        return const _MockResponseConfig(200, '{"users":[]}');
      }
      return const _MockResponseConfig(200, '{}');
    });

    await AuthService().login('tok-5', {
      'id': 1,
      'name': 'Harsh',
      'username': 'harsh',
      'email': 'harsh@example.com',
    });
    NotificationPollingService().stopPolling();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CommentSheetWidget(postId: 55),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Hey @bob check this');
    // Allow debounce timer to settle cleanly
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Post'));
    await tester.pumpAndSettle();

    expect(
      find.text("@bob doesn't allow @mentions from anyone."),
      findsOneWidget,
    );
  });

  testWidgets('MentionText invokes onMentionTap only for real @mentions', (tester) async {
    final List<String> tapped = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MentionText(
            text: 'Check out @alice or email user@example.com!',
            onMentionTap: tapped.add,
          ),
        ),
      ),
    );

    final richText = tester.widget<RichText>(find.byType(RichText));
    final rootSpan = richText.text as TextSpan;
    final TextSpan contentSpan =
        (rootSpan.children != null &&
                rootSpan.children!.length == 1 &&
                rootSpan.children!.first is TextSpan)
            ? rootSpan.children!.first as TextSpan
            : rootSpan;
    expect(contentSpan.children, hasLength(3)); // 'Check out ', '@alice', ' or email user@example.com!'
    final mentionSpan = contentSpan.children![1] as TextSpan;
    expect(mentionSpan.text, '@alice');
    expect(mentionSpan.recognizer, isNotNull);

    await tester.tapOnText(find.textRange.ofSubstring('@alice'));
    expect(tapped, equals(<String>['alice']));
  });
}

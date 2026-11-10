import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidely_new/screens/creator_profile_screen.dart';
import 'package:hidely_new/screens/group_chat_screen.dart';
import 'package:hidely_new/services/api_service.dart';
import 'package:hidely_new/services/auth_service.dart';
import 'package:hidely_new/services/chat_socket_service.dart';
import 'package:hidely_new/services/notification_polling_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
        default:
          return null;
      }
    });

    messenger.setMockMethodCallHandler(localNotifChannel, (call) async {
      if (call.method == 'getNotificationAppLaunchDetails') {
        return <String, dynamic>{'notificationLaunchedApp': false};
      }
      return true;
    });
  });

  setUp(() async {
    fakeSecureStore.clear();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    ChatSocketService().skipSocketConnectForTest = true;
    NotificationPollingService().stopPolling();
    GroupChatScreen.clearSessionCache();

    await AuthService().login(
      'jwt_chat_tester',
      <String, dynamic>{
        'id': 10,
        'name': 'Real Harsh',
        'username': 'realharsh',
        'email': 'realharsh@example.com',
        'profile_picture': '',
      },
    );
  });

  tearDown(() async {
    GroupChatScreen.clearSessionCache();
    NotificationPollingService().stopPolling();
    ApiService().resetClientForTest();
  });

  group('Chat deduplication, vertical centering & full chat workflows', () {
    testWidgets(
      'deduplicates multiple DIRECT conversations from same profile and skips orphaned rows',
      (WidgetTester tester) async {
        ApiService().resetClientForTest(
          MockClient((request) async {
            if (request.url.path == '/api/chat/conversations') {
              return http.Response(
                jsonEncode({
                  'success': true,
                  'conversations': [
                    // Empty duplicate DIRECT row for user 42
                    {
                      'id': 105,
                      'type': 'DIRECT',
                      'name': null,
                      'updated_at': '2026-11-10T10:00:00.000Z',
                      'unread_count': 1,
                      'last_message': null,
                      'participants': [
                        {
                          'id': 42,
                          'name': 'Harsh bhardwaj',
                          'username': 'dancerharsh',
                          'profile_picture': null,
                          'is_online': true,
                        },
                      ],
                    },
                    // Active DIRECT row for the EXACT same peer user 42
                    {
                      'id': 77,
                      'type': 'DIRECT',
                      'name': null,
                      'updated_at': '2026-11-10T05:04:00.000Z',
                      'unread_count': 1,
                      'last_message': {
                        'id': 501,
                        'text': 'hi',
                        'type': 'text',
                        'sender_id': 42,
                        'created_at': '2026-11-10T05:04:00.000Z',
                      },
                      'participants': [
                        {
                          'id': 42,
                          'name': 'Harsh bhardwaj',
                          'username': 'dancerharsh',
                          'profile_picture': null,
                          'is_online': true,
                        },
                      ],
                    },
                    // Orphaned DIRECT row with no peer user
                    {
                      'id': 109,
                      'type': 'DIRECT',
                      'name': null,
                      'updated_at': '2026-11-10T04:00:00.000Z',
                      'unread_count': 0,
                      'last_message': null,
                      'participants': [],
                    },
                    // Another separate friend
                    {
                      'id': 88,
                      'type': 'DIRECT',
                      'name': null,
                      'updated_at': '2026-11-10T09:09:00.000Z',
                      'unread_count': 0,
                      'last_message': {
                        'id': 499,
                        'text': 'hi',
                        'type': 'text',
                        'sender_id': 55,
                        'created_at': '2026-11-10T09:09:00.000Z',
                      },
                      'participants': [
                        {
                          'id': 55,
                          'name': 'Vandhan Bhardwaj',
                          'username': 'vandhan',
                          'profile_picture': null,
                          'is_online': false,
                        },
                      ],
                    },
                  ],
                }),
                200,
              );
            }
            return http.Response(jsonEncode({'success': true}), 200);
          }),
        );

        await tester.pumpWidget(
          const MaterialApp(
            home: GroupChatScreen(),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Harsh bhardwaj'), findsOneWidget);
        expect(find.text('dancerharsh'), findsNothing);
        expect(find.text('Vandhan Bhardwaj'), findsOneWidget);
        expect(find.text('No messages yet'), findsNothing);
      },
    );

    testWidgets(
      'CreatorProfileScreen Message button resolves numeric conversationId and never creates a dm_ duplicate row',
      (WidgetTester tester) async {
        bool postDirectCalled = false;
        int? requestedTargetUserId;

        ApiService().resetClientForTest(
          MockClient((request) async {
            if (request.url.path == '/api/chat/conversations') {
              return http.Response(
                jsonEncode({
                  'success': true,
                  'conversations': [
                    {
                      'id': 77,
                      'type': 'DIRECT',
                      'name': null,
                      'updated_at': '2026-11-10T05:04:00.000Z',
                      'unread_count': 0,
                      'last_message': {
                        'id': 501,
                        'text': 'hi',
                        'type': 'text',
                        'sender_id': 42,
                        'created_at': '2026-11-10T05:04:00.000Z',
                      },
                      'participants': [
                        {
                          'id': 42,
                          'name': 'Harsh bhardwaj',
                          'username': 'dancerharsh',
                          'profile_picture': null,
                          'is_online': true,
                        },
                      ],
                    },
                  ],
                }),
                200,
              );
            }
            if (request.url.path == '/api/users/profile/dancerharsh') {
              return http.Response(
                jsonEncode({
                  'success': true,
                  'creator': {
                    'id': 42,
                    'name': 'Harsh bhardwaj',
                    'username': 'dancerharsh',
                    'profile_picture': null,
                    'followers_count': 12,
                    'followings_count': 5,
                    'posts_count': 0,
                    'is_following': false,
                  },
                  'posts': [],
                }),
                200,
              );
            }
            if (request.url.path == '/api/posts/user/42') {
              return http.Response(jsonEncode({'success': true, 'posts': []}), 200);
            }
            if (request.url.path == '/api/chat/direct' && request.method == 'POST') {
              postDirectCalled = true;
              final body = jsonDecode(request.body) as Map<String, dynamic>;
              requestedTargetUserId = int.tryParse('${body['targetUserId']}');
              return http.Response(
                jsonEncode({'success': true, 'conversationId': 77, 'isNew': false}),
                200,
              );
            }
            if (request.url.path == '/api/chat/conversations/77/messages') {
              return http.Response(
                jsonEncode({
                  'success': true,
                  'messages': [
                    {
                      'id': 501,
                      'conversation_id': 77,
                      'sender_id': 42,
                      'sender_name': 'Harsh bhardwaj',
                      'sender_profile_picture': null,
                      'type': 'text',
                      'text': 'hi',
                      'created_at': '2026-11-10T05:04:00.000Z',
                      'attachments': null,
                      'reactions': null,
                      'reply_to_message': null,
                    },
                  ],
                }),
                200,
              );
            }
            if (request.url.path == '/api/chat/conversations/77/read') {
              return http.Response(jsonEncode({'success': true}), 200);
            }
            return http.Response(jsonEncode({'success': true}), 200);
          }),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Stack(
                  children: [
                    const GroupChatScreen(),
                    Positioned(
                      bottom: 16,
                      right: 16,
                      child: ElevatedButton(
                        key: const Key('open_profile_btn'),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const CreatorProfileScreen(
                                username: 'dancerharsh',
                              ),
                            ),
                          );
                        },
                        child: const Text('Open Profile'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('open_profile_btn')));
        await tester.pumpAndSettle();

        expect(find.text('Message'), findsOneWidget);
        await tester.tap(find.text('Message'));
        await tester.pumpAndSettle();

        expect(postDirectCalled, isTrue);
        expect(requestedTargetUserId, equals(42));
        expect(find.byKey(const Key('chat_message_input')), findsOneWidget);
        expect(find.text('hi'), findsOneWidget);

        // Navigate back to inbox and ensure NO second row was added
        await tester.tap(find.byKey(const Key('chat_room_back_btn')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('chat_message_input')), findsNothing);
        expect(find.text('Harsh bhardwaj'), findsOneWidget);
        expect(find.textContaining('Tap to send a secure private message'), findsNothing);
      },
    );

    testWidgets(
      'chat search and composer inputs are vertically centered geometrically',
      (WidgetTester tester) async {
        ApiService().resetClientForTest(
          MockClient((request) async {
            if (request.url.path == '/api/chat/conversations') {
              return http.Response(
                jsonEncode({
                  'success': true,
                  'conversations': [
                    {
                      'id': 77,
                      'type': 'DIRECT',
                      'name': null,
                      'updated_at': '2026-11-10T05:04:00.000Z',
                      'unread_count': 0,
                      'last_message': {
                        'id': 501,
                        'text': 'hi',
                        'type': 'text',
                        'sender_id': 42,
                        'created_at': '2026-11-10T05:04:00.000Z',
                      },
                      'participants': [
                        {
                          'id': 42,
                          'name': 'Harsh bhardwaj',
                          'username': 'dancerharsh',
                          'profile_picture': null,
                          'is_online': true,
                        },
                      ],
                    },
                  ],
                }),
                200,
              );
            }
            if (request.url.path == '/api/chat/conversations/77/messages') {
              return http.Response(jsonEncode({'success': true, 'messages': []}), 200);
            }
            return http.Response(jsonEncode({'success': true}), 200);
          }),
        );

        await tester.pumpWidget(const MaterialApp(home: GroupChatScreen()));
        await tester.pumpAndSettle();

        // 1. Inbox search bar alignment
        final searchPillRect = tester.getRect(find.byKey(const Key('chat_search_pill')));
        final searchEditableRect = tester.getRect(
          find.descendant(
            of: find.byKey(const Key('chat_search_input')),
            matching: find.byType(EditableText),
          ),
        );
        expect((searchEditableRect.center.dy - searchPillRect.center.dy).abs(), lessThanOrEqualTo(2.5));

        // 2. New Message modal search bar alignment
        await tester.tap(find.byTooltip('New Message / Squad'));
        await tester.pumpAndSettle();
        final newMsgPillRect = tester.getRect(find.byKey(const Key('chat_new_msg_search_pill')));
        final newMsgEditableRect = tester.getRect(
          find.descendant(
            of: find.byKey(const Key('chat_new_msg_search_input')),
            matching: find.byType(EditableText),
          ),
        );
        expect((newMsgEditableRect.center.dy - newMsgPillRect.center.dy).abs(), lessThanOrEqualTo(2.5));
        await tester.tap(find.byIcon(Icons.close_rounded));
        await tester.pumpAndSettle();

        // 3. Chat room composer alignment (empty + with typed text)
        await tester.tap(find.text('Harsh bhardwaj'));
        await tester.pumpAndSettle();

        final composerPillEmptyRect = tester.getRect(find.byKey(const Key('chat_composer_pill')));
        final composerEditableEmptyRect = tester.getRect(
          find.descendant(
            of: find.byKey(const Key('chat_message_input')),
            matching: find.byType(EditableText),
          ),
        );
        expect(
          (composerEditableEmptyRect.center.dy - composerPillEmptyRect.center.dy).abs(),
          lessThanOrEqualTo(2.5),
        );

        await tester.enterText(find.byKey(const Key('chat_message_input')), 'Hello Harsh!');
        await tester.pump();

        final composerPillTypedRect = tester.getRect(find.byKey(const Key('chat_composer_pill')));
        final composerEditableTypedRect = tester.getRect(
          find.descendant(
            of: find.byKey(const Key('chat_message_input')),
            matching: find.byType(EditableText),
          ),
        );
        expect(
          (composerEditableTypedRect.center.dy - composerPillTypedRect.center.dy).abs(),
          lessThanOrEqualTo(2.5),
        );
      },
    );

    testWidgets(
      'socket deduplication, send message, reply quote, typing indicator, reaction persistence and logout cleanup',
      (WidgetTester tester) async {
        final List<String> sentPayloads = <String>[];
        bool reactionCalled = false;
        int markReadCalls = 0;

        ApiService().resetClientForTest(
          MockClient((request) async {
            if (request.url.path == '/api/chat/conversations') {
              return http.Response(
                jsonEncode({
                  'success': true,
                  'conversations': [
                    {
                      'id': 77,
                      'type': 'DIRECT',
                      'name': null,
                      'updated_at': '2026-11-10T05:04:00.000Z',
                      'unread_count': 0,
                      'last_message': {
                        'id': 501,
                        'text': 'hi',
                        'type': 'text',
                        'sender_id': 42,
                        'created_at': '2026-11-10T05:04:00.000Z',
                      },
                      'participants': [
                        {
                          'id': 42,
                          'name': 'Harsh bhardwaj',
                          'username': 'dancerharsh',
                          'profile_picture': null,
                          'is_online': true,
                        },
                      ],
                    },
                  ],
                }),
                200,
              );
            }
            if (request.url.path == '/api/chat/conversations/77/messages' && request.method == 'GET') {
              return http.Response(
                jsonEncode({
                  'success': true,
                  'messages': [
                    {
                      'id': 501,
                      'conversation_id': 77,
                      'sender_id': 42,
                      'sender_name': 'Harsh bhardwaj',
                      'sender_profile_picture': null,
                      'type': 'text',
                      'text': 'First peer msg',
                      'created_at': '2026-11-10T05:04:00.000Z',
                      'attachments': null,
                      'reactions': null,
                      'reply_to_message': null,
                    },
                  ],
                }),
                200,
              );
            }
            if (request.url.path == '/api/chat/conversations/77/messages' && request.method == 'POST') {
              sentPayloads.add(request.body);
              final nextId = 700 + sentPayloads.length;
              return http.Response(
                jsonEncode({
                  'success': true,
                  'message': {
                    'id': nextId,
                    'conversation_id': 77,
                    'sender_id': 10,
                    'text': 'ok',
                    'type': 'text',
                  },
                }),
                201,
              );
            }
            if (request.url.path == '/api/chat/messages/501/reactions' && request.method == 'POST') {
              reactionCalled = true;
              return http.Response(jsonEncode({'success': true, 'active': true}), 200);
            }
            if (request.url.path == '/api/chat/conversations/77/read') {
              markReadCalls += 1;
              return http.Response(jsonEncode({'success': true}), 200);
            }
            return http.Response(jsonEncode({'success': true}), 200);
          }),
        );

        await tester.pumpWidget(const MaterialApp(home: GroupChatScreen()));
        await tester.pumpAndSettle();

        // Open conversation 77 once, then go back to verify future unread still works
        await tester.tap(find.text('Harsh bhardwaj'));
        await tester.pumpAndSettle();
        expect(find.text('First peer msg'), findsOneWidget);

        // Double tap message -> toggles ❤️ and calls backend reaction endpoint
        await tester.tap(find.text('First peer msg'));
        await tester.pump(const Duration(milliseconds: 50));
        await tester.tap(find.text('First peer msg'));
        await tester.pumpAndSettle();
        expect(reactionCalled, isTrue);
        expect(find.text('❤️'), findsOneWidget);

        // Receive typing indicator from peer 42
        ChatSocketService().emitTypingStatusForTest({
          'conversationId': 77,
          'userId': 42,
          'isTyping': true,
        });
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.text('typing... 💬'), findsOneWidget);

        // Emit duplicate Socket.IO new_message with the exact same ID twice
        final dupSocketPayload = {
          'id': 902,
          'conversation_id': 77,
          'sender_id': 42,
          'sender_name': 'Harsh bhardwaj',
          'sender_profile_picture': null,
          'type': 'text',
          'text': 'Socket message once',
          'created_at': '2026-11-10T11:00:00.000Z',
        };
        ChatSocketService().emitNewMessageForTest(dupSocketPayload);
        ChatSocketService().emitNewMessageForTest(dupSocketPayload);
        await tester.pumpAndSettle();

        expect(find.text('Socket message once'), findsOneWidget);
        expect(find.text('typing... 💬'), findsNothing);
        expect(markReadCalls, greaterThanOrEqualTo(2));

        // Long press message -> Reply to Message -> Send reply
        await tester.longPress(find.text('Socket message once'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Reply to Message'));
        await tester.pumpAndSettle();
        expect(find.text('Replying to Harsh bhardwaj'), findsOneWidget);

        await tester.enterText(find.byKey(const Key('chat_message_input')), 'On my way!');
        await tester.pump();
        await tester.tap(find.byKey(const Key('chat_send_button')));
        await tester.pumpAndSettle();

        expect(find.text('On my way!'), findsOneWidget);
        expect(sentPayloads.length, equals(1));
        expect(sentPayloads.first, contains('On my way!'));
        expect(sentPayloads.first, contains('902'));

        // Go back to inbox -> emit another peer message -> verify unread badge recovers cleanly
        await tester.tap(find.byKey(const Key('chat_room_back_btn')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('chat_unread_dot_77')), findsNothing);

        ChatSocketService().emitNewMessageForTest({
          'id': 903,
          'conversation_id': 77,
          'sender_id': 42,
          'sender_name': 'Harsh bhardwaj',
          'sender_profile_picture': null,
          'type': 'text',
          'text': 'New unread ping',
          'created_at': '2026-11-10T11:05:00.000Z',
        });
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.byKey(const Key('chat_unread_dot_77')), findsOneWidget);

        // Account logout resets chat state cleanly
        await AuthService().logout();
        await tester.pumpAndSettle();
        expect(GroupChatScreen.isChatRoomOpen.value, isFalse);
      },
    );

    testWidgets(
      'search travelers, filter categories, send error snackbar & account switch session reset work cleanly',
      (WidgetTester tester) async {
        ApiService().resetClientForTest(
          MockClient((request) async {
            if (request.url.path == '/api/chat/conversations') {
              return http.Response(
                jsonEncode({
                  'success': true,
                  'conversations': [
                    {
                      'id': 77,
                      'type': 'DIRECT',
                      'name': null,
                      'updated_at': '2026-11-10T05:04:00.000Z',
                      'unread_count': 0,
                      'last_message': {
                        'id': 501,
                        'text': 'hi',
                        'type': 'text',
                        'sender_id': 42,
                        'created_at': '2026-11-10T05:04:00.000Z',
                      },
                      'participants': [
                        {
                          'id': 42,
                          'name': 'Harsh bhardwaj',
                          'username': 'dancerharsh',
                          'profile_picture': null,
                          'is_online': false,
                        },
                      ],
                    },
                    {
                      'id': 200,
                      'type': 'GROUP',
                      'name': 'Manali Squad',
                      'updated_at': '2026-11-10T06:00:00.000Z',
                      'unread_count': 0,
                      'last_message': {
                        'id': 601,
                        'text': 'Packing done',
                        'type': 'text',
                        'sender_id': 42,
                        'created_at': '2026-11-10T06:00:00.000Z',
                      },
                      'participants': [
                        {
                          'id': 42,
                          'name': 'Harsh bhardwaj',
                          'username': 'dancerharsh',
                          'profile_picture': null,
                          'is_online': false,
                        },
                      ],
                    },
                  ],
                }),
                200,
              );
            }
            if (request.url.path == '/api/users/search') {
              return http.Response(
                jsonEncode({
                  'success': true,
                  'users': [
                    {'id': 10, 'name': 'Real Harsh', 'username': 'realharsh', 'profile_picture': null},
                    {'id': 42, 'name': 'Harsh bhardwaj', 'username': 'dancerharsh', 'profile_picture': null},
                    {'id': 99, 'name': 'Aarav Explorer', 'username': 'aarav_trails', 'profile_picture': null},
                  ],
                }),
                200,
              );
            }
            if (request.url.path == '/api/chat/direct' && request.method == 'POST') {
              return http.Response(
                jsonEncode({'success': true, 'conversationId': 333, 'isNew': true}),
                201,
              );
            }
            if (request.url.path == '/api/chat/conversations/333/messages' && request.method == 'GET') {
              return http.Response(jsonEncode({'success': true, 'messages': []}), 200);
            }
            if (request.url.path == '/api/chat/conversations/333/messages' && request.method == 'POST') {
              return http.Response(
                jsonEncode({'error': 'Messaging is unavailable for this conversation.'}),
                403,
              );
            }
            return http.Response(jsonEncode({'success': true}), 200);
          }),
        );

        await tester.pumpWidget(const MaterialApp(home: GroupChatScreen()));
        await tester.pumpAndSettle();

        expect(find.text('Harsh bhardwaj'), findsOneWidget);
        expect(find.text('Manali Squad'), findsOneWidget);

        // Filter to Groups -> only Manali Squad remains visible
        await tester.tap(find.byTooltip('Filter Messages'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Groups'));
        await tester.tap(find.text('Apply Filters'));
        await tester.pumpAndSettle();
        expect(find.text('Manali Squad'), findsOneWidget);
        expect(find.text('Harsh bhardwaj'), findsNothing);

        // Reset back to All
        await tester.tap(find.byTooltip('Filter Messages'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Reset'));
        await tester.tap(find.text('Apply Filters'));
        await tester.pumpAndSettle();

        // Search travelers: should exclude self (10) and existing DM (42), show Aarav Explorer (99)
        await tester.enterText(find.byKey(const Key('chat_search_input')), 'aar');
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpAndSettle();

        expect(find.text('Aarav Explorer'), findsOneWidget);
        expect(find.text('@aarav_trails'), findsOneWidget);

        // Start chat with Aarav -> returns HTTP 201 conversationId 333
        await tester.tap(find.text('Aarav Explorer'));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('chat_message_input')), findsOneWidget);

        // Send blocked message -> surfaces SnackBar error
        await tester.enterText(find.byKey(const Key('chat_message_input')), 'Hi Aarav');
        await tester.pump();
        await tester.tap(find.byKey(const Key('chat_send_button')));
        await tester.pumpAndSettle();
        expect(find.text('Messaging is unavailable for this conversation.'), findsOneWidget);

        // Return to inbox -> confirm Aarav appears only ONCE
        await tester.tap(find.byKey(const Key('chat_room_back_btn')));
        await tester.pumpAndSettle();
        expect(find.text('Aarav Explorer'), findsOneWidget);

        // Account switch clears previous account chats cleanly
        await AuthService().login(
          'jwt_other_user',
          <String, dynamic>{
            'id': 777,
            'name': 'Second User',
            'username': 'second_user',
            'email': 'second@example.com',
          },
        );
        NotificationPollingService().stopPolling();
        await tester.pumpAndSettle();
        expect(find.text('second_user'), findsOneWidget);
      },
    );
  });
}

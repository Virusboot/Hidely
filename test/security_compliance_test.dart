import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hidely_new/config/app_env.dart';
import 'package:hidely_new/config/call_config.dart';
import 'package:hidely_new/screens/create_account_screen.dart';
import 'package:hidely_new/screens/help_center_screen.dart';
import 'package:hidely_new/screens/hire_traveller_screen.dart';
import 'package:hidely_new/screens/points_history_screen.dart';
import 'package:hidely_new/screens/post_signup_onboarding_screen.dart';
import 'package:hidely_new/screens/privacy_policy_screen.dart';
import 'package:hidely_new/screens/terms_of_service_screen.dart';
import 'package:hidely_new/services/api_service.dart';
import 'package:hidely_new/services/auth_service.dart';
import 'package:hidely_new/services/notification_polling_service.dart';
import 'package:hidely_new/widgets/report_bottom_sheet.dart';

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
          if (k != null && v != null) {
            fakeSecureStore[k] = v;
          }
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

    messenger.setMockMethodCallHandler(localNotifChannel, (_) async => null);
  });

  setUp(() async {
    fakeSecureStore.clear();
    SharedPreferences.setMockInitialValues({});
    NotificationPollingService().stopPolling();
    await AuthService().logout();
  });

  tearDown(() {
    NotificationPollingService().stopPolling();
    ApiService().resetClientForTest();
  });

  group('API & Auth Security Compliance', () {
    test('verifyEmailOtp never accepts hardcoded bypass codes like 1234', () async {
      String? requestedPath;
      Map<String, dynamic>? sentBody;

      ApiService().resetClientForTest(MockClient((request) async {
        requestedPath = request.url.path;
        sentBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({'error': 'Invalid or expired verification code.'}),
          400,
        );
      }));

      final res = await ApiService().verifyEmailOtp(
        email: 'user@example.com',
        otp: '1234',
      );

      expect(requestedPath, '/api/auth/verify-email-otp');
      expect(sentBody?['otp'], '1234');
      expect(res.success, isFalse);
      expect(res.message, contains('Invalid'));
    });

    test('checkEmailAvailable hits /api/auth/check-availability instead of forgot-password', () async {
      final List<String> pathsCalled = [];
      ApiService().resetClientForTest(MockClient((request) async {
        pathsCalled.add(request.url.path);
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        if (body['email'] == 'taken@example.com') {
          return http.Response(
            jsonEncode({'error': 'An account already exists with this email.'}),
            400,
          );
        }
        return http.Response(jsonEncode({'available': true}), 200);
      }));

      final takenRes = await ApiService().checkEmailAvailable(email: 'taken@example.com');
      final freeRes = await ApiService().checkEmailAvailable(email: 'fresh@example.com');

      expect(pathsCalled, everyElement('/api/auth/check-availability'));
      expect(pathsCalled, isNot(contains('/api/auth/forgot-password')));
      expect(takenRes.success, isFalse);
      expect(freeRes.success, isTrue);
    });

    test('register sends explicit age_confirmed and terms_accepted flags', () async {
      Map<String, dynamic>? capturedPayload;
      ApiService().resetClientForTest(MockClient((request) async {
        if (request.url.path == '/api/auth/register') {
          capturedPayload = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'token': 'jwt.token.value',
              'user': {'id': 10, 'username': 'explorer'},
            }),
            201,
          );
        }
        return http.Response('{}', 404);
      }));

      final res = await ApiService().register(
        name: 'Asha Explorer',
        username: 'asha_exp',
        email: 'asha@example.com',
        password: 'Strong@Password1',
        ageConfirmed: true,
        termsAccepted: true,
      );

      expect(res.success, isTrue);
      expect(capturedPayload?['age_confirmed'], isTrue);
      expect(capturedPayload?['terms_accepted'], isTrue);
    });

    test('AuthService.deleteAccount requires password, calls backend, and purges local state', () async {
      await AuthService().login('secret-jwt-1', {
        'id': 55,
        'username': 'harsh',
        'email': 'harsh@example.com',
      });
      await AuthService().blockUser('badactor');

      ApiService().resetClientForTest(MockClient((request) async {
        if (request.url.path == '/api/users/account' && request.method == 'DELETE') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          if (body['password'] != 'Correct@123') {
            return http.Response(
              jsonEncode({'error': 'Incorrect current password.'}),
              401,
            );
          }
          return http.Response(
            jsonEncode({'message': 'Account permanently deleted.'}),
            200,
          );
        }
        return http.Response('{}', 200);
      }));

      final badRes = await AuthService().deleteAccount(password: 'Wrong@123');
      expect(badRes.success, isFalse);
      expect(AuthService().isLoggedIn, isTrue);

      final okRes = await AuthService().deleteAccount(password: 'Correct@123');
      expect(okRes.success, isTrue);
      expect(AuthService().isLoggedIn, isFalse);
      expect(AuthService().token, isNull);
      expect(AuthService().isUserBlockedSync('badactor'), isFalse);
    });

    test('exportUserData returns DPDP personal archive payload cleanly', () async {
      ApiService().resetClientForTest(MockClient((request) async {
        expect(request.url.path, '/api/users/data-export');
        expect(request.headers['Authorization'], 'Bearer tok-123');
        return http.Response(
          jsonEncode({
            'exported_at': '2026-11-12T00:00:00Z',
            'profile': {'username': 'harsh', 'email': 'harsh@example.com'},
            'counts': {'posts': 3, 'messages': 8},
          }),
          200,
        );
      }));

      final res = await ApiService().exportUserData(token: 'tok-123');
      expect(res.success, isTrue);
      expect((res.data?['profile'] as Map?)?['username'], 'harsh');
    });

    test('CallConfig & AppEnv contain zero hardcoded production API keys or AppSign', () {
      // Built without --dart-define in test environment, secrets must default empty.
      expect(CallConfig.appId, 0);
      expect(CallConfig.appSign, isEmpty);
      expect(CallConfig.isConfigured, isFalse);
      expect(AppEnv.googleMapsApiKey, isEmpty);
    });
  });

  group('UI Compliance & Moderation Workflows', () {
    testWidgets('CreateAccountScreen enforces 8-char password on Step 6 and 18+ consent checkbox on Step 7',
        (WidgetTester tester) async {
      bool registerCalled = false;
      Map<String, dynamic>? registerPayload;

      ApiService().resetClientForTest(MockClient((request) async {
        final path = request.url.path;
        if (path == '/api/auth/check-availability') {
          return http.Response(jsonEncode({'available': true}), 200);
        }
        if (path == '/api/auth/send-email-otp') {
          return http.Response(jsonEncode({'message': 'Verification code sent.'}), 200);
        }
        if (path == '/api/auth/verify-email-otp') {
          return http.Response(
            jsonEncode({'verified': true, 'message': 'Verified!'}),
            200,
          );
        }
        if (path == '/api/auth/register') {
          registerCalled = true;
          registerPayload = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'token': 'reg-jwt',
              'user': {'id': 202, 'username': 'asha_exp'},
            }),
            201,
          );
        }
        return http.Response('{}', 200);
      }));

      await tester.pumpWidget(
        const MaterialApp(
          home: CreateAccountScreen(),
        ),
      );

      // Step 1: Full Name
      await tester.enterText(find.byType(TextField).first, 'Asha Traveler');
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Step 2: Username
      expect(find.text('Create a username'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'asha_exp');
      await tester.tap(find.text('Next'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      // Step 3: Gender
      expect(find.text("What's your gender?"), findsOneWidget);
      await tester.tap(find.text('Female'));
      await tester.pump();
      await tester.tap(find.text('Next'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      // Step 4: Email
      expect(find.text("What's your email?"), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'asha@example.com');
      await tester.tap(find.text('Next'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      // Step 5: Email OTP (paste 4 digits into first box -> auto-submits)
      await tester.enterText(find.byType(TextField).first, '9876');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      // Step 6: Weak <8 char password should be blocked
      expect(find.text('Create a password'), findsOneWidget);
      final pwFields = find.byType(TextField);
      await tester.enterText(pwFields.at(0), 'Abc@12');
      await tester.enterText(pwFields.at(1), 'Abc@12');
      await tester.tap(find.text('Next'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.textContaining('at least 8 characters'), findsOneWidget);

      // Valid 8+ char password with special char proceeds to Step 7
      await tester.enterText(pwFields.at(0), 'Strong@123');
      await tester.enterText(pwFields.at(1), 'Strong@123');
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      ScaffoldMessenger.of(tester.element(find.byType(CreateAccountScreen))).clearSnackBars();
      await tester.pumpAndSettle();

      // Step 7: Review & Agree to Terms (Heading in 2 lines)
      expect(find.text("Agree to Hidely's terms\nand policies"), findsOneWidget);
      expect(find.textContaining('I confirm I am at least 18 years old'), findsOneWidget);
      await tester.ensureVisible(find.text('I agree'));
      await tester.tap(find.text('I agree'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(registerCalled, isFalse);
      expect(find.textContaining('Please confirm you are 18+ years old'), findsOneWidget);

      ScaffoldMessenger.of(tester.element(find.byType(CreateAccountScreen))).clearSnackBars();
      await tester.pumpAndSettle();

      // Checking 18+ consent enables registration with consent booleans
      await tester.ensureVisible(find.byType(CheckboxListTile));
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      await tester.ensureVisible(find.text('I agree'));
      await tester.tap(find.text('I agree'));
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();

      expect(registerCalled, isTrue);
      expect(registerPayload?['age_confirmed'], isTrue);
      expect(registerPayload?['terms_accepted'], isTrue);

      NotificationPollingService().stopPolling();
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('PostSignupOnboardingScreen uses invite sharing with no contact syncing prompt',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PostSignupOnboardingScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Step 1 -> Skip -> Step 2 (Invite friends)
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      expect(find.text('Invite friends to explore with you'), findsOneWidget);
      expect(find.textContaining('never accesses, uploads, or stores your device contacts'), findsOneWidget);
      expect(find.text('Find friends faster by syncing device contacts'), findsNothing);
      expect(find.text('Allow full access'), findsNothing);
    });

    testWidgets('ReportBottomSheet includes CSAE option and submits real /api/reports request',
        (WidgetTester tester) async {
      await AuthService().login('rep-jwt', {
        'id': 7,
        'username': 'reporter',
      });

      Map<String, dynamic>? submittedReport;
      ApiService().resetClientForTest(MockClient((request) async {
        if (request.url.path == '/api/reports' && request.method == 'POST') {
          submittedReport = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({'message': 'Report submitted successfully.', 'report_id': 99}),
            201,
          );
        }
        return http.Response('{}', 200);
      }));

      bool callbackCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => ReportBottomSheet(
                        targetType: 'Post',
                        targetId: 404,
                        targetUsername: 'spammer',
                        targetName: 'Suspicious post',
                        onSubmitSuccess: () => callbackCalled = true,
                      ),
                    );
                  },
                  child: const Text('Open Report'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Report'));
      await tester.pumpAndSettle();

      expect(find.text('Child Safety / CSAE'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Inappropriate Content'),
        120,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Inappropriate Content'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Child Safety / CSAE'),
        -120,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('Child Safety / CSAE'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Urgent safety escalation');
      await tester.tap(find.text('Submit Report'));
      await tester.pumpAndSettle();

      expect(callbackCalled, isTrue);
      expect(submittedReport?['targetType'], 'Post');
      expect(submittedReport?['targetId'], 404);
      expect(submittedReport?['targetUsername'], 'spammer');
      expect(submittedReport?['reason'], 'Child Safety / CSAE');
      expect(find.text('Report Submitted'), findsOneWidget);
      expect(find.text('Block @spammer'), findsOneWidget);

      NotificationPollingService().stopPolling();
    });

    testWidgets('HireTravellerScreen is framed honestly as Preview with zero ₹ booking fees',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HireTravellerScreen(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Local Explorers (Preview)'), findsOneWidget);
      expect(find.textContaining('Paid bookings are coming soon'), findsOneWidget);
      expect(find.text('Hire a Traveller'), findsNothing);
      expect(find.textContaining('₹'), findsNothing);
      expect(find.textContaining('Book Guide'), findsNothing);
    });

    testWidgets('PrivacyPolicy, Terms, HelpCenter & PointsHistory reflect DPDP/RBI/CSAE disclosures',
        (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: PrivacyPolicyScreen()));
      expect(find.textContaining('18 years'), findsAtLeastNWidgets(1));
      expect(find.textContaining('DPDP Act'), findsAtLeastNWidgets(1));
      expect(find.textContaining('grievance@hidely.app'), findsOneWidget);
      expect(find.textContaining('support@hidelyapp.com'), findsNothing);

      await tester.pumpWidget(const MaterialApp(home: TermsOfServiceScreen()));
      expect(find.textContaining('zero monetary, cash, wallet'), findsOneWidget);
      expect(find.textContaining('grievance@hidely.app'), findsOneWidget);

      await tester.pumpWidget(const MaterialApp(home: HelpCenterScreen()));
      expect(find.text('support@hidely.app'), findsOneWidget);
      expect(find.textContaining('grievance@hidely.app'), findsOneWidget);

      ApiService().resetClientForTest(MockClient((request) async {
        return http.Response(jsonEncode({'history': [], 'total_points': 0}), 200);
      }));
      await tester.pumpWidget(const MaterialApp(home: PointsHistoryScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('How Points Work'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('zero cash, wallet, or monetary value'),
        findsOneWidget,
      );
    });
  });

  group('Native Manifest & Network Security Config Verification', () {
    test('AndroidManifest and iOS Info.plist remove overprivileged permissions & cleartext links', () {
      final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
      expect(manifest, isNot(contains('READ_MEDIA_AUDIO')));
      expect(manifest, isNot(contains('android:scheme="http"')));
      expect(manifest, contains('android:allowBackup="false"'));
      expect(manifest, contains('android:dataExtractionRules="@xml/data_extraction_rules"'));

      final netSec = File('android/app/src/main/res/xml/network_security_config.xml').readAsStringSync();
      expect(netSec, contains('<debug-overrides>'));
      expect(netSec, isNot(RegExp(r'<base-config[\s\S]*?<certificates src="user"[\s\S]*?</base-config>')));

      final plist = File('ios/Runner/Info.plist').readAsStringSync();
      expect(plist, isNot(contains('NSLocationAlwaysAndWhenInUseUsageDescription')));
      expect(plist, contains('video calls'));
    });
  });
}

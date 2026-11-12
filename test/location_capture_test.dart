import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hidely_new/screens/post_details_screen.dart';
import 'package:hidely_new/services/api_service.dart';
import 'package:hidely_new/services/auth_service.dart';
import 'package:hidely_new/services/location_capture_service.dart';
import 'package:hidely_new/services/notification_polling_service.dart';

Uint8List buildJpegWithExifGps({
  required double latitude,
  required double longitude,
  double hPositioningErrorMeters = 12.0,
}) {
  final baseJpg = Uint8List.fromList(
    img.encodeJpg(img.Image(width: 2, height: 2)),
  );
  assert(baseJpg.length >= 2 && baseJpg[0] == 0xFF && baseJpg[1] == 0xD8);

  const int tiffLength = 148;
  final tiff = ByteData(tiffLength);

  // TIFF Header (Little Endian 'II', 42, IFD0 offset = 8)
  tiff.setUint8(0, 0x49);
  tiff.setUint8(1, 0x49);
  tiff.setUint16(2, 0x002A, Endian.little);
  tiff.setUint32(4, 8, Endian.little);

  // IFD0 at offset 8 (1 entry -> GPS IFD pointer 0x8825)
  tiff.setUint16(8, 1, Endian.little);
  tiff.setUint16(10, 0x8825, Endian.little);
  tiff.setUint16(12, 4, Endian.little); // LONG
  tiff.setUint32(14, 1, Endian.little);
  tiff.setUint32(18, 26, Endian.little); // GPS IFD offset
  tiff.setUint32(22, 0, Endian.little); // next IFD = 0

  // GPS IFD at offset 26 (5 entries)
  tiff.setUint16(26, 5, Endian.little);
  void writeEntry(int index, int tag, int type, int count, int valueOrOffset) {
    final base = 28 + index * 12;
    tiff.setUint16(base, tag, Endian.little);
    tiff.setUint16(base + 2, type, Endian.little);
    tiff.setUint32(base + 4, count, Endian.little);
    tiff.setUint32(base + 8, valueOrOffset, Endian.little);
  }

  final int latRefChar = latitude >= 0 ? 'N'.codeUnitAt(0) : 'S'.codeUnitAt(0);
  final int lonRefChar = longitude >= 0 ? 'E'.codeUnitAt(0) : 'W'.codeUnitAt(0);

  // Inline ASCII 2-byte values (little-endian uint32: [char, 0, 0, 0])
  writeEntry(0, 0x0001, 2, 2, latRefChar);
  writeEntry(1, 0x0002, 5, 3, 92);
  writeEntry(2, 0x0003, 2, 2, lonRefChar);
  writeEntry(3, 0x0004, 5, 3, 116);
  writeEntry(4, 0x001F, 5, 1, 140);
  tiff.setUint32(28 + 5 * 12, 0, Endian.little); // next IFD = 0

  void writeDmsRational(int offset, double decimalDegrees) {
    final absVal = decimalDegrees.abs();
    final deg = absVal.floor();
    final minFloat = (absVal - deg) * 60.0;
    final min = minFloat.floor();
    final sec = (minFloat - min) * 60.0;
    final secNum = (sec * 10000).round();

    tiff.setUint32(offset, deg, Endian.little);
    tiff.setUint32(offset + 4, 1, Endian.little);
    tiff.setUint32(offset + 8, min, Endian.little);
    tiff.setUint32(offset + 12, 1, Endian.little);
    tiff.setUint32(offset + 16, secNum, Endian.little);
    tiff.setUint32(offset + 20, 10000, Endian.little);
  }

  writeDmsRational(92, latitude);
  writeDmsRational(116, longitude);
  tiff.setUint32(140, (hPositioningErrorMeters * 10).round(), Endian.little);
  tiff.setUint32(144, 10, Endian.little);

  const int app1PayloadLen = 6 + tiffLength;
  const int app1LengthField = app1PayloadLen + 2;

  final out = BytesBuilder();
  out.add([0xFF, 0xD8]); // SOI
  out.add([
    0xFF,
    0xE1,
    (app1LengthField >> 8) & 0xFF,
    app1LengthField & 0xFF,
  ]);
  out.add(ascii.encode('Exif'));
  out.add([0x00, 0x00]);
  out.add(tiff.buffer.asUint8List());
  out.add(baseJpg.sublist(2));
  return out.toBytes();
}

Position _makePosition(double lat, double lon, {double accuracy = 10.0, DateTime? timestamp}) {
  return Position(
    longitude: lon,
    latitude: lat,
    timestamp: timestamp ?? DateTime.now(),
    accuracy: accuracy,
    altitude: 0.0,
    altitudeAccuracy: 0.0,
    heading: 0.0,
    headingAccuracy: 0.0,
    speed: 0.0,
    speedAccuracy: 0.0,
  );
}

class _FakeGeolocatorPlatform extends GeolocatorPlatform {
  bool serviceEnabled = true;
  LocationPermission permission = LocationPermission.always;
  LocationPermission requestedPermissionResult = LocationPermission.always;
  Position? currentPositionResult;
  Position? lastKnownPositionResult;
  List<Position> streamPositions = <Position>[];
  Object? getCurrentError;

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async {
    permission = requestedPermissionResult;
    return requestedPermissionResult;
  }

  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) async {
    if (getCurrentError != null) {
      throw getCurrentError!;
    }
    return currentPositionResult!;
  }

  @override
  Future<Position?> getLastKnownPosition({bool forceLocationManager = false}) async {
    return lastKnownPositionResult;
  }

  @override
  Stream<Position> getPositionStream({LocationSettings? locationSettings}) {
    if (streamPositions.isEmpty) {
      return const Stream<Position>.empty();
    }
    return Stream<Position>.fromIterable(streamPositions);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel secureStorageChannel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  const MethodChannel localNotifChannel =
      MethodChannel('dexterous.com/flutter_local_notifications');
  const MethodChannel connectivityChannel =
      MethodChannel('dev.fluttercommunity.plus/connectivity');
  final Map<String, String> fakeSecureStore = <String, String>{};

  late GeolocatorPlatform originalGeolocator;
  late _FakeGeolocatorPlatform fakeGeolocator;

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
          final key = args['key']?.toString();
          final val = args['value']?.toString();
          if (key != null && val != null) fakeSecureStore[key] = val;
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

    messenger.setMockMethodCallHandler(localNotifChannel, (call) async => null);
    messenger.setMockMethodCallHandler(
        connectivityChannel, (call) async => <String>['wifi']);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    fakeSecureStore.clear();
    LocationCaptureService.clearCachesForTest();
    final locService = LocationCaptureService();
    locService.httpClientOverride = null;
    locService.skipNativeGeocoderForTest = true;
    locService.nativePlacemarkOverride = null;
    locService.accuracyRefinementTimeoutOverride =
        const Duration(milliseconds: 250);
    locService.lastErrorMessage = null;
    locService.lastServiceEnabled = true;
    locService.lastPermission = null;

    originalGeolocator = GeolocatorPlatform.instance;
    fakeGeolocator = _FakeGeolocatorPlatform();
    GeolocatorPlatform.instance = fakeGeolocator;
  });

  tearDown(() {
    GeolocatorPlatform.instance = originalGeolocator;
    LocationCaptureService().httpClientOverride = null;
    LocationCaptureService().skipNativeGeocoderForTest = false;
    LocationCaptureService().nativePlacemarkOverride = null;
    LocationCaptureService().accuracyRefinementTimeoutOverride = null;
    ApiService().resetClientForTest();
    NotificationPollingService().stopPolling();
  });

  group('LocationCaptureService validation & metadata extraction', () {
    test('isValidCoordinatePair rejects invalid, out-of-bounds, and (0,0)', () {
      expect(LocationCaptureService.isValidCoordinatePair(null, 77.2), isFalse);
      expect(LocationCaptureService.isValidCoordinatePair(28.6, null), isFalse);
      expect(LocationCaptureService.isValidCoordinatePair(double.nan, 77.2), isFalse);
      expect(LocationCaptureService.isValidCoordinatePair(28.6, double.infinity), isFalse);
      expect(LocationCaptureService.isValidCoordinatePair(90.5, 77.2), isFalse);
      expect(LocationCaptureService.isValidCoordinatePair(-91.0, 77.2), isFalse);
      expect(LocationCaptureService.isValidCoordinatePair(28.6, 180.5), isFalse);
      expect(LocationCaptureService.isValidCoordinatePair(28.6, -181.0), isFalse);
      expect(LocationCaptureService.isValidCoordinatePair(0.0, 0.0), isFalse);
      expect(LocationCaptureService.isValidCoordinatePair(0.00001, -0.00002), isFalse);

      expect(LocationCaptureService.isValidCoordinatePair(28.6139, 77.2090), isTrue);
      expect(LocationCaptureService.isValidCoordinatePair(-33.8688, 151.2093), isTrue);
      expect(LocationCaptureService.isValidCoordinatePair(-22.9068, -43.1729), isTrue);
    });

    test('extractExifGpsWithMetadata parses NE and SW EXIF GPS accurately', () async {
      final northEastJpg = buildJpegWithExifGps(
        latitude: 27.1751,
        longitude: 78.0421,
        hPositioningErrorMeters: 8.5,
      );
      final ne = await LocationCaptureService()
          .extractExifGpsWithMetadata(northEastJpg);
      expect(ne, isNotNull);
      expect((ne!['latitude'] as double), closeTo(27.1751, 0.0002));
      expect((ne['longitude'] as double), closeTo(78.0421, 0.0002));
      expect((ne['accuracyMeters'] as double), closeTo(8.5, 0.05));

      final southWestJpg = buildJpegWithExifGps(
        latitude: -33.4489,
        longitude: -70.6693,
      );
      final sw = await LocationCaptureService()
          .extractExifGpsWithMetadata(southWestJpg);
      expect(sw, isNotNull);
      expect((sw!['latitude'] as double), closeTo(-33.4489, 0.0002));
      expect((sw['longitude'] as double), closeTo(-70.6693, 0.0002));
    });

    test('extractVideoIso6709Gps & extractVideoGpsFromFile extract QuickTime tail ©xyz atom', () async {
      final payload = Uint8List.fromList(<int>[
        0x00, 0x00, 0x00, 0x18,
        0xA9, 0x78, 0x79, 0x7A, // ©xyz
        0x00, 0x12, 0x15, 0xC7,
        ...ascii.encode('+28.6139+077.2090+216.00/'),
      ]);

      final parsed = LocationCaptureService().extractVideoIso6709Gps(payload);
      expect(parsed, isNotNull);
      expect(parsed!['latitude'], closeTo(28.6139, 0.0001));
      expect(parsed['longitude'], closeTo(77.2090, 0.0001));

      // Rejects (0,0) null-island ISO-6709 payload
      final zeroPayload = Uint8List.fromList(latin1.encode('©xyz+0.0000+0.0000/'));
      expect(LocationCaptureService().extractVideoIso6709Gps(zeroPayload), isNull);

      // Verify >4MB MP4 tail atom extraction without OOM
      final tmpDir = await Directory.systemTemp.createTemp('hidely_vid_test_');
      try {
        final videoFile = File('${tmpDir.path}/sample_camera.mp4');
        final raf = await videoFile.open(mode: FileMode.write);
        await raf.writeFrom(ascii.encode('ftypisom'));
        await raf.setPosition(5 * 1024 * 1024);
        await raf.writeFrom(payload);
        await raf.close();

        final fileGps =
            await LocationCaptureService().extractVideoGpsFromFile(videoFile);
        expect(fileGps, isNotNull);
        expect(fileGps!['latitude'], closeTo(28.6139, 0.0001));
        expect(fileGps['longitude'], closeTo(77.2090, 0.0001));
      } finally {
        await tmpDir.delete(recursive: true);
      }
    });
  });

  group('LocationCaptureService GPS capture & multi-provider geocoding', () {
    test('captureCameraLocation reports disabled GPS & deniedForever diagnostics', () async {
      fakeGeolocator.serviceEnabled = false;
      final disabledLoc = await LocationCaptureService().captureCameraLocation();
      expect(disabledLoc, isNull);
      expect(LocationCaptureService().lastServiceEnabled, isFalse);
      expect(LocationCaptureService().lastErrorMessage, contains('GPS'));

      fakeGeolocator.serviceEnabled = true;
      fakeGeolocator.permission = LocationPermission.deniedForever;
      final deniedLoc = await LocationCaptureService().captureCameraLocation();
      expect(deniedLoc, isNull);
      expect(LocationCaptureService().lastPermission,
          LocationPermission.deniedForever);
      expect(LocationCaptureService().lastErrorMessage, isNotEmpty);
    });

    test('captureCameraLocation refines coarse initial fix via position stream & cascades geocoders', () async {
      fakeGeolocator.currentPositionResult =
          _makePosition(28.6000, 77.2000, accuracy: 85.0);
      fakeGeolocator.streamPositions = <Position>[
        _makePosition(28.6100, 77.2200, accuracy: 42.0),
        _makePosition(28.6129, 77.2295, accuracy: 12.0),
      ];

      // Force Google Reverse Geocode to fail (ZERO_RESULTS) so Nominatim zoom=18 handles it
      LocationCaptureService().httpClientOverride = MockClient((request) async {
        if (request.url.host.contains('maps.googleapis.com')) {
          return http.Response('{"status":"ZERO_RESULTS","results":[]}', 200);
        }
        if (request.url.host.contains('nominatim.openstreetmap.org')) {
          return http.Response(
            jsonEncode({
              'name': 'India Gate',
              'type': 'monument',
              'address': {
                'tourism': 'India Gate',
                'city': 'New Delhi',
                'state': 'Delhi',
                'country': 'India',
              },
              'display_name': 'India Gate, New Delhi, Delhi, India',
            }),
            200,
          );
        }
        return http.Response('{}', 404);
      });

      final captured = await LocationCaptureService().captureCameraLocation();
      expect(captured, isNotNull);
      expect(captured!.latitude, closeTo(28.6129, 0.0001));
      expect(captured.longitude, closeTo(77.2295, 0.0001));
      expect(captured.accuracyMeters, closeTo(12.0, 0.01));
      expect(captured.isHighConfidence, isTrue);
      expect(captured.source, 'camera_capture');
      expect(captured.displayName, 'India Gate, New Delhi');
      expect(captured.city, 'New Delhi');
      expect(captured.state, 'Delhi');
      expect(captured.country, 'India');
    });

    test('reverseGeocodeDetailed falls back through Photon -> native placemark override', () async {
      // Case 1: Google & Nominatim fail -> Photon succeeds
      LocationCaptureService().httpClientOverride = MockClient((request) async {
        if (request.url.host.contains('photon.komoot.io')) {
          return http.Response(
            jsonEncode({
              'features': [
                {
                  'properties': {
                    'name': 'Hawa Mahal',
                    'city': 'Jaipur',
                    'state': 'Rajasthan',
                    'country': 'India',
                    'osm_value': 'attraction',
                  }
                }
              ]
            }),
            200,
          );
        }
        return http.Response('error', 500);
      });

      final photonRes =
          await LocationCaptureService().reverseGeocodeDetailed(26.9239, 75.8267);
      expect(photonRes, isNotNull);
      expect(photonRes!.displayName, 'Hawa Mahal, Jaipur');
      expect(photonRes.city, 'Jaipur');

      // Case 2: All HTTP fail -> nativePlacemarkOverride succeeds
      LocationCaptureService.clearCachesForTest();
      LocationCaptureService().httpClientOverride =
          MockClient((request) async => http.Response('down', 503));
      LocationCaptureService().nativePlacemarkOverride = (lat, lon) async =>
          const ReverseGeocodeResult(
            displayName: 'Pangong Lake, Ladakh',
            canonicalName: 'Pangong Lake',
            city: 'Leh',
            state: 'Ladakh',
            country: 'India',
            landmarkType: 'locality',
          );

      final nativeRes =
          await LocationCaptureService().reverseGeocodeDetailed(33.7595, 78.6674);
      expect(nativeRes, isNotNull);
      expect(nativeRes!.displayName, 'Pangong Lake, Ladakh');
    });

    test('reverseGeocodeDetailed skips Google Plus Codes and extracts real landmark & city', () async {
      LocationCaptureService().httpClientOverride = MockClient((request) async {
        if (request.url.host.contains('maps.googleapis.com') ||
            request.url.path.contains('/api/map/reverse-geocode')) {
          return http.Response(
            jsonEncode({
              'status': 'OK',
              'results': [
                {
                  'formatted_address': '8P4G+2X, Shimla, Himachal Pradesh, India',
                  'address_components': [
                    {
                      'long_name': '8P4G+2X',
                      'types': ['plus_code']
                    },
                    {
                      'long_name': 'Jakhoo Temple',
                      'types': ['tourist_attraction', 'point_of_interest']
                    },
                    {
                      'long_name': 'Shimla',
                      'types': ['locality']
                    },
                    {
                      'long_name': 'Himachal Pradesh',
                      'types': ['administrative_area_level_1']
                    },
                    {
                      'long_name': 'India',
                      'types': ['country']
                    },
                  ],
                }
              ],
            }),
            200,
          );
        }
        return http.Response('{}', 404);
      });

      final res =
          await LocationCaptureService().reverseGeocodeDetailed(31.1008, 77.1846);
      expect(res, isNotNull);
      expect(res!.displayName, 'Jakhoo Temple, Shimla');
      expect(res.displayName.contains('8P4G+2X'), isFalse);
      expect(res.city, 'Shimla');
      expect(res.state, 'Himachal Pradesh');
      expect(res.country, 'India');
    });

    test('searchPlaceSuggestions & resolvePlaceSuggestion return coordinates cleanly', () async {
      LocationCaptureService().httpClientOverride = MockClient((request) async {
        if (request.url.path.contains('/api/map/autocomplete')) {
          return http.Response(
            jsonEncode({
              'status': 'OK',
              'predictions': [
                {
                  'description': 'Kedarnath Temple, Rudraprayag',
                  'place_id': 'photon_30.7352_79.0669',
                  'city': 'Rudraprayag',
                  'state': 'Uttarakhand',
                  'country': 'India',
                  'geometry': {
                    'location': {'lat': 30.7352, 'lng': 79.0669}
                  },
                  'structured_formatting': {
                    'main_text': 'Kedarnath Temple',
                    'secondary_text': 'Rudraprayag, Uttarakhand, India',
                  },
                }
              ],
            }),
            200,
          );
        }
        return http.Response('{}', 404);
      });

      final suggestions =
          await LocationCaptureService().searchPlaceSuggestions('Kedarnath');
      expect(suggestions, hasLength(1));
      expect(suggestions.first.hasCoordinates, isTrue);

      final resolved = await LocationCaptureService()
          .resolvePlaceSuggestion(suggestions.first);
      expect(resolved, isNotNull);
      expect(resolved!.displayName, 'Kedarnath Temple, Rudraprayag');
      expect(resolved.latitude, closeTo(30.7352, 0.0001));
      expect(resolved.longitude, closeTo(79.0669, 0.0001));
      expect(resolved.city, 'Rudraprayag');
      expect(resolved.source, 'manual');
    });
  });

  group('PostDetailsScreen end-to-end location flows', () {
    testWidgets('Gallery photo EXIF auto-populates photo location and Switch to Current GPS works', (tester) async {
      await AuthService().login('tok-loc-1', {
        'id': 1,
        'name': 'Harsh',
        'username': 'harsh',
        'email': 'harsh@example.com',
      });
      NotificationPollingService().stopPolling();

      final exifPhotoBytes = buildJpegWithExifGps(
        latitude: 27.1751,
        longitude: 78.0421,
      );

      // Device is currently in Delhi while photo was shot at Taj Mahal, Agra
      fakeGeolocator.currentPositionResult =
          _makePosition(28.6129, 77.2295, accuracy: 9.0);

      LocationCaptureService().httpClientOverride = MockClient((request) async {
        if (request.url.host.contains('nominatim.openstreetmap.org')) {
          final lat = request.url.queryParameters['lat'] ?? '';
          if (lat.startsWith('27.17')) {
            return http.Response(
              jsonEncode({
                'name': 'Taj Mahal',
                'address': {
                  'tourism': 'Taj Mahal',
                  'city': 'Agra',
                  'state': 'Uttar Pradesh',
                  'country': 'India',
                },
              }),
              200,
            );
          }
          if (lat.startsWith('28.61')) {
            return http.Response(
              jsonEncode({
                'name': 'India Gate',
                'address': {
                  'tourism': 'India Gate',
                  'city': 'New Delhi',
                  'state': 'Delhi',
                  'country': 'India',
                },
              }),
              200,
            );
          }
        }
        return http.Response('{"status":"ZERO_RESULTS","results":[]}', 200);
      });

      await tester.pumpWidget(
        MaterialApp(
          home: PostDetailsScreen(
            imageBytes: exifPhotoBytes,
            filename: 'IMG_TAJ.jpg',
            mediaSource: MediaSource.gallery,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verifies Photo EXIF Location (where photo was clicked) is auto-detected & displayed
      expect(find.text('Photo/Video Location (Auto-Detected)'), findsOneWidget);
      expect(find.text('Taj Mahal, Agra'), findsOneWidget);
      expect(find.text('27.1751, 78.0421'), findsOneWidget);
      expect(find.text('EXIF GPS'), findsOneWidget);

      // Switch from Gallery Photo Location -> Current Device GPS
      await tester.tap(find.text('Current GPS'));
      await tester.pumpAndSettle();

      expect(find.text('Current Location (High Accuracy)'), findsOneWidget);
      expect(find.text('India Gate, New Delhi'), findsOneWidget);
      expect(find.text('28.6129, 77.2295'), findsOneWidget);
    });

    testWidgets('Gallery photo without EXIF supports Use Current Location and Location Picker search + Share payload', (tester) async {
      await AuthService().login('tok-loc-2', {
        'id': 2,
        'name': 'Harsh',
        'username': 'harsh',
        'email': 'harsh@example.com',
      });
      NotificationPollingService().stopPolling();

      // Plain JPEG without GPS EXIF
      final plainBytes = Uint8List.fromList(
        img.encodeJpg(img.Image(width: 2, height: 2)),
      );

      fakeGeolocator.currentPositionResult =
          _makePosition(19.0760, 72.8777, accuracy: 11.0);

      LocationCaptureService().httpClientOverride = MockClient((request) async {
        if (request.url.path.contains('/api/map/autocomplete')) {
          return http.Response(
            jsonEncode({
              'status': 'OK',
              'predictions': [
                {
                  'description': 'Manali Mall Road, Manali',
                  'place_id': 'photon_32.2432_77.1892',
                  'city': 'Manali',
                  'state': 'Himachal Pradesh',
                  'country': 'India',
                  'geometry': {
                    'location': {'lat': 32.2432, 'lng': 77.1892}
                  },
                  'structured_formatting': {
                    'main_text': 'Manali Mall Road',
                    'secondary_text': 'Manali, Himachal Pradesh, India',
                  },
                }
              ],
            }),
            200,
          );
        }
        if (request.url.host.contains('nominatim.openstreetmap.org')) {
          return http.Response(
            jsonEncode({
              'name': 'Marine Drive',
              'address': {
                'road': 'Marine Drive',
                'city': 'Mumbai',
                'state': 'Maharashtra',
                'country': 'India',
              },
            }),
            200,
          );
        }
        return http.Response('{"status":"ZERO_RESULTS","results":[]}', 200);
      });

      final Map<String, String> postedFields = <String, String>{};
      ApiService().resetClientForTest(
        MockClient.streaming((request, bodyStream) async {
          if (request.url.path == '/api/posts' &&
              request is http.MultipartRequest) {
            postedFields.addAll(request.fields);
            // Return 400 after capturing fields so widget test stays on
            // PostDetailsScreen without booting full MainWrapper/Map/Socket trees.
            final respBytes = utf8.encode(jsonEncode({
              'error': 'Captured multipart payload for test.',
            }));
            return http.StreamedResponse(
              Stream<List<int>>.value(respBytes),
              400,
              headers: {'content-type': 'application/json'},
            );
          }
          final emptyResp = utf8.encode('{}');
          return http.StreamedResponse(
            Stream<List<int>>.value(emptyResp),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PostDetailsScreen(
            imageBytes: plainBytes,
            filename: 'IMG_PLAIN.jpg',
            mediaSource: MediaSource.gallery,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Shows fallback prompt + Use Current Location chip
      expect(find.text('Add Location'), findsOneWidget);
      expect(find.text('Use Current Location'), findsOneWidget);

      await tester.tap(find.text('Use Current Location'));
      await tester.pumpAndSettle();

      expect(find.text('Marine Drive, Mumbai'), findsOneWidget);
      expect(find.text('19.0760, 72.8777'), findsOneWidget);

      // Open searchable Location Picker via "Change" button and pick Manali
      await tester.tap(find.text('Change'));
      await tester.pumpAndSettle();

      expect(find.text('Select Location'), findsOneWidget);
      final sheetTextField = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(TextField),
      );
      await tester.enterText(sheetTextField, 'Manali');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Manali Mall Road, Manali'));
      await tester.pumpAndSettle();

      // Coordinates updated cleanly from Mumbai -> Manali
      expect(find.text('Manali Mall Road, Manali'), findsOneWidget);
      expect(find.text('32.2432, 77.1892'), findsOneWidget);

      // Verify Share submits accurate structured location fields to backend
      await tester.tap(find.text('Share'));
      await tester.pumpAndSettle();

      expect(postedFields['location'], 'Manali Mall Road, Manali');
      expect(postedFields['latitude'], '32.2432');
      expect(postedFields['longitude'], '77.1892');
      expect(postedFields['location_source'], 'manual');
      expect(postedFields['city'], 'Manali');
      expect(postedFields['state'], 'Himachal Pradesh');
      expect(postedFields['country'], 'India');

      // Now verify changing to un-geocodable custom text clears stale coordinates
      LocationCaptureService.clearCachesForTest();
      LocationCaptureService().httpClientOverride =
          MockClient((request) async => http.Response('{}', 404));
      postedFields.clear();

      await tester.tap(find.text('Change'));
      await tester.pumpAndSettle();

      final sheetTextField2 = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(TextField),
      );
      await tester.enterText(sheetTextField2, 'Secret Camp XYZ');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Set custom location: "Secret Camp XYZ"'));
      await tester.pumpAndSettle();

      expect(find.text('Secret Camp XYZ'), findsOneWidget);
      await tester.tap(find.text('Share'));
      await tester.pumpAndSettle();

      expect(postedFields['location'], 'Secret Camp XYZ');
      expect(postedFields.containsKey('latitude'), isFalse);
      expect(postedFields.containsKey('longitude'), isFalse);
    });
  });
}

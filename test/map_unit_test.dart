import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:hidely_new/data/models/nearby_place.dart';
import 'package:hidely_new/data/models/route_data.dart';
import 'package:hidely_new/data/repositories/map_repository_impl.dart';
import 'package:hidely_new/services/local_storage_service.dart';

class MockLocalStorageService implements LocalStorageService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mock connectivity platform channel response
  const channel = MethodChannel('dev.fluttercommunity.plus/connectivity');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
    if (methodCall.method == 'check') {
      return ['none']; // Simulating offline status for test
    }
    return null;
  });

  group('Map Implementation Tests', () {
    late MapRepositoryImpl repository;

    setUp(() {
      repository = MapRepositoryImpl(MockLocalStorageService());
    });

    test('Geocoding falling back correctly on invalid address', () async {
      final coords = await repository.geocodeAddress('');
      expect(coords, isNull);
    });

    test('Offline routing produces straight line bearing path', () async {
      const start = LatLng(28.6139, 77.2090); // New Delhi
      const end = LatLng(28.7041, 77.1025);   // Rohini, Delhi
      
      // OSRM or Google Maps won't execute if offline, returning straight line
      final route = await repository.getRoute(
        start: start,
        end: end,
        mode: 'walking',
      );

      expect(route, isA<RouteData>());
      expect(route.coordinates, hasLength(2));
      expect(route.coordinates.first, equals(start));
      expect(route.coordinates.last, equals(end));
      expect(route.distanceKm, greaterThan(0));
      expect(route.instructions, isNotEmpty);
    });

    test('Places Search and Filters validation', () {
      final place = NearbyPlace(
        id: 'place_1',
        name: 'India Gate',
        category: 'Monument',
        location: const LatLng(28.6129, 77.2295),
        imageUrl: '',
        rating: 4.8,
      );

      expect(place.id, 'place_1');
      expect(place.name, 'India Gate');
      expect(place.category, 'Monument');
      expect(place.rating, 4.8);
    });
  });
}

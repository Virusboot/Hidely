import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../data/models/nearby_place.dart';

class LocalStorageService {
  Isar? _isar;
  bool _isInitialized = false;

  Isar get isar {
    if (!_isInitialized || _isar == null) {
      throw StateError('Isar is not initialized');
    }
    return _isar!;
  }

  bool get isInitialized => _isInitialized;

  Future<void> init() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      _isar = await Isar.open(
        [NearbyPlaceSchema],
        directory: dir.path,
      );
      _isInitialized = true;
      debugPrint('[LocalStorage] Isar initialized successfully.');
    } catch (e, stackTrace) {
      _isInitialized = false;
      debugPrint('[LocalStorage] Failed to initialize Isar: $e');
      debugPrint('$stackTrace');
    }
  }
}

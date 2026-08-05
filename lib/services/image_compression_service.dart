import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

class ImageCompressionService {
  /// Compresses and resizes an image file if it is larger than 300 KB.
  /// Downscales the image so its maximum dimension is [maxDimension] pixels.
  /// Encodes the output as a JPEG with a quality parameter of [quality].
  static Future<File> compressImage(File file, {int quality = 80, int maxDimension = 1920}) async {
    try {
      final sizeBytes = await file.length();
      
      // If image is already quite small (less than 300 KB), don't compress
      if (sizeBytes < 300 * 1024) {
        debugPrint('[ImageCompressor] Image is already small (${(sizeBytes / 1024).toStringAsFixed(1)} KB). Skipping compression.');
        return file;
      }

      // Read image bytes
      final bytes = await file.readAsBytes();
      
      // Decode image using the image package
      img.Image? image = img.decodeImage(bytes);
      if (image == null) {
        debugPrint('[ImageCompressor] Failed to decode image. Using original file.');
        return file;
      }

      int width = image.width;
      int height = image.height;
      bool resized = false;

      // Calculate new dimensions if they exceed maxDimension
      if (width > maxDimension || height > maxDimension) {
        if (width > height) {
          height = (height * maxDimension / width).round();
          width = maxDimension;
        } else {
          width = (width * maxDimension / height).round();
          height = maxDimension;
        }
        
        // Downscale image
        image = img.copyResize(image, width: width, height: height);
        resized = true;
      }

      // Encode image to JPG with requested quality
      final compressedBytes = img.encodeJpg(image, quality: quality);

      // Write compressed bytes to a temporary file
      final tempDir = await getTemporaryDirectory();
      final tempPath = '${tempDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final compressedFile = File(tempPath);
      await compressedFile.writeAsBytes(compressedBytes);

      final newSize = compressedBytes.length;
      debugPrint('[ImageCompressor] Compressed from ${(sizeBytes / 1024).toStringAsFixed(1)} KB '
          'to ${(newSize / 1024).toStringAsFixed(1)} KB (dimensions: ${width}x$height, resized: $resized)');

      return compressedFile;
    } catch (e) {
      debugPrint('[ImageCompressor] Error during image compression: $e. Returning original file.');
      return file;
    }
  }
}

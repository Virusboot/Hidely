import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:hidely_new/widgets/custom_snackbar.dart';

class MediaDownloadService {
  /// Downloads image or video media to device local storage / gallery
  static Future<bool> downloadMediaToGallery(BuildContext context, String urlOrPath) async {
    if (urlOrPath.trim().isEmpty) {
      if (context.mounted) {
        showHidelySnackBar(context, "No media file found to download", isError: true);
      }
      return false;
    }

    try {
      showHidelySnackBar(context, "Downloading media to gallery...", isError: false);

      Directory? saveDir;
      if (Platform.isAndroid) {
        saveDir = Directory('/storage/emulated/0/Download');
        if (!await saveDir.exists()) {
          saveDir = Directory('/storage/emulated/0/Pictures');
        }
        if (!await saveDir.exists()) {
          saveDir = await getExternalStorageDirectory();
        }
      } else {
        saveDir = await getApplicationDocumentsDirectory();
      }

      if (saveDir == null) {
        if (context.mounted) {
          showHidelySnackBar(context, "Could not access storage directory", isError: true);
        }
        return false;
      }

      final isVideo = urlOrPath.endsWith('.mp4') || urlOrPath.contains('.mp4') || urlOrPath.contains('video');
      final ext = isVideo ? 'mp4' : (urlOrPath.endsWith('.png') ? 'png' : 'jpg');
      final fileName = 'hidely_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final filePath = '${saveDir.path}/$fileName';

      if (urlOrPath.startsWith('http')) {
        final response = await http.get(Uri.parse(urlOrPath));
        if (response.statusCode == 200) {
          final file = File(filePath);
          await file.writeAsBytes(response.bodyBytes);
          if (context.mounted) {
            showHidelySnackBar(context, "Saved to Gallery / Downloads 📥", isError: false);
          }
          return true;
        }
      } else {
        final sourceFile = File(urlOrPath);
        if (await sourceFile.exists()) {
          await sourceFile.copy(filePath);
          if (context.mounted) {
            showHidelySnackBar(context, "Saved to Gallery / Downloads 📥", isError: false);
          }
          return true;
        }
      }

      if (context.mounted) {
        showHidelySnackBar(context, "Failed to download media", isError: true);
      }
      return false;
    } catch (e) {
      debugPrint("Download error: $e");
      if (context.mounted) {
        showHidelySnackBar(context, "Error saving media to gallery", isError: true);
      }
      return false;
    }
  }
}

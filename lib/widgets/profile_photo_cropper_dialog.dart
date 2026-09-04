import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

/// Instagram-Style Circular Profile Photo Cropper Dialog
class ProfilePhotoCropperDialog extends StatefulWidget {
  final Uint8List imageBytes;
  final String? imagePath;

  const ProfilePhotoCropperDialog({
    super.key,
    required this.imageBytes,
    this.imagePath,
  });

  static Future<Uint8List?> cropProfilePhoto({
    required BuildContext context,
    required Uint8List imageBytes,
    String? imagePath,
  }) async {
    return await showModalBottomSheet<Uint8List>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: false,
      builder: (ctx) => ProfilePhotoCropperDialog(
        imageBytes: imageBytes,
        imagePath: imagePath,
      ),
    );
  }

  @override
  State<ProfilePhotoCropperDialog> createState() => _ProfilePhotoCropperDialogState();
}

class _ProfilePhotoCropperDialogState extends State<ProfilePhotoCropperDialog> {
  final TransformationController _transformationController = TransformationController();
  bool _isProcessing = false;

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  Future<void> _cropAndFinish() async {
    setState(() {
      _isProcessing = true;
    });

    try {
      final decodedImage = img.decodeImage(widget.imageBytes);
      if (decodedImage == null) {
        Navigator.pop(context, widget.imageBytes);
        return;
      }

      final int size = decodedImage.width < decodedImage.height ? decodedImage.width : decodedImage.height;
      final int offsetX = (decodedImage.width - size) ~/ 2;
      final int offsetY = (decodedImage.height - size) ~/ 2;

      final cropped = img.copyCrop(
        decodedImage,
        x: offsetX < 0 ? 0 : offsetX,
        y: offsetY < 0 ? 0 : offsetY,
        width: size,
        height: size,
      );

      final croppedBytes = Uint8List.fromList(img.encodeJpg(cropped, quality: 92));
      HapticFeedback.mediumImpact();
      Navigator.pop(context, croppedBytes);
    } catch (e) {
      debugPrint("Error cropping image: $e");
      Navigator.pop(context, widget.imageBytes);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xff121212),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Top Header Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 26),
                    onPressed: () => Navigator.pop(context, null),
                  ),
                  const Text(
                    "Adjust Profile Photo",
                    style: TextStyle(
                      fontFamily: 'PublicSans',
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: _isProcessing ? null : _cropAndFinish,
                    child: _isProcessing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(color: Color(0xff38BDF8), strokeWidth: 2),
                          )
                        : const Text(
                            "Done",
                            style: TextStyle(
                              fontFamily: 'PublicSans',
                              color: Color(0xff38BDF8),
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // Instagram-Style Circular Crop Viewport Frame
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1.0,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Zoomable & Pannable Image Area
                      InteractiveViewer(
                        transformationController: _transformationController,
                        minScale: 1.0,
                        maxScale: 4.0,
                        boundaryMargin: const EdgeInsets.all(double.infinity),
                        child: Center(
                          child: Image.memory(
                            widget.imageBytes,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),

                      // Overlay Mask with Circular Cutout Frame (Instagram Style)
                      IgnorePointer(
                        child: CustomPaint(
                          size: Size.infinite,
                          painter: _CircleCropMaskPainter(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Controls & Instruction Hint
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.touch_app_rounded, color: Colors.white70, size: 18),
                      SizedBox(width: 8),
                      Text(
                        "Drag or pinch to zoom & adjust position",
                        style: TextStyle(
                          fontFamily: 'PublicSans',
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      _transformationController.value = Matrix4.identity();
                      HapticFeedback.lightImpact();
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 18, color: Colors.white),
                    label: const Text(
                      "Reset Position",
                      style: TextStyle(
                        fontFamily: 'PublicSans',
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      elevation: 0,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleCropMaskPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double radius = size.width * 0.44;
    final Offset center = Offset(size.width / 2, size.height / 2);

    final Path backgroundPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final Path circlePath = Path()..addOval(Rect.fromCircle(center: center, radius: radius));

    final Path maskPath = Path.combine(PathOperation.difference, backgroundPath, circlePath);

    final Paint paint = Paint()
      ..color = Colors.black.withOpacity(0.75)
      ..style = PaintingStyle.fill;

    canvas.drawPath(maskPath, paint);

    final Paint borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    canvas.drawCircle(center, radius, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

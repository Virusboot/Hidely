import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hidely_new/services/api_service.dart';

class ImageFullViewScreen extends StatelessWidget {
  final String imagePath;
  final bool isAsset;

  const ImageFullViewScreen({
    super.key,
    required this.imagePath,
    this.isAsset = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Pinch-to-zoom image layer
          Center(
            child: InteractiveViewer(
              clipBehavior: Clip.none,
              minScale: 0.8,
              maxScale: 4.0,
              child: imagePath.startsWith('http') || imagePath.startsWith('uploads')
                  ? Image.network(
                      imagePath.startsWith('http') ? imagePath : '${ApiService().baseUrl}/$imagePath',
                      fit: BoxFit.contain,
                      width: double.infinity,
                      height: double.infinity,
                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, color: Colors.white24, size: 48),
                    )
                  : isAsset
                      ? Image.asset(
                          imagePath,
                          fit: BoxFit.contain,
                          width: double.infinity,
                          height: double.infinity,
                        )
                      : Image.file(
                          File(imagePath),
                          fit: BoxFit.contain,
                          width: double.infinity,
                          height: double.infinity,
                        ),
            ),
          ),

          // Safe-area close button on top-left
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

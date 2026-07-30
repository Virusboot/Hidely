import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hidely_new/screens/feed_video_player.dart';
import 'package:hidely_new/services/api_service.dart';

class LocationSwipeViewScreen extends StatefulWidget {
  final List<dynamic> items;
  final int initialIndex;

  const LocationSwipeViewScreen({
    super.key,
    required this.items,
    required this.initialIndex,
  });

  @override
  State<LocationSwipeViewScreen> createState() => _LocationSwipeViewScreenState();
}

class _LocationSwipeViewScreenState extends State<LocationSwipeViewScreen> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  bool _isVideo(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.mkv') ||
        lower.endsWith('.avi');
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
      body: Stack(
        children: [
          // PageView for swiping left/right
          PageView.builder(
            controller: _pageController,
            itemCount: widget.items.length,
            itemBuilder: (context, index) {
              final item = widget.items[index];
              final String mediaPath = item["image_url"] ?? (item["image"] is String ? item["image"] : "");
              final bool isNetwork = mediaPath.startsWith("http") || mediaPath.startsWith("uploads");
              final bool isVideo = _isVideo(mediaPath);

              if (isVideo) {
                return Center(
                  child: FeedVideoPlayer(videoUrl: mediaPath),
                );
              } else {
                return Center(
                  child: InteractiveViewer(
                    clipBehavior: Clip.none,
                    minScale: 0.8,
                    maxScale: 4.0,
                    child: isNetwork
                        ? Image.network(
                            mediaPath.startsWith('http') ? mediaPath : '${ApiService().baseUrl}/$mediaPath',
                            fit: BoxFit.contain,
                            width: double.infinity,
                            height: double.infinity,
                            errorBuilder: (context, error, stackTrace) => const Icon(
                              Icons.broken_image,
                              color: Colors.white24,
                              size: 48,
                            ),
                          )
                        : Image.asset(
                            mediaPath,
                            fit: BoxFit.contain,
                            width: double.infinity,
                            height: double.infinity,
                            errorBuilder: (context, error, stackTrace) => const Icon(
                              Icons.broken_image,
                              color: Colors.white24,
                              size: 48,
                            ),
                          ),
                  ),
                );
              }
            },
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
    ),);
  }
}

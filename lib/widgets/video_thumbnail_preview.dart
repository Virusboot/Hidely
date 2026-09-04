import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:hidely_new/services/api_service.dart';

class VideoThumbnailPreview extends StatefulWidget {
  final String videoUrl;
  final BoxFit fit;
  final Widget? fallback;

  const VideoThumbnailPreview({
    super.key,
    required this.videoUrl,
    this.fit = BoxFit.cover,
    this.fallback,
  });

  @override
  State<VideoThumbnailPreview> createState() => _VideoThumbnailPreviewState();
}

class _VideoThumbnailPreviewState extends State<VideoThumbnailPreview> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initThumbnail();
  }

  @override
  void didUpdateWidget(VideoThumbnailPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) {
      _disposeController();
      _initThumbnail();
    }
  }

  Future<void> _initThumbnail() async {
    if (widget.videoUrl.isEmpty) {
      if (mounted) setState(() => _hasError = true);
      return;
    }

    final bool isLocal = !kIsWeb &&
        (widget.videoUrl.startsWith('/') ||
            widget.videoUrl.startsWith('file://') ||
            widget.videoUrl.contains('cache/'));

    try {
      if (isLocal) {
        _controller = VideoPlayerController.file(File(widget.videoUrl));
      } else {
        final String resolvedUrl = widget.videoUrl.startsWith('http') ||
                widget.videoUrl.startsWith('blob:')
            ? widget.videoUrl
            : (widget.videoUrl.startsWith('/')
                ? '${ApiService().baseUrl}${widget.videoUrl}'
                : '${ApiService().baseUrl}/${widget.videoUrl}');
        _controller = VideoPlayerController.networkUrl(Uri.parse(resolvedUrl));
      }

      await _controller!.initialize();
      await _controller!.setVolume(0.0);
      // Seek slightly past frame 0 to avoid blank black intro frames
      await _controller!.seekTo(const Duration(milliseconds: 500));

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      debugPrint("Error initializing video thumbnail: $e");
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }

  void _disposeController() {
    _controller?.dispose();
    _controller = null;
    _isInitialized = false;
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return widget.fallback ??
          Container(
            color: const Color(0xff1E293B),
            child: const Center(
              child: Icon(Icons.play_circle_fill_rounded, color: Colors.white70, size: 36),
            ),
          );
    }

    if (!_isInitialized || _controller == null) {
      return widget.fallback ??
          Container(
            color: const Color(0xff0F172A),
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
              ),
            ),
          );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        FittedBox(
          fit: widget.fit,
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            width: _controller!.value.size.width > 0 ? _controller!.value.size.width : 300,
            height: _controller!.value.size.height > 0 ? _controller!.value.size.height : 300,
            child: VideoPlayer(_controller!),
          ),
        ),
        // Instagram Reels Style Top-Right Play Badge
        Positioned(
          top: 8,
          right: 8,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.55),
              shape: BoxShape.circle,
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.play_arrow_rounded,
              color: Colors.white,
              size: 16,
            ),
          ),
        ),
      ],
    );
  }
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:hidely_new/services/api_service.dart';

import 'package:hidely_new/screens/full_screen_video_player.dart';

class FeedVideoPlayer extends StatefulWidget {
  final String videoUrl;
  const FeedVideoPlayer({super.key, required this.videoUrl});

  @override
  State<FeedVideoPlayer> createState() => _FeedVideoPlayerState();
}

class _FeedVideoPlayerState extends State<FeedVideoPlayer> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isPlaying = true;
  bool _isMuted = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    final bool isLocal = widget.videoUrl.startsWith('/') || widget.videoUrl.startsWith('file://') || widget.videoUrl.contains('cache/');

    if (isLocal) {
      _controller = VideoPlayerController.file(File(widget.videoUrl));
    } else {
      final String resolvedUrl = widget.videoUrl.startsWith('http')
          ? widget.videoUrl
          : '${ApiService().baseUrl}/${widget.videoUrl}';
      _controller = VideoPlayerController.networkUrl(Uri.parse(resolvedUrl));
    }

    try {
      await _controller!.initialize();
      await _controller!.setLooping(true);
      await _controller!.setVolume(1.0);
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
        _controller!.play();
      }
    } catch (e) {
      debugPrint("Error initializing feed video player: $e");
    }
  }

  @override
  void dispose() {
    try {
      _controller?.pause();
      _controller?.dispose();
    } catch (e) {
      debugPrint("Error disposing video controller: $e");
    }
    super.dispose();
  }



  void _toggleMute() {
    if (_controller == null || !_isInitialized) return;
    setState(() {
      _isMuted = !_isMuted;
      _controller!.setVolume(_isMuted ? 0.0 : 1.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized || _controller == null) {
      return Container(
        height: 480,
        width: double.infinity,
        color: Colors.black87,
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        _controller?.pause();
        setState(() {
          _isPlaying = false;
        });
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FullScreenVideoPlayer(videoUrl: widget.videoUrl),
          ),
        ).then((_) {
          if (mounted) {
            _controller?.play();
            setState(() {
              _isPlaying = true;
            });
          }
        });
      },
      child: Container(
        height: 480,
        width: double.infinity,
        color: Colors.black,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Looping Full-Screen Fitted Video Player
            Positioned.fill(
              child: ClipRect(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _controller!.value.size.width,
                    height: _controller!.value.size.height,
                    child: VideoPlayer(_controller!),
                  ),
                ),
              ),
            ),

            // Play/Pause Overlay Indicator
            if (!_isPlaying)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 40,
                ),
              ),

            // Audio mute/unmute control overlay in bottom-right
            Positioned(
              bottom: 12,
              right: 12,
              child: GestureDetector(
                onTap: _toggleMute,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

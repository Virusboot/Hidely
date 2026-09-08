import 'package:flutter/foundation.dart';
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
  bool _isInitializing = false;
  bool _isPlaying = false;
  bool _isMuted = true;
  bool _userPaused = false;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_isDisposed) {
        _checkVisibility();
      }
    });
  }

  @override
  void didUpdateWidget(FeedVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) {
      _disposeController();
      _checkVisibility();
    }
  }

  Future<void> _initializePlayer() async {
    if (_isInitializing || _controller != null || _isDisposed || !mounted) return;
    _isInitializing = true;

    final bool isLocal = !kIsWeb && (widget.videoUrl.startsWith('/') || widget.videoUrl.startsWith('file://') || widget.videoUrl.contains('cache/'));

    final String resolvedUrl = isLocal
        ? widget.videoUrl
        : (widget.videoUrl.startsWith('http') || widget.videoUrl.startsWith('blob:')
            ? widget.videoUrl
            : (widget.videoUrl.startsWith('/') ? '${ApiService().baseUrl}${widget.videoUrl}' : '${ApiService().baseUrl}/${widget.videoUrl}'));

    final VideoPlayerController controller = isLocal
        ? VideoPlayerController.file(File(resolvedUrl))
        : VideoPlayerController.networkUrl(Uri.parse(resolvedUrl));

    try {
      await controller.initialize();
      if (_isDisposed || !mounted) {
        controller.dispose();
        _isInitializing = false;
        return;
      }

      await controller.setLooping(true);
      await controller.setVolume(_isMuted ? 0.0 : 1.0);

      _controller = controller;
      _isInitializing = false;

      if (mounted && !_isDisposed) {
        setState(() {
          _isInitialized = true;
        });
        _checkVisibility();
      } else {
        controller.dispose();
        _controller = null;
        _isInitialized = false;
      }
    } catch (e) {
      _isInitializing = false;
      debugPrint("Error initializing feed video player: $e");
    }
  }

  void _checkVisibility() {
    if (!mounted || _isDisposed) return;

    try {
      final RenderObject? renderObject = context.findRenderObject();
      if (renderObject == null || !renderObject.attached) {
        _disposeController();
        return;
      }

      final RenderBox renderBox = renderObject as RenderBox;
      if (!renderBox.hasSize) {
        _disposeController();
        return;
      }

      final Offset position = renderBox.localToGlobal(Offset.zero);
      final Size size = renderBox.size;
      final double screenHeight = MediaQuery.of(context).size.height;

      final double top = position.dy;
      final double bottom = top + size.height;

      final bool isVisible = top < (screenHeight - 60) && bottom > 60;

      if (isVisible) {
        if (_controller == null && !_isInitializing) {
          _initializePlayer();
        } else if (_isInitialized && !_userPaused) {
          _playVideo();
        }
      } else {
        _disposeController();
      }
    } catch (e) {
      // Safe fallback
    }
  }

  void _playVideo() {
    if (_isDisposed || !mounted || _controller == null || !_isInitialized) return;
    if (!_controller!.value.isPlaying) {
      _controller!.play();
      if (mounted && !_isPlaying) {
        setState(() {
          _isPlaying = true;
        });
      }
    }
  }

  void _pauseVideo() {
    if (_isDisposed || !mounted || _controller == null || !_isInitialized) return;
    if (_controller!.value.isPlaying) {
      _controller!.pause();
      if (mounted && _isPlaying) {
        setState(() {
          _isPlaying = false;
        });
      }
    }
  }

  void _disposeController() {
    if (_controller != null) {
      try {
        _controller!.setVolume(0.0);
        _controller!.pause();
        _controller!.dispose();
      } catch (e) {
        debugPrint("Error disposing video controller: $e");
      }
      _controller = null;
      _isInitialized = false;
      _isPlaying = false;
      if (mounted && !_isDisposed) {
        setState(() {});
      }
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _disposeController();
    super.dispose();
  }

  void _toggleMute() {
    if (_controller == null || !_isInitialized || _isDisposed) return;
    setState(() {
      _isMuted = !_isMuted;
      _controller!.setVolume(_isMuted ? 0.0 : 1.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized || _controller == null) {
      return NotificationListener<ScrollNotification>(
        onNotification: (ScrollNotification scrollInfo) {
          _checkVisibility();
          return false;
        },
        child: Container(
          height: 480,
          width: double.infinity,
          color: Colors.black87,
          child: const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification scrollInfo) {
        _checkVisibility();
        return false;
      },
      child: GestureDetector(
        onTap: () {
          _userPaused = true;
          _pauseVideo();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FullScreenVideoPlayer(videoUrl: widget.videoUrl),
            ),
          ).then((_) {
            if (mounted && !_isDisposed) {
              _userPaused = false;
              _checkVisibility();
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
      ),
    );
  }
}

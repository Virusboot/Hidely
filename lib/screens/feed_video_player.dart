import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:hidely_new/services/api_service.dart';
import 'package:hidely_new/screens/full_screen_video_player.dart';
import 'package:hidely_new/screens/main_wrapper.dart';
import 'package:hidely_new/main.dart' show routeObserver;

class FeedVideoPlayer extends StatefulWidget {
  final String videoUrl;
  const FeedVideoPlayer({super.key, required this.videoUrl});

  @override
  State<FeedVideoPlayer> createState() => _FeedVideoPlayerState();
}

class _FeedVideoPlayerState extends State<FeedVideoPlayer> with WidgetsBindingObserver, RouteAware {
  static _FeedVideoPlayerState? _currentlyPlaying;

  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isInitializing = false;
  bool _isPlaying = false;
  bool _isMuted = true;
  bool _userPaused = false;
  bool _isDisposed = false;

  bool _isRouteActive = true;
  bool _isTabActive = true;
  bool _isAppForeground = true;
  double _visibleFraction = 0.0;
  bool _isSubscribedToRoute = false;

  String get _thumbnailUrl {
    final url = widget.videoUrl;
    if (url.contains('cloudinary.com')) {
      return url.replaceAll(RegExp(r'\.(mp4|mov|avi|webm|mkv)$', caseSensitive: false), '.jpg');
    }
    return '';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    MainWrapperState.currentTabNotifier.addListener(_onTabChanged);
    _onTabChanged();
    _initializePlayer();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isSubscribedToRoute) {
      final modalRoute = ModalRoute.of(context);
      if (modalRoute != null) {
        routeObserver.subscribe(this, modalRoute);
        _isSubscribedToRoute = true;
      }
    }
  }

  void _onTabChanged() {
    if (!mounted || _isDisposed) return;
    final int tab = MainWrapperState.currentTabNotifier.value;
    final bool isFeed = (tab == 0);
    if (_isTabActive != isFeed) {
      _isTabActive = isFeed;
      if (!_isTabActive) {
        _pauseVideo();
      } else {
        _checkAndAutoPlay();
      }
    }
  }

  @override
  void didPushNext() {
    // Navigated away to a new screen/route (e.g. Chat, Profile, Fullscreen, Sheet)
    _isRouteActive = false;
    _pauseVideo();
  }

  @override
  void didPopNext() {
    // Returned back to this screen
    _isRouteActive = true;
    _checkAndAutoPlay();
  }

  @override
  void didPop() {
    _isRouteActive = false;
    _pauseVideo();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isAppForeground = (state == AppLifecycleState.resumed);
    if (!_isAppForeground) {
      _pauseVideo();
    } else {
      _checkAndAutoPlay();
    }
  }

  void _checkAndAutoPlay() {
    if (_isDisposed || !mounted || _controller == null || !_isInitialized) return;
    if (!_userPaused && _isRouteActive && _isTabActive && _isAppForeground && _visibleFraction >= 0.5) {
      _playVideo();
    } else if (_visibleFraction < 0.5 || !_isRouteActive || !_isTabActive || !_isAppForeground) {
      _pauseVideo();
    }
  }

  @override
  void didUpdateWidget(FeedVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) {
      _disposeController();
      _initializePlayer();
    }
  }

  Future<void> _initializePlayer() async {
    if (_isInitializing || _isDisposed || !mounted) return;
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
      await controller.setVolume(0.0); // Start muted
      _isMuted = true;

      _controller = controller;
      _isInitializing = false;

      if (mounted && !_isDisposed) {
        setState(() {
          _isInitialized = true;
        });
        _checkAndAutoPlay();
      } else {
        controller.dispose();
        _controller = null;
        _isInitialized = false;
      }
    } catch (e) {
      _isInitializing = false;
      debugPrint("Error initializing feed video player: $e");
      if (mounted && !_isDisposed) {
        setState(() {});
      }
    }
  }

  void _playVideo() {
    if (_isDisposed || !mounted || _controller == null || !_isInitialized) return;
    
    // Pause any other video in the feed first (Single playback coordinator)
    if (_currentlyPlaying != null && _currentlyPlaying != this) {
      _currentlyPlaying?._pauseVideo();
    }
    _currentlyPlaying = this;

    _controller!.setVolume(_isMuted ? 0.0 : 1.0);
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
    if (_currentlyPlaying == this) {
      _currentlyPlaying = null;
    }
    if (_controller == null || !_isInitialized) return;
    try {
      _controller!.setVolume(0.0); // Mute immediately to stop any audio residue
      if (_controller!.value.isPlaying) {
        _controller!.pause();
      }
    } catch (e) {
      debugPrint("Error pausing video player: $e");
    }
    if (mounted && _isPlaying) {
      setState(() {
        _isPlaying = false;
      });
    }
  }

  void _disposeController() {
    if (_currentlyPlaying == this) {
      _currentlyPlaying = null;
    }
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
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
    MainWrapperState.currentTabNotifier.removeListener(_onTabChanged);
    if (_isSubscribedToRoute) {
      try {
        routeObserver.unsubscribe(this);
      } catch (_) {}
    }
    _disposeController();
    super.dispose();
  }

  void _toggleMute() {
    if (_controller == null || !_isInitialized || _isDisposed) return;
    setState(() {
      _isMuted = !_isMuted;
      if (_isPlaying) {
        _controller!.setVolume(_isMuted ? 0.0 : 1.0);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final thumb = _thumbnailUrl;

    return VisibilityDetector(
      key: Key('feed_video_${widget.videoUrl}_${identityHashCode(this)}'),
      onVisibilityChanged: (VisibilityInfo info) {
        if (!mounted || _isDisposed) return;
        _visibleFraction = info.visibleFraction;
        if (_visibleFraction < 0.5) {
          _pauseVideo();
        } else {
          _checkAndAutoPlay();
        }
      },
      child: GestureDetector(
        onTap: () {
          if (_controller != null && _isInitialized) {
            if (_isPlaying) {
              _userPaused = true;
              _pauseVideo();
            } else {
              _userPaused = false;
              _playVideo();
            }
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => FullScreenVideoPlayer(videoUrl: widget.videoUrl),
              ),
            );
          }
        },
        onDoubleTap: () {
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
              _checkAndAutoPlay();
            }
          });
        },
        child: Container(
          height: 480,
          width: double.infinity,
          color: Colors.black,
          child: Stack(
            alignment: Alignment.center,
            fit: StackFit.expand,
            children: [
              // 1. Poster thumbnail preview image (shown instantly while loading or if video fails)
              if (thumb.isNotEmpty)
                Image.network(
                  thumb,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: 480,
                  errorBuilder: (context, error, stackTrace) => Container(color: Colors.black87),
                ),

              // 2. Live Video Player when initialized
              if (_isInitialized && _controller != null)
                Positioned.fill(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    clipBehavior: Clip.antiAlias,
                    child: SizedBox(
                      width: _controller!.value.size.width > 0 ? _controller!.value.size.width : 480,
                      height: _controller!.value.size.height > 0 ? _controller!.value.size.height : 480,
                      child: VideoPlayer(_controller!),
                    ),
                  ),
                ),

              // 3. Loading spinner if not yet initialized and no thumbnail
              if (!_isInitialized && thumb.isEmpty)
                const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),

              // 4. Play button overlay when paused
              if (_isInitialized && !_isPlaying)
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.55),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 44,
                    ),
                  ),
                ),

              // 5. Audio mute/unmute toggle in bottom-right
              if (_isInitialized && _controller != null)
                Positioned(
                  bottom: 14,
                  right: 14,
                  child: GestureDetector(
                    onTap: _toggleMute,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
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

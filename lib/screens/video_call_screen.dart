import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';

class VideoCallScreen extends StatefulWidget {
  final String callerName;
  final String callerAvatar;

  const VideoCallScreen({
    super.key,
    required this.callerName,
    required this.callerAvatar,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  CameraController? _cameraController;
  bool isCameraInitialized = false;
  bool isMuted = false;
  bool isVideoOff = false;
  bool isFrontCamera = true;
  List<CameraDescription> cameras = [];

  bool isConnected = false;
  int durationInSeconds = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _initCamera();
    
    // Simulate connection after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          isConnected = true;
        });
        _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (mounted) {
            setState(() {
              durationInSeconds++;
            });
          }
        });
      }
    });
  }

  Future<void> _initCamera() async {
    try {
      cameras = await availableCameras();
      if (cameras.isNotEmpty) {
        // Try to find front camera, fallback to first available
        final frontCamera = cameras.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.front,
          orElse: () => cameras.first,
        );
        isFrontCamera = frontCamera.lensDirection == CameraLensDirection.front;

        _cameraController = CameraController(
          frontCamera,
          ResolutionPreset.high,
          enableAudio: true,
        );

        await _cameraController!.initialize();
        if (mounted) {
          setState(() {
            isCameraInitialized = true;
          });
        }
      }
    } catch (e) {
      debugPrint('Error initializing camera: $e');
    }
  }

  Future<void> _switchCamera() async {
    if (cameras.length < 2 || _cameraController == null) return;
    
    isFrontCamera = !isFrontCamera;
    final newCamera = cameras.firstWhere(
      (c) => c.lensDirection == (isFrontCamera ? CameraLensDirection.front : CameraLensDirection.back),
      orElse: () => cameras.first,
    );
    
    final oldController = _cameraController;
    _cameraController = CameraController(
      newCamera,
      ResolutionPreset.high,
      enableAudio: true,
    );

    try {
      await _cameraController!.initialize();
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error switching camera: $e');
    }
    
    await oldController?.dispose();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _cameraController?.dispose();
    super.dispose();
  }

  String get formattedDuration {
    final minutes = (durationInSeconds / 60).floor().toString().padLeft(2, '0');
    final seconds = (durationInSeconds % 60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background - Main Video (Simulate remote caller's video or DP taking up full screen)
          SizedBox.expand(
            child: Stack(
              fit: StackFit.expand,
              children: [
                widget.callerAvatar.startsWith('http')
                    ? CachedNetworkImage(
                        imageUrl: widget.callerAvatar,
                        fit: BoxFit.cover,
                        errorWidget: (context, url, error) => const Icon(Icons.person, color: Colors.white, size: 80),
                      )
                    : Image.asset(
                        widget.callerAvatar.isNotEmpty ? widget.callerAvatar : "assets/images/user1.jpg",
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stack) => const Icon(Icons.person, color: Colors.white, size: 80),
                      ),
                // Add a slight dark overlay if not connected
                if (!isConnected)
                  Container(
                    color: Colors.black54,
                    child: const Center(
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    ),
                  )
              ],
            ),
          ),
          // Gradient Overlay at Top & Bottom for readability
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.6),
                  Colors.transparent,
                  Colors.transparent,
                  Colors.black.withOpacity(0.8),
                ],
                stops: const [0.0, 0.2, 0.7, 1.0],
              ),
            ),
          ),

          // Top Header (Back button, Name, Duration)
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 36),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.callerName,
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isConnected ? formattedDuration : "Ringing...",
                            style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // PiP View (Local User Front Camera)
          Positioned(
            top: MediaQuery.of(context).padding.top + 70,
            right: 16,
            child: Container(
              width: 110,
              height: 160,
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white24, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: (isCameraInitialized && !isVideoOff && _cameraController != null)
                    ? FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: _cameraController!.value.previewSize?.height ?? 1,
                          height: _cameraController!.value.previewSize?.width ?? 1,
                          child: CameraPreview(_cameraController!),
                        ),
                      )
                    : Container(
                        color: const Color(0xff2A2A35),
                        child: const Center(
                          child: Icon(Icons.videocam_off_rounded, color: Colors.white54, size: 30),
                        ),
                      ),
              ),
            ),
          ),

          // Bottom Controls
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 24.0, left: 32, right: 32),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildControlButton(
                      icon: Icons.flip_camera_ios_rounded,
                      isActive: false,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _switchCamera();
                      },
                    ),
                    _buildControlButton(
                      icon: isVideoOff ? Icons.videocam_off_rounded : Icons.videocam_rounded,
                      isActive: isVideoOff,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() {
                          isVideoOff = !isVideoOff;
                        });
                      },
                    ),
                    _buildControlButton(
                      icon: isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                      isActive: isMuted,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() {
                          isMuted = !isMuted;
                        });
                      },
                    ),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.heavyImpact();
                        Navigator.pop(context);
                      },
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: const BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.call_end_rounded, color: Colors.white, size: 28),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({required IconData icon, required bool isActive, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.white24,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: isActive ? Colors.black : Colors.white, size: 24),
      ),
    );
  }
}

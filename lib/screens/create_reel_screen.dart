import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hidely_new/services/media_download_service.dart';
import 'post_details_screen.dart';

class CreateReelScreen extends StatefulWidget {
  const CreateReelScreen({super.key});

  @override
  State<CreateReelScreen> createState() => _CreateReelScreenState();
}

class _CreateReelScreenState extends State<CreateReelScreen> {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  int _selectedCameraIndex = 0;
  bool _isCameraInitialized = false;

  // Recording State
  bool _isRecording = false;
  int _recordedSeconds = 0;
  Timer? _recordingTimer;

  // Timer / Duration options: 15s, 30s, 60s (Max 60 sec)
  int _selectedLength = 60;
  final List<int> _availableLengths = [15, 30, 60];

  // Torch Flash state
  bool _isFlashOn = false;

  // Professional Cinematic LUTs
  int _selectedLutIndex = 0;
  late PageController _pageController;

  final List<Map<String, dynamic>> _luts = [
    {
      "name": "Normal",
      "color": Colors.transparent,
      "matrix": <double>[
        1.0, 0.0, 0.0, 0.0, 0.0,
        0.0, 1.0, 0.0, 0.0, 0.0,
        0.0, 0.0, 1.0, 0.0, 0.0,
        0.0, 0.0, 0.0, 1.0, 0.0,
      ]
    },
    {
      "name": "Teal & Orange",
      "color": const Color(0xff008080).withOpacity(0.4),
      "matrix": <double>[
        1.15, 0.0, 0.10, 0.0, 10.0,
        0.0, 1.05, 0.05, 0.0, 5.0,
        -0.05, 0.10, 1.25, 0.0, 15.0,
        0.0, 0.0, 0.0, 1.0, 0.0,
      ]
    },
    {
      "name": "Vintage 35mm",
      "color": Colors.amber.withOpacity(0.35),
      "matrix": <double>[
        1.20, 0.10, 0.05, 0.0, 15.0,
        0.10, 1.05, 0.05, 0.0, 10.0,
        0.05, 0.10, 0.85, 0.0, 5.0,
        0.0, 0.0, 0.0, 1.0, 0.0,
      ]
    },
    {
      "name": "Moody Dark",
      "color": const Color(0xff2D3748).withOpacity(0.4),
      "matrix": <double>[
        0.90, 0.10, 0.00, 0.0, -5.0,
        0.05, 0.85, 0.05, 0.0, -5.0,
        0.00, 0.10, 1.10, 0.0, 0.0,
        0.0, 0.0, 0.0, 1.0, 0.0,
      ]
    },
    {
      "name": "Golden Hour",
      "color": Colors.orangeAccent.withOpacity(0.35),
      "matrix": <double>[
        1.30, 0.10, -0.10, 0.0, 20.0,
        0.10, 1.15, 0.00, 0.0, 10.0,
        -0.10, 0.00, 0.75, 0.0, -10.0,
        0.0, 0.0, 0.0, 1.0, 0.0,
      ]
    },
    {
      "name": "Emerald Forest",
      "color": const Color(0xff10B981).withOpacity(0.35),
      "matrix": <double>[
        0.90, 0.15, 0.00, 0.0, -5.0,
        0.05, 1.25, 0.10, 0.0, 15.0,
        0.00, 0.10, 1.05, 0.0, 5.0,
        0.0, 0.0, 0.0, 1.0, 0.0,
      ]
    },
    {
      "name": "Cyberpunk Neon",
      "color": Colors.deepPurpleAccent.withOpacity(0.4),
      "matrix": <double>[
        1.20, 0.00, 0.30, 0.0, 15.0,
        0.10, 0.80, 0.20, 0.0, -10.0,
        0.30, 0.10, 1.40, 0.0, 20.0,
        0.0, 0.0, 0.0, 1.0, 0.0,
      ]
    },
    {
      "name": "Monochrome Noir",
      "color": Colors.grey.shade800,
      "matrix": <double>[
        0.30, 0.59, 0.11, 0.0, 0.0,
        0.30, 0.59, 0.11, 0.0, 0.0,
        0.30, 0.59, 0.11, 0.0, 0.0,
        0.0, 0.0, 0.0, 1.0, 0.0,
      ]
    },
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.24, initialPage: 0);
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        await _setupCamera(_selectedCameraIndex);
      }
    } catch (e) {
      debugPrint("Camera Initialization Error: $e");
    }
  }

  Future<void> _setupCamera(int index) async {
    if (_cameras == null || _cameras!.isEmpty) return;
    setState(() => _isCameraInitialized = false);
    await _cameraController?.dispose();

    _cameraController = CameraController(
      _cameras![index],
      ResolutionPreset.high,
      enableAudio: true,
    );

    try {
      await _cameraController!.initialize();
      if (mounted) {
        setState(() => _isCameraInitialized = true);
      }
    } catch (e) {
      debugPrint("Camera Setup Error: $e");
    }
  }

  Future<void> _toggleCamera() async {
    if (_cameras == null || _cameras!.length < 2 || _isRecording) return;
    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras!.length;
    await _setupCamera(_selectedCameraIndex);
  }

  Future<void> _toggleFlash() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    try {
      _isFlashOn = !_isFlashOn;
      await _cameraController!.setFlashMode(
        _isFlashOn ? FlashMode.torch : FlashMode.off,
      );
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint("Flash Error: $e");
    }
  }

  void _cycleLength() {
    if (_isRecording) return;
    setState(() {
      final currentIndex = _availableLengths.indexOf(_selectedLength);
      final nextIndex = (currentIndex + 1) % _availableLengths.length;
      _selectedLength = _availableLengths[nextIndex];
    });
  }

  Future<void> _toggleRecording() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;

    if (_isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    try {
      await _cameraController!.startVideoRecording();
      setState(() {
        _isRecording = true;
        _recordedSeconds = 0;
      });

      _recordingTimer?.cancel();
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) return;
        setState(() {
          _recordedSeconds++;
        });

        if (_recordedSeconds >= _selectedLength) {
          _stopRecording();
        }
      });
    } catch (e) {
      debugPrint("Error starting recording: $e");
    }
  }

  Future<void> _stopRecording() async {
    _recordingTimer?.cancel();
    if (!_isRecording) return;

    try {
      final XFile file = await _cameraController!.stopVideoRecording();
      setState(() {
        _isRecording = false;
      });

      if (mounted) {
        final navigator = Navigator.of(context);
        // Auto-save recorded video to phone gallery
        await MediaDownloadService.downloadMediaToGallery(context, file.path);

        if (!mounted) return;
        navigator.push(
          MaterialPageRoute(
            builder: (context) => PostDetailsScreen(selectedImage: File(file.path)),
          ),
        );
      }
    } catch (e) {
      debugPrint("Error stopping recording: $e");
      setState(() {
        _isRecording = false;
      });
    }
  }

  Future<void> _pickFromGallery() async {
    if (_isRecording) return;
    final ImagePicker picker = ImagePicker();
    final XFile? media = await picker.pickVideo(source: ImageSource.gallery);
    if (media != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PostDetailsScreen(selectedImage: File(media.path)),
        ),
      );
    }
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _cameraController?.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double progress = _selectedLength > 0 ? (_recordedSeconds / _selectedLength).clamp(0.0, 1.0) : 0.0;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Camera Live Preview with Selected Cinematic LUT Filter
            if (_isCameraInitialized && _cameraController != null)
              FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _cameraController!.value.previewSize?.height ?? 1,
                  height: _cameraController!.value.previewSize?.width ?? 1,
                  child: ColorFiltered(
                    colorFilter: ColorFilter.matrix(_luts[_selectedLutIndex]['matrix'] as List<double>),
                    child: CameraPreview(_cameraController!),
                  ),
                ),
              )
            else
              Container(
                color: const Color(0xff111111),
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),

            // 2. Recording Top Progress Bar
            if (_isRecording)
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                left: 16,
                right: 16,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 4,
                    backgroundColor: Colors.white30,
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.redAccent),
                  ),
                ),
              ),

            // 3. Top Action Controls Header
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Close Screen Button
                        GestureDetector(
                          onTap: () {
                            if (_isRecording) {
                              _stopRecording();
                            } else {
                              Navigator.pop(context);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.35),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close_rounded, color: Colors.white, size: 26),
                          ),
                        ),

                        // Center: Recording Time Counter
                        if (_isRecording)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.redAccent,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              "${_recordedSeconds}s / ${_selectedLength}s",
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.videocam_rounded, color: Colors.white, size: 16),
                                SizedBox(width: 6),
                                Text(
                                  "Reel Camera",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Top Controls (Flash Toggle)
                        GestureDetector(
                          onTap: _toggleFlash,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _isFlashOn ? Colors.amber : Colors.black.withOpacity(0.35),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _isFlashOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                              color: _isFlashOn ? Colors.black : Colors.white,
                              size: 22,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // 4. Right Side Toolbar (Flip Camera, Timer Length)
            Positioned(
              right: 16,
              top: MediaQuery.of(context).size.height * 0.22,
              child: Column(
                children: [
                  // Flip Camera
                  _buildSideToolButton(
                    icon: Icons.flip_camera_ios_rounded,
                    label: "Flip",
                    onTap: _toggleCamera,
                  ),
                  const SizedBox(height: 20),

                  // Max Timer Length Selector (15s, 30s, 60s max)
                  _buildSideToolButton(
                    labelWidget: Text(
                      "${_selectedLength}s",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    label: "Timer",
                    onTap: _cycleLength,
                  ),
                ],
              ),
            ),

            // 5. Active LUT Filter Name Indicator Pill
            Positioned(
              bottom: 175,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.auto_awesome, color: Colors.amberAccent, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        _luts[_selectedLutIndex]['name'] as String,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 6. Cinematic LUT Filter Carousel & Controls
            Positioned(
              bottom: 65,
              left: 0,
              right: 0,
              child: SizedBox(
                height: 90,
                child: PageView.builder(
                  controller: _pageController,
                  physics: const BouncingScrollPhysics(),
                  onPageChanged: (index) {
                    if (index < _luts.length) {
                      setState(() => _selectedLutIndex = index);
                    }
                  },
                  itemCount: _luts.length,
                  itemBuilder: (context, index) {
                    final isSelected = index == _selectedLutIndex;
                    final lutName = _luts[index]['name'] as String;

                    return GestureDetector(
                      onTap: () {
                        _pageController.animateToPage(
                          index,
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeInOut,
                        );
                      },
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: isSelected ? 62 : 48,
                            height: isSelected ? 62 : 48,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected ? Colors.white : Colors.white54,
                                width: isSelected ? 3 : 1.5,
                              ),
                              boxShadow: isSelected
                                  ? [BoxShadow(color: Colors.white.withOpacity(0.4), blurRadius: 8)]
                                  : null,
                            ),
                            child: ClipOval(
                              child: Container(
                                color: index == 0 ? Colors.white30 : _luts[index]['color'],
                                child: Center(
                                  child: Text(
                                    lutName[0],
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: isSelected ? 18 : 14,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            lutName,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.white70,
                              fontSize: isSelected ? 11 : 9.5,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),

            // 7. Bottom Record Button & Gallery Media Picker
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 12,
              left: 30,
              right: 30,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Gallery Video/Photo Upload Button
                  GestureDetector(
                    onTap: _pickFromGallery,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white54, width: 1.5),
                      ),
                      child: const Icon(Icons.photo_library_rounded, color: Colors.white, size: 22),
                    ),
                  ),

                  // Record Reel Button
                  GestureDetector(
                    onTap: _toggleRecording,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _isRecording ? Colors.redAccent : Colors.white,
                          width: 4,
                        ),
                      ),
                      child: Center(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: _isRecording ? 32 : 62,
                          height: _isRecording ? 32 : 62,
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            borderRadius: BorderRadius.circular(_isRecording ? 8 : 40),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Placeholder symmetry spacing
                  const SizedBox(width: 44),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSideToolButton({
    IconData? icon,
    Widget? labelWidget,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.45),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24),
            ),
            child: Center(
              child: labelWidget ?? Icon(icon, color: Colors.white, size: 22),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
              shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
            ),
          ),
        ],
      ),
    );
  }
}
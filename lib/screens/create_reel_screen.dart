import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'post_details_screen.dart';
import 'package:video_player/video_player.dart';

class CreateReelScreen extends StatefulWidget {
  const CreateReelScreen({super.key});

  @override
  State<CreateReelScreen> createState() => _CreateReelScreenState();
}

class _CreateReelScreenState extends State<CreateReelScreen> {
  int _selectedLength = 15;
  File? _recordedVideo;
  VideoPlayerController? _previewVideoController;
  bool _isPreviewInitialized = false;
  
  // Camera state controllers
  List<CameraDescription>? _cameras;
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isRecording = false;
  bool _showEffects = false;
  bool _noCameraFound = false;

  final ImagePicker _picker = ImagePicker();

  // Custom Grading Parameters
  double _customRed = 1.0;
  double _customGreen = 1.0;
  double _customBlue = 1.0;
  double _customContrast = 1.0;

  // Calculates the color filter matrix dynamically based on custom slider values
  List<double> get _customMatrix {
    double c = _customContrast;
    double t = (1.0 - c) / 2.0;
    return [
      _customRed * c, 0.0, 0.0, 0.0, t * 255.0,
      0.0, _customGreen * c, 0.0, 0.0, t * 255.0,
      0.0, 0.0, _customBlue * c, 0.0, t * 255.0,
      0.0, 0.0, 0.0, 1.0, 0.0,
    ];
  }

  // Cinematic LUT Matrix Filters List
  final List<Map<String, dynamic>> _lutFilters = [
    {
      "name": "Normal",
      "color": Colors.white,
      "matrix": [
        1.0, 0.0, 0.0, 0.0, 0.0,
        0.0, 1.0, 0.0, 0.0, 0.0,
        0.0, 0.0, 1.0, 0.0, 0.0,
        0.0, 0.0, 0.0, 1.0, 0.0,
      ]
    },
    {
      "name": "Golden",
      "color": Colors.amber,
      "matrix": [
        1.1, 0.1, 0.0, 0.0, 10.0,
        0.0, 1.0, 0.0, 0.0, 5.0,
        0.0, 0.0, 0.8, 0.0, -10.0,
        0.0, 0.0, 0.0, 1.0, 0.0,
      ]
    },
    {
      "name": "Cyber",
      "color": Colors.cyan,
      "matrix": [
        0.8, 0.0, 0.0, 0.0, -10.0,
        0.0, 1.0, 0.1, 0.0, 10.0,
        0.0, 0.1, 1.2, 0.0, 20.0,
        0.0, 0.0, 0.0, 1.0, 0.0,
      ]
    },
    {
      "name": "Sepia",
      "color": Colors.orangeAccent,
      "matrix": [
        0.393, 0.769, 0.189, 0.0, 0.0,
        0.349, 0.686, 0.168, 0.0, 0.0,
        0.272, 0.534, 0.131, 0.0, 0.0,
        0.0,   0.0,   0.0,   1.0, 0.0,
      ]
    },
    {
      "name": "Drama",
      "color": Colors.redAccent,
      "matrix": [
        1.2, -0.1, -0.1, 0.0, 0.0,
        -0.1, 1.2, -0.1, 0.0, 0.0,
        -0.1, -0.1, 1.2, 0.0, 0.0,
        0.0,   0.0,   0.0,   1.0, 0.0,
      ]
    },
    {
      "name": "Monochrome",
      "color": Colors.grey,
      "matrix": [
        0.2126, 0.7152, 0.0722, 0.0, 0.0,
        0.2126, 0.7152, 0.0722, 0.0, 0.0,
        0.2126, 0.7152, 0.0722, 0.0, 0.0,
        0.0,    0.0,    0.0,    1.0, 0.0,
      ]
    },
    {
      "name": "Custom",
      "color": Colors.purpleAccent,
      "matrix": null, // Custom dynamic matrix values
    },
  ];

  int _selectedLutIndex = 0;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final cameraStatus = await Permission.camera.request();
    final micStatus = await Permission.microphone.request();

    if (cameraStatus.isDenied || cameraStatus.isPermanentlyDenied ||
        micStatus.isDenied || micStatus.isPermanentlyDenied) {
      if (mounted) {
        setState(() {
          _noCameraFound = true;
        });
        _showCustomSnackBar("Camera & Microphone permissions are required to create a reel.", isError: true);
      }
      return;
    }

    try {
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        _cameraController = CameraController(
          _cameras![0], // default back camera
          ResolutionPreset.high,
          enableAudio: true,
        );
        await _cameraController!.initialize();
        if (mounted) {
          setState(() {
            _isCameraInitialized = true;
            _noCameraFound = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _noCameraFound = true;
          });
        }
      }
    } catch (e) {
      debugPrint("Error initializing camera: $e");
      if (mounted) {
        setState(() {
          _noCameraFound = true;
        });
      }
      _showCustomSnackBar("Camera initialization failed. Please check permissions.", isError: true);
    }
  }

  Future<File> _ensureMp4Extension(File file) async {
    final path = file.path;
    final ext = path.split('.').last.toLowerCase();
    if (['mp4', 'mov', 'avi', 'mkv', 'mpeg'].contains(ext)) {
      return file;
    }
    try {
      final String dir = file.parent.path;
      final String newPath = '$dir/recorded_reel_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final File newFile = await file.copy(newPath);
      await file.delete();
      return newFile;
    } catch (e) {
      debugPrint("Error renaming video file to mp4: $e");
      return file;
    }
  }

  Future<void> _toggleVideoRecording() async {
    if (_cameraController == null || !_isCameraInitialized) return;

    if (_isRecording) {
      // Stop recording
      try {
        final XFile videoFile = await _cameraController!.stopVideoRecording();
        final File processedVideo = await _ensureMp4Extension(File(videoFile.path));
        setState(() {
          _isRecording = false;
          _recordedVideo = processedVideo;
        });
        _showCustomSnackBar("Reel recorded successfully!", isError: false);
        _setupVideoPreview();
      } catch (e) {
        debugPrint("Error stopping video recording: $e");
        _showCustomSnackBar("Error saving video recording.", isError: true);
      }
    } else {
      // Clear previous recording and start new
      try {
        setState(() {
          _recordedVideo = null;
          _isRecording = true;
        });
        await _cameraController!.startVideoRecording();
        
        // Auto-stop after _selectedLength duration
        Future.delayed(Duration(seconds: _selectedLength), () {
          if (mounted && _isRecording) {
            _toggleVideoRecording();
          }
        });
      } catch (e) {
        debugPrint("Error starting video recording: $e");
        setState(() {
          _isRecording = false;
        });
        _showCustomSnackBar("Could not start video recording.", isError: true);
      }
    }
  }

  Future<void> _pickVideoFromGallery() async {
    if (_isRecording) return;
    try {
      final XFile? media = await _picker.pickMedia();
      if (media != null) {
        final path = media.path.toLowerCase();
        final isVideo = path.endsWith('.mp4') || path.endsWith('.mov') || path.endsWith('.avi') || path.endsWith('.mkv');
        if (!isVideo) {
          _showCustomSnackBar("Reels only support videos. Please select a video.", isError: true);
          return;
        }

        final File processedVideo = await _ensureMp4Extension(File(media.path));
        setState(() {
          _recordedVideo = processedVideo;
        });
        _showCustomSnackBar("Video selected from gallery!", isError: false);
        _setupVideoPreview();
      }
    } catch (e) {
      debugPrint("Error picking media from gallery: $e");
      _showCustomSnackBar("Could not access device gallery.", isError: true);
    }
  }

  void _showCustomSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? Colors.redAccent.shade700 : const Color(0xff5D3EBC),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _previewVideoController?.dispose();
    super.dispose();
  }

  Future<void> _setupVideoPreview() async {
    if (_recordedVideo == null) return;
    
    if (_previewVideoController != null) {
      await _previewVideoController!.dispose();
      _previewVideoController = null;
    }
    
    if (mounted) {
      setState(() {
        _isPreviewInitialized = false;
      });
    }

    _previewVideoController = VideoPlayerController.file(_recordedVideo!);
    try {
      await _previewVideoController!.initialize();
      await _previewVideoController!.setLooping(true);
      await _previewVideoController!.play();
      if (mounted) {
        setState(() {
          _isPreviewInitialized = true;
        });
      }
    } catch (e) {
      debugPrint("Error initializing video preview: $e");
    }
  }

  Future<void> _discardRecordedVideo() async {
    if (_previewVideoController != null) {
      await _previewVideoController!.dispose();
      _previewVideoController = null;
    }
    if (mounted) {
      setState(() {
        _recordedVideo = null;
        _isPreviewInitialized = false;
      });
    }
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
            // --- BACKGROUND: FULL SCREEN LIVE CAMERA VIEWFINDER WITH CINEMATIC LUT FILTER ---
            Positioned.fill(
              child: _recordedVideo != null && _isPreviewInitialized && _previewVideoController != null
                  ? SizedBox.expand(
                      child: FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: _previewVideoController!.value.size.width,
                          height: _previewVideoController!.value.size.height,
                          child: VideoPlayer(_previewVideoController!),
                        ),
                      ),
                    )
                  : (_isCameraInitialized && _cameraController != null
                      ? ColorFiltered(
                          colorFilter: ColorFilter.matrix(
                            _selectedLutIndex == 6
                                ? _customMatrix
                                : List<double>.from(_lutFilters[_selectedLutIndex]["matrix"]),
                          ),
                          child: ClipRect(
                            child: SizedBox.expand(
                              child: FittedBox(
                                fit: BoxFit.cover,
                                child: SizedBox(
                                  width: _cameraController!.value.previewSize!.height,
                                  height: _cameraController!.value.previewSize!.width,
                                  child: CameraPreview(_cameraController!),
                                ),
                              ),
                            ),
                          ),
                        )
                      : (_noCameraFound
                          ? Container(
                              color: Colors.black,
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.videocam_off_outlined, color: Colors.white70, size: 64),
                                    const SizedBox(height: 16),
                                    const Text(
                                      "Camera not available",
                                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 8),
                                    const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 32),
                                      child: Text(
                                        "Please upload a video from your gallery instead",
                                        textAlign: TextAlign.center,
                                        style: TextStyle(color: Colors.white70, fontSize: 13),
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    ElevatedButton.icon(
                                      onPressed: _pickVideoFromGallery,
                                      icon: const Icon(Icons.photo_library_outlined, color: Colors.white),
                                      label: const Text("Open Gallery", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xff5D3EBC),
                                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(24),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : Container(
                              color: Colors.black,
                              child: const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    CircularProgressIndicator(color: Colors.white),
                                    SizedBox(height: 16),
                                    Text(
                                      "Connecting to Camera...",
                                      style: TextStyle(color: Colors.white70, fontSize: 15),
                                    ),
                                  ],
                                ),
                              ),
                            ))),
            ),

            // --- SEMI-TRANSLUCENT VIGNETTE OVERLAY ---
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.4),
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withOpacity(0.6),
                    ],
                    stops: const [0.0, 0.2, 0.8, 1.0],
                  ),
                ),
              ),
            ),

            // --- FOREGROUND ELEMENTS WRAPPED IN SAFEAREA ---
            SafeArea(
              child: Column(
                children: [
                  // --- 1. TOP PREMIUM APP BAR HEADER ---
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                         GestureDetector(
                          onTap: () {
                            if (_recordedVideo != null) {
                              _discardRecordedVideo();
                            } else {
                              Navigator.pop(context);
                            }
                          },
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.4),
                              shape: BoxShape.circle,
                            ),
                            child: Center(child: Image.asset('assets/images/back_icon.png', color: Colors.white, width: 18.0, height: 18.0)),
                          ),
                        ),
                        // Title / Recording indicator status
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_isRecording) ...[
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                              ],
                              Text(
                                _isRecording
                                    ? "RECORDING"
                                    : (_recordedVideo != null ? "Preview" : "New Reel"),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          height: 38,
                          child: ElevatedButton(
                            onPressed: () {
                              if (_recordedVideo != null) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => PostDetailsScreen(
                                      selectedImage: _recordedVideo!,
                                    ),
                                  ),
                                );
                              } else {
                                _showCustomSnackBar("Please record or select a video first.", isError: true);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xff5D3EBC),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                            ),
                            child: const Text(
                              "Share",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // --- 2. CAMERA CONSOLE SYSTEM INTERACTIVE OVERLAYS ---
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Stack(
                        children: [
                           // LEFT RAIL PANEL BUTTONS
                          if (_recordedVideo == null)
                            Positioned(
                              left: 12,
                              top: MediaQuery.of(context).size.height * 0.05,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildVerticalRailActionButton(Icons.music_note, "Audio", onTap: () {}),
                                  const SizedBox(height: 20),
                                  _buildVerticalRailCustomButton(
                                    child: Text(
                                      "$_selectedLength",
                                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                                    ),
                                    label: "Length",
                                    onTap: () {
                                      if (_isRecording) return;
                                      setState(() {
                                        _selectedLength = _selectedLength == 15 ? 30 : (_selectedLength == 30 ? 60 : 15);
                                      });
                                      _showCustomSnackBar("Reel duration limit set to $_selectedLength seconds.", isError: false);
                                    },
                                  ),
                                  const SizedBox(height: 20),
                                  _buildVerticalRailActionButton(Icons.speed, "Speed", onTap: () {}),
                                  const SizedBox(height: 20),
                                  _buildVerticalRailActionButton(Icons.timer_outlined, "Timer", onTap: () {}),
                                ],
                              ),
                            ),

                          // RIGHT RAIL PANEL: CINEMATIC LUT FILTERS
                          if (_showEffects && _recordedVideo == null)
                            Positioned(
                              right: 12,
                              top: MediaQuery.of(context).size.height * 0.01,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: List.generate(_lutFilters.length, (index) {
                                  final filter = _lutFilters[index];
                                  final isSelected = index == _selectedLutIndex;
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12.0),
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _selectedLutIndex = index;
                                        });
                                      },
                                      child: Column(
                                        children: [
                                          Container(
                                            width: 44,
                                            height: 44,
                                            decoration: BoxDecoration(
                                              color: isSelected 
                                                  ? const Color(0xff5D3EBC)
                                                  : Colors.black.withOpacity(0.4),
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: isSelected ? Colors.white : Colors.white30,
                                                width: isSelected ? 2 : 1,
                                              ),
                                            ),
                                            child: Center(
                                              child: Icon(
                                                index == 6 ? Icons.tune_rounded : Icons.filter_hdr_outlined, 
                                                color: filter["color"] as Color, 
                                                size: 18
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            filter["name"] as String,
                                            style: TextStyle(
                                              color: Colors.white, 
                                              fontSize: 10, 
                                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                              shadows: const [Shadow(color: Colors.black, blurRadius: 4)],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            ),

                          // CUSTOM DYNAMIC LUT ADJUSTMENT SLIDER CONTROL PANEL
                          if (_showEffects && _selectedLutIndex == 6 && !_isRecording)
                            Positioned(
                              left: 12,
                              right: 12,
                              bottom: 130 + MediaQuery.of(context).padding.bottom,
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.75),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(color: Colors.white.withOpacity(0.12), width: 1),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Row(
                                      children: [
                                        Icon(Icons.tune_rounded, color: Colors.purpleAccent, size: 16),
                                        SizedBox(width: 8),
                                        Text(
                                          "Cinematic Grade Studio",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    _buildLutSlider("Red Channel", _customRed, 0.2, 2.0, Colors.red, (val) {
                                      setState(() => _customRed = val);
                                    }),
                                    _buildLutSlider("Green Channel", _customGreen, 0.2, 2.0, Colors.green, (val) {
                                      setState(() => _customGreen = val);
                                    }),
                                    _buildLutSlider("Blue Channel", _customBlue, 0.2, 2.0, Colors.blue, (val) {
                                      setState(() => _customBlue = val);
                                    }),
                                    _buildLutSlider("Contrast", _customContrast, 0.5, 2.0, Colors.purpleAccent, (val) {
                                      setState(() => _customContrast = val);
                                    }),
                                  ],
                                ),
                              ),
                            ),



                          // BOTTOM BAR TRIGGER CONTROL STRIP
                          if (_recordedVideo == null)
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 24 + MediaQuery.of(context).padding.bottom,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  // GALLERY ACCESS BUTTON
                                  _buildBottomUtilityLauncher(
                                    child: const DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: Colors.black54,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(Icons.photo_library_outlined, color: Colors.white, size: 20),
                                    ),
                                    label: "Gallery",
                                    onTap: _pickVideoFromGallery,
                                  ),
                                  
                                  // Capture/Record Trigger button
                                  GestureDetector(
                                    onTap: _toggleVideoRecording,
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      width: _isRecording ? 92 : 84,
                                      height: _isRecording ? 92 : 84,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: _isRecording ? Colors.redAccent : Colors.white,
                                          width: _isRecording ? 6.0 : 4.5,
                                        ),
                                      ),
                                      padding: const EdgeInsets.all(5.5),
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          color: _isRecording ? Colors.redAccent : Colors.white,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ),
                                  ),
                                  
                                  _buildBottomUtilityLauncher(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(colors: [Color(0xff9333EA), Color(0xff6366F1)]),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: _showEffects ? Colors.white : Colors.transparent,
                                          width: 2,
                                        ),
                                      ),
                                      child: const Icon(Icons.auto_awesome, color: Colors.white, size: 22),
                                    ),
                                    label: "Effects",
                                    onTap: () {
                                      setState(() {
                                        _showEffects = !_showEffects;
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
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

  Widget _buildVerticalRailActionButton(IconData icon, String label, {required VoidCallback onTap}) {
    return _buildVerticalRailCustomButton(
      child: Icon(icon, color: Colors.white, size: 24),
      label: label,
      onTap: onTap,
    );
  }

  Widget _buildVerticalRailCustomButton({required Widget child, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.4),
              shape: BoxShape.circle,
            ),
            child: Center(child: child),
          ),
          const SizedBox(height: 5),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold, shadows: [Shadow(color: Colors.black45, blurRadius: 4)])),
        ],
      ),
    );
  }

  Widget _buildBottomUtilityLauncher({required Widget child, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white70, width: 1.5)),
            padding: const EdgeInsets.all(2.0),
            child: child,
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold, shadows: [Shadow(color: Colors.black45, blurRadius: 4)])),
        ],
      ),
    );
  }

  // Helper builder for dynamic custom LUT sliders
  Widget _buildLutSlider(
    String label, 
    double value, 
    double min, 
    double max, 
    Color activeColor, 
    ValueChanged<double> onChanged
  ) {
    return Row(
      children: [
        SizedBox(
          width: 75,
          child: Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: activeColor,
              inactiveTrackColor: Colors.white12,
              thumbColor: Colors.white,
              overlayColor: activeColor.withOpacity(0.2),
              trackHeight: 3.0,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ),
        SizedBox(
          width: 32,
          child: Text(
            value.toStringAsFixed(1),
            textAlign: TextAlign.right,
            style: const TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'monospace'),
          ),
        ),
      ],
    );
  }
}
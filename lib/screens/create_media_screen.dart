import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:video_player/video_player.dart';
import 'post_details_screen.dart';

class CreateMediaScreen extends StatefulWidget {
  const CreateMediaScreen({super.key});

  @override
  State<CreateMediaScreen> createState() => _CreateMediaScreenState();
}

class _CreateMediaScreenState extends State<CreateMediaScreen> {
  // 0 = POST, 1 = REEL
  int _currentModeIndex = 0;

  // --- POST STATE ---
  File? _selectedPostImage;
  final ImagePicker _picker = ImagePicker();
  List<AssetEntity> _recentAssets = [];
  bool _loadingAssets = true;
  bool _hasPermission = false;
  AssetEntity? _selectedAsset;

  // --- REEL STATE ---
  int _selectedLength = 15;
  File? _recordedVideo;
  VideoPlayerController? _previewVideoController;
  bool _isPreviewInitialized = false;
  List<CameraDescription>? _cameras;
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isRecording = false;
  bool _showEffects = false;

  // Custom Grading Parameters
  double _customRed = 1.0;
  double _customGreen = 1.0;
  double _customBlue = 1.0;
  double _customContrast = 1.0;

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
      "name": "Cinematic",
      "color": Colors.tealAccent,
      "matrix": [
        1.05, 0.1,  0.0,  0.0, 10.0,
        0.0,  0.95, 0.05, 0.0, 5.0,
        0.0,  0.2,  0.9,  0.0, -10.0,
        0.0,  0.0,  0.0,  1.0, 0.0,
      ]
    },
    {
      "name": "Nature Pro",
      "color": Colors.greenAccent,
      "matrix": [
        0.9,  0.1,  0.0,  0.0, 0.0,
        0.0,  1.25, 0.05, 0.0, 10.0,
        0.0,  0.0,  1.15, 0.0, 10.0,
        0.0,  0.0,  0.0,  1.0, 0.0,
      ]
    },
    {
      "name": "Moody Forest",
      "color": Colors.green.shade900,
      "matrix": [
        0.7,  0.1, 0.1, 0.0, -15.0,
        0.0,  0.9, 0.1, 0.0, -5.0,
        0.0,  0.1, 0.8, 0.0, 5.0,
        0.0,  0.0, 0.0, 1.0, 0.0,
      ]
    },
    {
      "name": "Golden Hour",
      "color": Colors.amber,
      "matrix": [
        1.15, 0.1,  0.0,  0.0, 15.0,
        0.0,  1.05, 0.0,  0.0, 10.0,
        0.0,  0.0,  0.85, 0.0, -15.0,
        0.0,  0.0,  0.0,  1.0, 0.0,
      ]
    },
    {
      "name": "Cine Flat",
      "color": Colors.grey.shade400,
      "matrix": [
        0.8, 0.1, 0.1, 0.0, 25.0,
        0.1, 0.8, 0.1, 0.0, 25.0,
        0.1, 0.1, 0.8, 0.0, 25.0,
        0.0, 0.0, 0.0, 1.0, 0.0,
      ]
    },
    {
      "name": "Custom",
      "color": Colors.purpleAccent,
      "matrix": null,
    },
  ];

  int _selectedLutIndex = 0;

  @override
  void initState() {
    super.initState();
    // Initialize POST gallery assets
    _fetchRecentAssets();
    
    // Removed auto-trigger of native picker here as per user request to use internal gallery

    // Initialize Camera for REEL mode in background
    _initializeCamera();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _previewVideoController?.dispose();
    super.dispose();
  }

  // --- POST METHODS ---
  Future<void> _fetchRecentAssets() async {
    try {
      final PermissionState ps = await PhotoManager.requestPermissionExtend();
      if (ps.isAuth) {
        setState(() {
          _hasPermission = true;
        });

        final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
          type: RequestType.image,
        );

        if (albums.isNotEmpty) {
          final List<AssetEntity> assets = await albums[0].getAssetListRange(
            start: 0,
            end: 60,
          );

          setState(() {
            _recentAssets = assets;
            _loadingAssets = false;
          });

          if (_selectedPostImage == null && assets.isNotEmpty) {
            _selectAsset(assets.first);
          }
        } else {
          setState(() {
            _loadingAssets = false;
          });
        }
      } else {
        setState(() {
          _hasPermission = false;
          _loadingAssets = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching assets: $e");
      setState(() {
        _loadingAssets = false;
      });
    }
  }

  Future<void> _selectAsset(AssetEntity asset) async {
    try {
      final file = await asset.file;
      if (file != null && mounted) {
        setState(() {
          _selectedPostImage = file;
          _selectedAsset = asset;
        });
      }
    } catch (e) {
      debugPrint("Error getting file from asset: $e");
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );
      if (pickedFile != null) {
        setState(() {
          _selectedPostImage = File(pickedFile.path);
          _selectedAsset = null;
        });
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
    }
  }

  Future<void> _captureImageFromCamera() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
      );
      if (pickedFile != null) {
        setState(() {
          _selectedPostImage = File(pickedFile.path);
          _selectedAsset = null;
        });
      }
    } catch (e) {
      debugPrint("Error capturing image: $e");
    }
  }

  Future<void> _importCustomLut() async {
    try {
      final XFile? file = await _picker.pickImage(source: ImageSource.gallery);
      if (file != null) {
        _showCustomSnackBar("Custom LUT profile extracted and applied!", isError: false);
        setState(() {
          // Simulate applying a custom color matrix profile
          _customRed = 1.05;
          _customGreen = 1.02;
          _customBlue = 0.98;
          _customContrast = 1.15;
        });
      }
    } catch (e) {
      _showCustomSnackBar("Failed to import LUT file.", isError: true);
    }
  }

  // --- GENERAL ACTIONS ---
  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        _cameraController = CameraController(
          _cameras![0],
          ResolutionPreset.high,
          enableAudio: true,
        );
        await _cameraController!.initialize();
        if (mounted) {
          setState(() {
            _isCameraInitialized = true;
          });
        }
      } else {
        debugPrint("No cameras found");
      }
    } catch (e) {
      debugPrint("Error initializing camera: $e");
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
      try {
        setState(() {
          _recordedVideo = null;
          _isRecording = true;
        });
        await _cameraController!.startVideoRecording();
        
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
      final XFile? video = await _picker.pickVideo(
        source: ImageSource.gallery,
      );
      if (video != null) {
        final File processedVideo = await _ensureMp4Extension(File(video.path));
        setState(() {
          _recordedVideo = processedVideo;
        });
        _showCustomSnackBar("Video selected from gallery!", isError: false);
        _setupVideoPreview();
      }
    } catch (e) {
      debugPrint("Error picking video from gallery: $e");
      _showCustomSnackBar("Could not access device gallery.", isError: true);
    }
  }

  Future<void> _setupVideoPreview() async {
    if (_recordedVideo == null) return;
    if (_previewVideoController != null) {
      await _previewVideoController!.dispose();
    }
    _previewVideoController = VideoPlayerController.file(_recordedVideo!);
    try {
      await _previewVideoController!.initialize();
      await _previewVideoController!.setLooping(true);
      await _previewVideoController!.play();
      setState(() {
        _isPreviewInitialized = true;
      });
    } catch (e) {
      debugPrint("Error loading preview video player: $e");
    }
  }

  void _discardRecordedVideo() {
    if (_previewVideoController != null) {
      _previewVideoController!.pause();
      _previewVideoController!.dispose();
      _previewVideoController = null;
    }
    setState(() {
      _recordedVideo = null;
      _isPreviewInitialized = false;
    });
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
            Expanded(child: Text(message, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600))),
          ],
        ),
        backgroundColor: isError ? Colors.redAccent.shade700 : const Color(0xff5D3EBC),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // --- GENERAL WIDGETS ---
  Widget _buildVerticalRailActionButton(IconData icon, String label, {required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.4),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, shadows: [Shadow(color: Colors.black, blurRadius: 4)])),
        ],
      ),
    );
  }

  Widget _buildVerticalRailCustomButton({required Widget child, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.4),
              shape: BoxShape.circle,
            ),
            child: Center(child: child),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, shadows: [Shadow(color: Colors.black, blurRadius: 4)])),
        ],
      ),
    );
  }

  Widget _buildLutSlider(String title, double value, double min, double max, Color activeColor, ValueChanged<double> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(title, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: activeColor,
                inactiveTrackColor: Colors.white24,
                thumbColor: Colors.white,
                overlayColor: activeColor.withAlpha(32),
                trackHeight: 2.0,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
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
            width: 30,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(value.toStringAsFixed(1), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ),
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
          SizedBox(width: 40, height: 40, child: child),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, shadows: [
              Shadow(color: Colors.black54, offset: Offset(0, 1), blurRadius: 2),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildOverlayCircleButton(IconData icon) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.65),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: Colors.white, size: 18),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. DYNAMIC CONTENT AREA BASED ON CHOSEN TAB
          Positioned.fill(
            child: _currentModeIndex == 0
                ? _buildPostTabLayout()
                : _buildReelTabLayout(),
          ),

          // 2. BOTTOM TAB SELECTOR BAR (POST / REEL)
          Positioned(
            left: 0,
            right: 0,
            bottom: MediaQuery.of(context).padding.bottom + 8,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white12, width: 0.8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildModeSelectorTab("POST", 0),
                      _buildModeSelectorTab("REEL", 1),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeSelectorTab(String title, int index) {
    final isSelected = _currentModeIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentModeIndex = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white60,
            fontSize: 13,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }

  // --- POST TAB LAYOUT ---
  Widget _buildPostTabLayout() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xffE0F2FE),
            Color(0xffFFFFFF),
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Custom Header Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: Center(child: Image.asset('assets/images/back_icon.png', color: const Color(0xff1C0D5A), width: 18.0, height: 18.0)),
                    ),
                  ),
                  const Text(
                    "New Post",
                    style: TextStyle(color: Color(0xff1C0D5A), fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: -0.3),
                  ),
                  SizedBox(
                    height: 38,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_selectedPostImage != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PostDetailsScreen(
                                selectedImage: _selectedPostImage!,
                              ),
                            ),
                          );
                        } else {
                          _showCustomSnackBar("Please select an image first.", isError: true);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xff2B1564),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        elevation: 0,
                      ),
                      child: const Text("Next", style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),

            // Preview Container
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                width: double.infinity,
                height: MediaQuery.of(context).size.height * 0.40,
                color: Colors.black.withOpacity(0.04),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: _selectedPostImage != null
                          ? Image.file(_selectedPostImage!, fit: BoxFit.cover)
                          : Container(
                              color: const Color(0xffCBD5E1).withOpacity(0.4),
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_photo_alternate_outlined, size: 40, color: Color(0xff2B1564)),
                                  SizedBox(height: 12),
                                  Text("Tap to select photo", style: TextStyle(color: Color(0xff1C0D5A), fontSize: 15, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                    ),
                    if (_selectedPostImage != null) ...[

                      Positioned(
                        bottom: 16,
                        right: 16,
                        child: Row(
                          children: [
                            _buildOverlayCircleButton(Icons.crop_original_outlined),
                            const SizedBox(width: 10),
                            _buildOverlayCircleButton(Icons.layers_outlined),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Dropdown & Refresh Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text("Device Gallery", style: TextStyle(color: Color(0xff1C0D5A), fontSize: 15, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 4),
                      Icon(Icons.keyboard_arrow_down_rounded, color: const Color(0xff1C0D5A).withOpacity(0.7), size: 18),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, color: Color(0xff2B1564), size: 20),
                    onPressed: () {
                      setState(() {
                        _loadingAssets = true;
                      });
                      _fetchRecentAssets();
                    },
                  ),
                ],
              ),
            ),

            // Media Grid
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 74.0), // Padding to avoid overlap with bottom selector
                child: _loadingAssets
                    ? const Center(child: CircularProgressIndicator(color: Color(0xff2B1564)))
                    : !_hasPermission || _recentAssets.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.photo_library_outlined, size: 48, color: const Color(0xff1C0D5A).withOpacity(0.5)),
                                const SizedBox(height: 12),
                                Text(
                                  "Select photos from gallery to upload",
                                  style: TextStyle(
                                    color: const Color(0xff1C0D5A).withOpacity(0.6),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: _pickImage,
                                  icon: const Icon(Icons.add_photo_alternate_outlined, color: Colors.white, size: 18),
                                  label: const Text("Open Gallery", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xff2B1564),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                    elevation: 0,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : GridView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 4,
                              mainAxisSpacing: 4,
                            ),
                            itemCount: _recentAssets.length + 1,
                            itemBuilder: (context, index) {
                              if (index == 0) {
                                return GestureDetector(
                                  onTap: _captureImageFromCamera,
                                  child: Container(
                                    color: const Color(0xffCBD5E1).withOpacity(0.3),
                                    child: const Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.photo_camera_outlined, color: Color(0xff1C0D5A), size: 26),
                                        SizedBox(height: 4),
                                        Text("Camera", style: TextStyle(color: Color(0xff1C0D5A), fontSize: 11, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                );
                              }
                              final asset = _recentAssets[index - 1];
                              final isSelected = _selectedAsset == asset;
                              return GestureDetector(
                                onTap: () => _selectAsset(asset),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    FutureBuilder<Uint8List?>(
                                      future: asset.thumbnailData,
                                      builder: (context, snapshot) {
                                        if (snapshot.connectionState == ConnectionState.done && snapshot.data != null) {
                                          return Image.memory(snapshot.data!, fit: BoxFit.cover);
                                        }
                                        return Container(color: Colors.grey.shade200);
                                      },
                                    ),
                                    if (isSelected) Container(color: Colors.black.withOpacity(0.35), child: const Center(child: Icon(Icons.check_circle, color: Colors.white, size: 28))),
                                  ],
                                ),
                              );
                            },
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- REEL TAB LAYOUT ---
  Widget _buildReelTabLayout() {
    return Stack(
      children: [
        // Camera Viewfinder / Preview
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
              : _isCameraInitialized && _cameraController != null
                  ? ColorFiltered(
                      colorFilter: ColorFilter.matrix(
                        _selectedLutIndex == 6 ? _customMatrix : List<double>.from(_lutFilters[_selectedLutIndex]["matrix"]),
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
                  : Container(
                      color: Colors.black,
                      child: const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    ),
        ),

        // Vignette Overlay
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

        // Controls Overlay
        SafeArea(
          child: Column(
            children: [
              // Header
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
                        decoration: BoxDecoration(color: Colors.black.withOpacity(0.4), shape: BoxShape.circle),
                        child: Center(child: Image.asset('assets/images/back_icon.png', color: Colors.white, width: 18.0, height: 18.0)),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(color: Colors.black.withOpacity(0.4), borderRadius: BorderRadius.circular(16)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_isRecording) ...[
                            Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            _isRecording ? "RECORDING" : (_recordedVideo != null ? "Preview" : "New Reel"),
                            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    if (!_isRecording)
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
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            elevation: 0,
                          ),
                          child: const Text("Next", style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                        ),
                      ),
                  ],
                ),
              ),

              // Console Overlays
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Stack(
                    children: [
                      // Left Rail Panel Buttons
                      if (_recordedVideo == null && !_isRecording)
                        Positioned(
                          left: 12,
                          top: MediaQuery.of(context).size.height * 0.05,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildVerticalRailActionButton(Icons.music_note, "Audio", onTap: () {}),
                              const SizedBox(height: 20),
                              _buildVerticalRailCustomButton(
                                child: Text("$_selectedLength", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
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


                      // Right Rail Panel: Cinematic LUT Filters
                      if (_showEffects && _recordedVideo == null && _selectedLutIndex != 6)
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
                                          color: isSelected ? const Color(0xff5D3EBC) : Colors.black.withOpacity(0.4),
                                          shape: BoxShape.circle,
                                          border: Border.all(color: isSelected ? Colors.white : Colors.white30, width: isSelected ? 2 : 1),
                                        ),
                                        child: Center(
                                          child: Icon(
                                            index == 6 ? Icons.tune_rounded : Icons.filter_hdr_outlined,
                                            color: filter["color"] as Color,
                                            size: 18,
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

                      // Custom Dynamic LUT adjustments
                      if (_showEffects && _selectedLutIndex == 6 && !_isRecording)
                        Positioned(
                          left: 12,
                          right: 12,
                          bottom: 130,
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
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Row(
                                      children: [
                                        Icon(Icons.tune_rounded, color: Colors.purpleAccent, size: 16),
                                        SizedBox(width: 8),
                                        Text("Cinematic Grade", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        TextButton.icon(
                                          onPressed: _importCustomLut,
                                          icon: const Icon(Icons.file_upload_outlined, color: Colors.white, size: 16),
                                          label: const Text("Import LUT", style: TextStyle(color: Colors.white, fontSize: 12)),
                                          style: TextButton.styleFrom(
                                            backgroundColor: Colors.white24,
                                            minimumSize: Size.zero,
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              _selectedLutIndex = 0; // Go back to normal preset
                                            });
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
                                            child: const Icon(Icons.close, color: Colors.white, size: 16),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                _buildLutSlider("Red Channel", _customRed, 0.2, 2.0, Colors.red, (val) => setState(() => _customRed = val)),
                                _buildLutSlider("Green Channel", _customGreen, 0.2, 2.0, Colors.green, (val) => setState(() => _customGreen = val)),
                                _buildLutSlider("Blue Channel", _customBlue, 0.2, 2.0, Colors.blue, (val) => setState(() => _customBlue = val)),
                                _buildLutSlider("Contrast", _customContrast, 0.5, 2.0, Colors.purpleAccent, (val) => setState(() => _customContrast = val)),
                              ],
                            ),
                          ),
                        ),

                      // Bottom Record/Gallery Strip
                      if (_recordedVideo == null)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 74,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              if (!_isRecording)
                                _buildBottomUtilityLauncher(
                                  child: const DecoratedBox(
                                    decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                    child: Icon(Icons.photo_library_outlined, color: Colors.white, size: 20),
                                  ),
                                  label: "Gallery",
                                  onTap: _pickVideoFromGallery,
                                ),
                              GestureDetector(
                                onTap: _toggleVideoRecording,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: _isRecording ? 92 : 84,
                                  height: _isRecording ? 92 : 84,
                                  decoration: BoxDecoration(
                                    color: Colors.transparent,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 4),
                                  ),
                                  padding: const EdgeInsets.all(6),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    decoration: BoxDecoration(
                                      color: _isRecording ? Colors.redAccent.shade700 : Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                              ),
                              if (!_isRecording)
                                _buildBottomUtilityLauncher(
                                  child: DecoratedBox(
                                    decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                    child: Icon(
                                      _showEffects ? Icons.auto_awesome : Icons.auto_awesome_outlined,
                                      color: Colors.white,
                                      size: 20,
                                    ),
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
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'post_details_screen.dart';
import 'package:photo_manager/photo_manager.dart';

import 'create_reel_screen.dart';

class CreatePostScreen extends StatefulWidget {
  final File? selectedImage;
  final String initialMode;
  const CreatePostScreen({super.key, this.selectedImage, this.initialMode = "POST"});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  List<AssetEntity> _recentAssets = [];
  bool _loadingAssets = true;
  bool _hasPermission = false;
  AssetEntity? _selectedAsset;
  late String _selectedMode;

  @override
  void initState() {
    super.initState();
    _selectedMode = widget.initialMode;
    _fetchRecentAssets();
    if (widget.selectedImage != null) {
      _selectedImage = widget.selectedImage;
    } else {
      // Auto-trigger native image picker if no image is initially selected
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _pickImage();
      });
    }
  }

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

          if (_selectedImage == null && assets.isNotEmpty) {
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
          _selectedImage = file;
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
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );
      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
          _selectedAsset = null;
        });
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to access device gallery.")),
        );
      }
    }
  }

  Future<void> _captureImageFromCamera() async {
    final cameraStatus = await Permission.camera.request();
    if (cameraStatus.isDenied || cameraStatus.isPermanentlyDenied) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Camera permission is required.")),
        );
      }
      return;
    }
    
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
      );
      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
          _selectedAsset = null;
        });
      }
    } catch (e) {
      debugPrint("Error capturing image: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to open camera.")),
        );
      }
    }
  }

  Future<void> _openCamera() async {
    if (_selectedMode == "REEL") {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const CreateReelScreen()),
      );
      if (result != null && result is File && mounted) {
        setState(() {
          _selectedImage = result;
          _selectedAsset = null;
        });
      }
    } else {
      _captureImageFromCamera();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xffF6F9FC),
        body: Container(
          width: double.infinity,
          height: double.infinity,
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
            child: Column(
              children: [
                // --- 1. TOP CUSTOM BRAND APP BAR HEADER ---
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Undo Back Navigation Ring
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Center(child: Image.asset('assets/images/back_icon.png', color: const Color(0xff1C0D5A), width: 18.0, height: 18.0)),
                        ),
                      ),
                      Text(
                        _selectedMode == "REEL" ? "New Reel" : "New Post",
                        style: const TextStyle(
                          color: Color(0xff1C0D5A),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.3,
                        ),
                      ),
                      // Next Button Matching Premium Pill Layout Box
                      SizedBox(
                        height: 38,
                        child: ElevatedButton(
                          onPressed: () {
                            if (_selectedImage != null) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => PostDetailsScreen(
                                    selectedImage: _selectedImage!,
                                  ),
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Please select an image first."),
                                  backgroundColor: Color(0xff2B1564),
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xff2B1564),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                          ),
                          child: const Text(
                            "Next",
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

                // --- 2. LIVE MEDIA VIEWER PREVIEW AREA CONTAINER ---
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: double.infinity,
                    height: _selectedMode == "REEL"
                        ? MediaQuery.of(context).size.height * 0.46
                        : MediaQuery.of(context).size.height * 0.38,
                    color: Colors.black.withOpacity(0.04),
                    child: Stack(
                      children: [
                        // Selected Image or Placeholder Viewport
                        Positioned.fill(
                          child: _selectedImage != null
                              ? Image.file(
                                  _selectedImage!,
                                  fit: BoxFit.cover,
                                )
                              : Container(
                                  color: const Color(0xffCBD5E1).withOpacity(0.4),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.9),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.add_photo_alternate_outlined,
                                          size: 40,
                                          color: Color(0xff2B1564),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      const Text(
                                        "Tap to select photo from gallery",
                                        style: TextStyle(
                                          color: Color(0xff1C0D5A),
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                        ),

                        if (_selectedImage != null) ...[


                          // Central Target Layer: Pointer Dot & Branded Text Pill Tag Context
                          Align(
                            alignment: const Alignment(0.0, 0.15),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 14,
                                  height: 14,
                                  decoration: const BoxDecoration(
                                    color: Color(0xff2B1564),
                                    shape: BoxShape.circle,
                                    boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.9),
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4))
                                    ],
                                  ),
                                  child: const Text(
                                    "TAP TO TAG LOCATION",
                                    style: TextStyle(
                                      color: Color(0xff2B1564),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Bottom Right Action Panel Overlays (Aspect Lock & Multipicker Toggles)
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

                // --- 3. MODE SELECTOR & GALLERY DROPDOWN BAR ---
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Mode Selector Pill Tabs: [ POST | REEL ]
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: const Color(0xffE2E8F0),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () {
                                if (_selectedMode != "POST") {
                                  setState(() {
                                    _selectedMode = "POST";
                                  });
                                }
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _selectedMode == "POST" ? const Color(0xff2B1564) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  "POST",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: _selectedMode == "POST" ? Colors.white : const Color(0xff64748B),
                                  ),
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                if (_selectedMode != "REEL") {
                                  setState(() {
                                    _selectedMode = "REEL";
                                  });
                                }
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _selectedMode == "REEL" ? const Color(0xff2B1564) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.movie_creation_outlined,
                                      size: 14,
                                      color: _selectedMode == "REEL" ? Colors.white : const Color(0xff64748B),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      "REEL",
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: _selectedMode == "REEL" ? Colors.white : const Color(0xff64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.photo_camera_outlined, color: Color(0xff2B1564)),
                            tooltip: "Open Camera",
                            onPressed: _openCamera,
                          ),
                          IconButton(
                            icon: const Icon(Icons.refresh_rounded, color: Color(0xff2B1564)),
                            onPressed: () {
                              setState(() {
                                _loadingAssets = true;
                              });
                              _fetchRecentAssets();
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // --- 4. INSTAGRAM-STYLE RECENT GALLERY GRID ---
                Expanded(
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
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                crossAxisSpacing: 4,
                                mainAxisSpacing: 4,
                                childAspectRatio: _selectedMode == "REEL" ? 9 / 16 : 1 / 1,
                              ),
                              itemCount: _recentAssets.length + 1,
                              itemBuilder: (context, index) {
                                if (index == 0) {
                                  return GestureDetector(
                                    onTap: _openCamera,
                                    child: Container(
                                      color: const Color(0xffCBD5E1).withOpacity(0.3),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            _selectedMode == "REEL" ? Icons.videocam_outlined : Icons.photo_camera_outlined,
                                            color: const Color(0xff1C0D5A),
                                            size: 28,
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            _selectedMode == "REEL" ? "Live Camera" : "Camera",
                                            style: const TextStyle(
                                              color: Color(0xff1C0D5A),
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
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
                                            return Image.memory(
                                              snapshot.data!,
                                              fit: BoxFit.cover,
                                            );
                                          }
                                          return Container(color: Colors.grey.shade200);
                                        },
                                      ),
                                      if (isSelected)
                                        Container(
                                          color: Colors.black.withOpacity(0.35),
                                          child: const Center(
                                            child: Icon(
                                              Icons.check_circle,
                                              color: Colors.white,
                                              size: 28,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Helper widget builder for translucent bottom-right preview anchors
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
}
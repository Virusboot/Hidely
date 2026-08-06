import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';

class CreateReelScreen extends StatefulWidget {
  const CreateReelScreen({super.key});

  @override
  State<CreateReelScreen> createState() => _CreateReelScreenState();
}

class _CreateReelScreenState extends State<CreateReelScreen> {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  int _selectedLength = 30;
  
  int _selectedLutIndex = 0;
  late PageController _pageController;
  final List<Map<String, dynamic>> _luts = [
    {
      "name": "Normal", "color": Colors.transparent,
      "matrix": <double>[1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0]
    },
    {
      "name": "Vintage", "color": Colors.orange.withOpacity(0.3),
      "matrix": <double>[1.2, 0.2, 0.1, 0, 0, 0.2, 1.0, 0.1, 0, 0, 0.1, 0.2, 0.8, 0, 0, 0, 0, 0, 1, 0]
    },
    {
      "name": "B&W", "color": Colors.grey,
      "matrix": <double>[0.33, 0.59, 0.11, 0, 0, 0.33, 0.59, 0.11, 0, 0, 0.33, 0.59, 0.11, 0, 0, 0, 0, 0, 1, 0]
    },
    {
      "name": "Cool", "color": Colors.blue.withOpacity(0.3),
      "matrix": <double>[0.8, 0, 0, 0, 0, 0, 0.9, 0, 0, 0, 0, 0, 1.3, 0, 0, 0, 0, 0, 1, 0]
    },
    {
      "name": "Warm", "color": Colors.orangeAccent.withOpacity(0.3),
      "matrix": <double>[1.3, 0, 0, 0, 0, 0, 1.1, 0, 0, 0, 0, 0, 0.8, 0, 0, 0, 0, 0, 1, 0]
    },
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.22, initialPage: 0);
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        _cameraController = CameraController(
          _cameras![0],
          ResolutionPreset.high,
          enableAudio: true,
        );
        await _cameraController!.initialize();
        if (mounted) setState(() => _isCameraInitialized = true);
      }
    } catch (e) {
      debugPrint("Camera Error: $e");
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _pageController.dispose();
    super.dispose();
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
        body: ClipRRect(
          borderRadius: BorderRadius.circular(24), // Instagram-like rounded corners
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Camera Preview
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
                Container(color: const Color(0xff1A1A1A)),

              // 2. Top Safe Area Elements
              SafeArea(
                child: Column(
                  children: [
                    // Top Bar
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: const Icon(Icons.close_rounded, color: Colors.white, size: 32),
                          ),
                          Row(
                            children: [
                              const Icon(Icons.flash_off_rounded, color: Colors.white, size: 24),
                              const SizedBox(width: 24),
                              const Text("1x", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                              const SizedBox(width: 24),
                              const Icon(Icons.access_time_rounded, color: Colors.white, size: 24),
                            ],
                          ),
                          const Icon(Icons.flip_camera_ios_rounded, color: Colors.white, size: 28),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Add Audio Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.music_note_rounded, color: Colors.white, size: 16),
                          SizedBox(width: 6),
                          Text("Add audio", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    
                    const Spacer(),

                    // Left Toolbar
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildToolIcon(Icons.music_note_rounded),
                            _buildToolIcon(Icons.auto_awesome), // Sparkles
                            _buildLengthIcon(),
                            _buildToolIcon(Icons.grid_view_rounded), // Layout
                            _buildToolIcon(Icons.view_agenda_outlined), // Dual
                            _buildToolIcon(Icons.auto_fix_high_rounded), // Wand
                          ],
                        ),
                      ),
                    ),

                    const Spacer(),

                    // Record Button & LUTs Carousel
                    SizedBox(
                      height: 100,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Scrollable LUTs list with Snap (PageView)
                          Positioned.fill(
                            child: PageView.builder(
                              controller: _pageController,
                              physics: const BouncingScrollPhysics(),
                              onPageChanged: (index) {
                                if (index < _luts.length) {
                                  setState(() => _selectedLutIndex = index);
                                }
                              },
                              itemCount: _luts.length + 1, // +1 for upload button
                              itemBuilder: (context, index) {
                                if (index == _luts.length) {
                                  // Upload Button
                                  return GestureDetector(
                                    onTap: () {
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Manual LUT Upload coming soon")));
                                    },
                                    child: Center(
                                      child: Container(
                                        width: 64,
                                        height: 64,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.white.withOpacity(0.2),
                                          border: Border.all(color: Colors.white54, width: 2),
                                        ),
                                        child: const Icon(Icons.upload_file_rounded, color: Colors.white, size: 28),
                                      ),
                                    ),
                                  );
                                }
                                
                                final isSelected = index == _selectedLutIndex;
                                
                                return GestureDetector(
                                  onTap: () {
                                    _pageController.animateToPage(index, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                                  },
                                  child: Center(
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      width: isSelected ? 86 : 64,
                                      height: isSelected ? 86 : 64,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(color: isSelected ? Colors.white : Colors.transparent, width: isSelected ? 5 : 0),
                                      ),
                                      child: ClipOval(
                                        child: Container(
                                          width: isSelected ? 72 : 64,
                                          height: isSelected ? 72 : 64,
                                          color: index == 0 ? Colors.white38 : _luts[index]['color'],
                                          child: index == 0 
                                            ? const Center(child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 36)) 
                                            : null,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 70), // Increased height to move LUT slider up
                  ],
                ),
              ),

              // Bottom-most bar (absolute positioning)
              Positioned(
                bottom: MediaQuery.of(context).padding.bottom > 0 ? MediaQuery.of(context).padding.bottom + 10 : 30,
                left: 20,
                right: 20,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // LUT Adjust Tools (Left)
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: const BoxDecoration(
                            color: Color(0xff2A2A2A),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.tune_rounded, color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 16),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: const BoxDecoration(
                            color: Color(0xff2A2A2A),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.contrast_rounded, color: Colors.white, size: 22),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToolIcon(IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Icon(icon, color: Colors.white, size: 28, shadows: const [Shadow(color: Colors.black45, blurRadius: 4)]),
    );
  }

  Widget _buildLengthIcon() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.5),
        ),
        child: Center(
          child: Text(
            "$_selectedLength",
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800, shadows: [Shadow(color: Colors.black45, blurRadius: 4)]),
          ),
        ),
      ),
    );
  }

}
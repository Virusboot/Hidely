import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:hidely_new/services/auth_service.dart';
import 'post_details_screen.dart';
import 'create_reel_screen.dart';

// 0 = POST (4:5),  1 = REEL (9:16)

class CreateMediaScreen extends StatefulWidget {
  const CreateMediaScreen({super.key});

  @override
  State<CreateMediaScreen> createState() => _CreateMediaScreenState();
}

class _CreateMediaScreenState extends State<CreateMediaScreen> {
  // ── Tabs ──────────────────────────────────────────────────────────────────
  int _currentModeIndex = 0; // 0=POST, 1=REEL

  // ── Gallery ───────────────────────────────────────────────────────────────
  File? _selectedFile;
  final ImagePicker _picker = ImagePicker();
  List<AssetEntity> _recentAssets = [];
  bool _loadingAssets = true;
  AssetEntity? _selectedAsset;

  @override
  void initState() {
    super.initState();
    _fetchAssets();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkUserFullName());
  }

  void _checkUserFullName() {
    if (AuthService().userName.trim().isEmpty) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('Notice', style: TextStyle(color: Color(0xff1C0D5A), fontWeight: FontWeight.bold)),
          content: const Text('Enter your full name in profile settings.'),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff2B1564),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  // ── Gallery loading ───────────────────────────────────────────────────────
  Future<void> _fetchAssets() async {
    setState(() => _loadingAssets = true);
    try {
      final ps = await PhotoManager.requestPermissionExtend();
      if (!ps.isAuth) { setState(() => _loadingAssets = false); return; }

      final type = _currentModeIndex == 0 ? RequestType.image : RequestType.video;
      final albums = await PhotoManager.getAssetPathList(type: type);
      if (albums.isNotEmpty) {
        final assets = await albums[0].getAssetListRange(start: 0, end: 60);
        setState(() {
          _recentAssets = assets;
          _loadingAssets = false;
        });
        if (assets.isNotEmpty) _selectAsset(assets.first);
      } else {
        setState(() => _loadingAssets = false);
      }
    } catch (e) {
      debugPrint('Gallery error: $e');
      setState(() => _loadingAssets = false);
    }
  }

  Future<void> _selectAsset(AssetEntity asset) async {
    final file = await asset.file;
    if (file != null && mounted) {
      setState(() { _selectedFile = file; _selectedAsset = asset; });
    }
  }

  Future<void> _pickImageFromCamera() async {
    final ok = await Permission.camera.request();
    if (ok.isDenied) { _snack('Camera permission required.', error: true); return; }
    final f = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      maxWidth: 1920,
      maxHeight: 1920,
    );
    if (f != null) setState(() { _selectedFile = File(f.path); _selectedAsset = null; });
  }



  void _snack(String msg, {required bool error}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(error ? Icons.error_outline : Icons.check_circle_outline, color: Colors.white),
        const SizedBox(width: 10),
        Expanded(child: Text(msg, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600))),
      ]),
      backgroundColor: error ? Colors.redAccent.shade700 : const Color(0xff5D3EBC),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 3),
    ));
  }

  // ── Build ─────────────────────────────────────────────────────────────────
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
        body: Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xffE0F2FE), Colors.white],
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    // ── Header ──────────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              width: 44, height: 44,
                              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                              child: Center(
                                child: Image.asset(
                                  'assets/images/back_icon.png',
                                  color: const Color(0xff1C0D5A),
                                  width: 18, height: 18,
                                ),
                              ),
                            ),
                          ),
                          Text(
                            _currentModeIndex == 0 ? 'New Post' : 'New Reel',
                            style: const TextStyle(
                              color: Color(0xff1C0D5A),
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.3,
                            ),
                          ),
                          SizedBox(
                            height: 38,
                            child: ElevatedButton(
                              onPressed: () {
                                if (_selectedFile != null) {
                                  Navigator.push(context, MaterialPageRoute(
                                    builder: (context) => PostDetailsScreen(selectedImage: _selectedFile!),
                                  ));
                                } else {
                                  _snack(
                                    _currentModeIndex == 0 ? 'Select a photo first.' : 'Select a video first.',
                                    error: true,
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xff2B1564),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                padding: const EdgeInsets.symmetric(horizontal: 24),
                                elevation: 0,
                              ),
                              child: const Text('Next', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── POST only: preview + dropdown ──────────────────
                    if (_currentModeIndex == 0) ..._postPreviewWidgets(),

                    // ── Media Grid ─────────────────────────────────────────
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 60),
                        child: _loadingAssets
                            ? const Center(child: CircularProgressIndicator(color: Color(0xff2B1564)))
                            : _recentAssets.isEmpty && _currentModeIndex == 0
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.photo_library_outlined, size: 48, color: const Color(0xff1C0D5A).withOpacity(0.4)),
                                        const SizedBox(height: 12),
                                        Text('No photos found', style: TextStyle(color: const Color(0xff1C0D5A).withOpacity(0.6), fontSize: 14, fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  )
                                : GridView.builder(
                                    padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
                                    physics: const BouncingScrollPhysics(),
                                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 3,
                                      crossAxisSpacing: 3,
                                      mainAxisSpacing: 3,
                                      childAspectRatio: _currentModeIndex == 0 ? (4 / 5) : (9 / 16),
                                    ),
                                    // REEL: first cell is camera, rest are assets
                                    itemCount: _currentModeIndex == 1
                                        ? _recentAssets.length + 1
                                        : _recentAssets.length,
                                    itemBuilder: (ctx, idx) {
                                      // REEL first cell = camera
                                      if (_currentModeIndex == 1 && idx == 0) {
                                        return GestureDetector(
                                          onTap: () {
                                            Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateReelScreen()));
                                          },
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(3),
                                            child: Container(
                                              color: const Color(0xffCBD5E1).withOpacity(0.5),
                                              child: Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  const Icon(Icons.video_camera_back_outlined, color: Color(0xff2B1564), size: 28),
                                                  const SizedBox(height: 4),
                                                  Text('Camera', style: TextStyle(color: const Color(0xff1C0D5A).withOpacity(0.7), fontSize: 11, fontWeight: FontWeight.bold)),
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      }

                                      final assetIdx = _currentModeIndex == 1 ? idx - 1 : idx;
                                      final asset = _recentAssets[assetIdx];
                                      final isSelected = _selectedAsset == asset;
                                      final isVideo = asset.type == AssetType.video;

                                      return GestureDetector(
                                        onTap: () => _selectAsset(asset),
                                        child: Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(3),
                                              child: FutureBuilder<Uint8List?>(
                                                future: asset.thumbnailDataWithSize(const ThumbnailSize(300, 533)),
                                                builder: (ctx, snap) {
                                                  if (snap.connectionState == ConnectionState.done && snap.data != null) {
                                                    return Image.memory(snap.data!, fit: BoxFit.cover, width: double.infinity, height: double.infinity);
                                                  }
                                                  return Container(color: Colors.grey.shade200);
                                                },
                                              ),
                                            ),
                                            if (isVideo)
                                              Positioned(
                                                bottom: 5, right: 5,
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: Colors.black.withOpacity(0.65),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    _formatDur(asset.videoDuration),
                                                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                                                  ),
                                                ),
                                              ),
                                            if (isSelected)
                                              ClipRRect(
                                                borderRadius: BorderRadius.circular(3),
                                                child: Container(
                                                  color: Colors.black.withOpacity(0.32),
                                                  child: const Center(child: Icon(Icons.check_circle, color: Colors.white, size: 26)),
                                                ),
                                              ),
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
            ),

            // ── Bottom tab bar: POST | REEL ───────────────────────────
            _buildTabBar(),
          ],
        ),
      ),
    );
  }

  // ── POST-only: preview area + dropdown ──────────────────────────────────
  List<Widget> _postPreviewWidgets() {
    final screenW = MediaQuery.of(context).size.width;
    final previewH = (screenW / (4 / 5)).clamp(180.0, MediaQuery.of(context).size.height * 0.44);

    return [
      // Preview
      GestureDetector(
        onTap: () async {
          final f = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 1920, maxHeight: 1920);
          if (f != null) setState(() { _selectedFile = File(f.path); _selectedAsset = null; });
        },
        child: Container(
          width: double.infinity,
          height: previewH,
          color: Colors.black.withOpacity(0.04),
          child: Stack(
            children: [
              Positioned.fill(
                child: _selectedFile != null
                    ? Image.file(_selectedFile!, fit: BoxFit.cover, width: double.infinity, height: double.infinity)
                    : Container(
                        color: const Color(0xffCBD5E1).withOpacity(0.4),
                        child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.add_photo_alternate_outlined, size: 40, color: Color(0xff2B1564)),
                          SizedBox(height: 12),
                          Text('Tap to select photo', style: TextStyle(color: Color(0xff1C0D5A), fontSize: 14, fontWeight: FontWeight.bold)),
                        ]),
                      ),
              ),
              if (_selectedFile != null)
                Positioned(
                  bottom: 12, right: 12,
                  child: Row(children: [
                    _overlayCircleBtn(Icons.crop_original_outlined),
                    const SizedBox(width: 8),
                    _overlayCircleBtn(Icons.layers_outlined),
                  ]),
                ),
            ],
          ),
        ),
      ),

      // Dropdown + camera button
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(children: [
              const Text('Device Gallery', style: TextStyle(color: Color(0xff1C0D5A), fontSize: 15, fontWeight: FontWeight.bold)),
              const SizedBox(width: 4),
              Icon(Icons.keyboard_arrow_down_rounded, color: const Color(0xff1C0D5A).withOpacity(0.7), size: 18),
            ]),
            GestureDetector(
              onTap: _pickImageFromCamera,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xff2B1564).withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(Icons.camera_alt_outlined, color: Color(0xff2B1564), size: 20),
              ),
            ),
          ],
        ),
      ),
    ];
  }



  Widget _overlayCircleBtn(IconData icon) {
    return Container(
      width: 34, height: 34,
      decoration: BoxDecoration(color: Colors.black.withOpacity(0.65), shape: BoxShape.circle),
      child: Icon(icon, color: Colors.white, size: 16),
    );
  }

  String _formatDur(Duration d) {
    final m = d.inMinutes;
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return m > 0 ? '$m:$s' : '0:$s';
  }

  // ── Bottom tab bar: POST | REEL ───────────────────────────────────────────
  Widget _buildTabBar() {
    const tabs = ['POST', 'REEL'];
    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom + 8,
          top: 8,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, -3)),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(tabs.length, (i) {
            final isSel = i == _currentModeIndex;
            return GestureDetector(
              onTap: () {
                if (_currentModeIndex != i) {
                  setState(() {
                    _currentModeIndex = i;
                    _selectedFile = null;
                    _selectedAsset = null;
                    _recentAssets = [];
                  });
                  _fetchAssets();
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 8),
                decoration: BoxDecoration(
                  color: isSel ? const Color(0xff2B1564) : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  tabs[i],
                  style: TextStyle(
                    color: isSel ? Colors.white : const Color(0xff1C0D5A).withOpacity(0.5),
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

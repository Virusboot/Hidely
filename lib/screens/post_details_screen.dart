import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:hidely_new/services/api_service.dart';
import 'package:hidely_new/services/auth_service.dart';
import 'package:hidely_new/services/ai_service.dart';
import 'package:hidely_new/widgets/user_avatar.dart';
import 'package:video_player/video_player.dart';
import 'main_wrapper.dart';
import 'package:hidely_new/services/location_capture_service.dart';

class PostDetailsScreen extends StatefulWidget {
  final File? selectedImage;
  final Uint8List? imageBytes;
  final String? filename;
  final MediaSource mediaSource;
  final CapturedLocation? initialCapturedLocation;

  const PostDetailsScreen({
    super.key,
    this.selectedImage,
    this.imageBytes,
    this.filename,
    this.mediaSource = MediaSource.gallery,
    this.initialCapturedLocation,
  });

  @override
  State<PostDetailsScreen> createState() => _PostDetailsScreenState();
}

class _PostDetailsScreenState extends State<PostDetailsScreen> {
  String _location = "Fetching location...";
  final TextEditingController _captionController = TextEditingController();
  final List<String> _taggedUsernames = [];
  bool _isLoading = false;

  String _selectedCategory = 'Nature';

  // Coordinates
  double? _latitude;
  double? _longitude;
  Uint8List? _localImageBytes;
  VideoPlayerController? _videoController;

  @override
  void initState() {
    super.initState();
    _fetchLocation();
    _runAiPlaceDetection();
    _loadLocalImageBytes();
    _initVideoPreview();
  }

  void _initVideoPreview() async {
    final path = (widget.selectedImage != null ? widget.selectedImage!.path : (widget.filename ?? '')).toLowerCase();
    final bool isVideo = path.contains('.mp4') || path.contains('.mov') || path.contains('.mkv') || path.contains('.avi') || path.contains('/video/');
    if (!isVideo) return;

    try {
      if (widget.selectedImage != null && !kIsWeb) {
        _videoController = VideoPlayerController.file(widget.selectedImage!);
      } else if (widget.selectedImage != null && kIsWeb) {
        _videoController = VideoPlayerController.networkUrl(Uri.parse(widget.selectedImage!.path));
      } else if (widget.filename != null && widget.filename!.isNotEmpty) {
        final url = widget.filename!.startsWith('http') || widget.filename!.startsWith('blob:')
            ? widget.filename!
            : '${ApiService().baseUrl}/${widget.filename!}';
        _videoController = VideoPlayerController.networkUrl(Uri.parse(url));
      }

      if (_videoController != null) {
        await _videoController!.initialize();
        await _videoController!.setLooping(true);
        await _videoController!.setVolume(0.0);
        _videoController!.play();
        if (mounted) setState(() {});
      }
    } catch (e) {
      debugPrint("Video preview init error: $e");
    }
  }

  Future<void> _loadLocalImageBytes() async {
    if (widget.imageBytes != null) {
      setState(() {
        _localImageBytes = widget.imageBytes;
      });
    } else if (widget.selectedImage != null) {
      try {
        final bytes = await widget.selectedImage!.readAsBytes();
        if (mounted) {
          setState(() {
            _localImageBytes = bytes;
          });
        }
      } catch (e) {
        debugPrint("Error loading image bytes in PostDetailsScreen: $e");
      }
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _runAiPlaceDetection() async {
    if (widget.selectedImage != null && !kIsWeb) {
      final result = await AiService().detectPlace(widget.selectedImage!);

      if (mounted) {
        setState(() {
          if (result.isValid && result.category.isNotEmpty) {
            _selectedCategory = result.category;
          }
        });
      }
    }
  }

  CapturedLocation? _capturedLocation;

  Future<void> _fetchLocation() async {
    // Gallery media: MUST NOT automatically fetch device GPS location
    if (widget.mediaSource == MediaSource.gallery) {
      if (mounted) {
        setState(() {
          _location = "Add location (optional)";
          _latitude = null;
          _longitude = null;
          _capturedLocation = null;
        });
      }
      return;
    }

    // Camera media: Capture high-accuracy current device location
    if (mounted) setState(() => _location = "Fetching camera location...");

    if (widget.initialCapturedLocation != null) {
      _capturedLocation = widget.initialCapturedLocation;
      _latitude = _capturedLocation!.latitude;
      _longitude = _capturedLocation!.longitude;
      if (mounted) {
        setState(() {
          _location = _capturedLocation!.displayName ?? "Camera Location";
        });
      }
      return;
    }

    final capLoc = await LocationCaptureService().captureCameraLocation();
    if (capLoc != null && mounted) {
      setState(() {
        _capturedLocation = capLoc;
        _latitude = capLoc.latitude;
        _longitude = capLoc.longitude;
        _location = capLoc.displayName ?? "${capLoc.latitude.toStringAsFixed(4)}, ${capLoc.longitude.toStringAsFixed(4)}";
      });
    } else if (mounted) {
      setState(() {
        _location = "Add location (optional)";
      });
    }
  }



  void _onSharePressed() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Running AI Place Verification..."),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 1),
      ),
    );

    String finalCaption = _captionController.text.trim();
    if (_taggedUsernames.isNotEmpty) {
      final String tagsText = _taggedUsernames.map((u) => '@$u').join(' ');
      if (finalCaption.isEmpty) {
        finalCaption = tagsText;
      } else {
        finalCaption = '$finalCaption\n\nwith $tagsText';
      }
    }

    // Run AI Verification Flow (Duplicate, Wrong Location, Spam Checks)
    final verifyResult = await AiService().verifyPlaceSubmission(
      title: finalCaption,
      location: _location,
      latitude: _latitude,
      longitude: _longitude,
      imageFile: widget.selectedImage,
    );

    if (verifyResult.isSpam) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Submission Rejected: ${verifyResult.reason}"),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final result = await ApiService().createPost(
      token: AuthService().token ?? '',
      caption: finalCaption,
      location: (_location == "Fetching location..." || _location == "Location access failed" || _location == "Add location (optional)") ? "Unknown Location" : _location,
      category: _selectedCategory,
      image: widget.selectedImage,
      imageBytes: widget.imageBytes,
      filename: widget.filename,
      latitude: _latitude,
      longitude: _longitude,
      locationAccuracyMeters: _capturedLocation?.accuracyMeters,
      locationSource: _capturedLocation?.source ?? (_location != "Add location (optional)" && _location != "Unknown Location" && _location.isNotEmpty ? 'manual' : null),
      locationCapturedAt: _capturedLocation?.capturedAt.toIso8601String(),
    );

    if (!mounted) {
      _isLoading = false;
      return;
    }

    setState(() {
      _isLoading = false;
    });

    if (result.success) {
      final String verificationMsg = verifyResult.isApproved
          ? "Place submitted! AI verified & queued for Admin Review ('Verified Hidden Place' Badge)."
          : "Place submitted. Status: ${verifyResult.reason}";

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(verificationMsg),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
      
      final navigator = Navigator.of(context);
      
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(settings: const RouteSettings(name: "/main"), builder: (context) => const MainWrapper()),
        (route) => false,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }



  void _openTagPeopleSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TagPeopleSheet(
        initialSelection: _taggedUsernames,
        onSelectionChanged: (selected) {
          setState(() {
            _taggedUsernames.clear();
            _taggedUsernames.addAll(selected);
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool canShare = !_isLoading;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: Image.asset('assets/images/back_icon.png', color: const Color(0xff1C0D5A), width: 24.0, height: 24.0),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "New Post",
          style: TextStyle(color: Color(0xff1C0D5A), fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          TextButton(
            onPressed: canShare ? _onSharePressed : null,
            child: Text(
              _isLoading ? "Sharing..." : "Share",
              style: TextStyle(
                color: canShare ? const Color(0xff5D3EBC) : Colors.black26,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildCaptionSection(),
            const Divider(height: 1),
            _buildTagPeopleSection(),
            const Divider(height: 1, indent: 60),
            _buildLocationSection(),
            const Divider(height: 1, indent: 60),
            _buildCategorySection(),
            const Divider(height: 1, indent: 60),
            _buildOptionSection(Icons.music_note, "Add Music"),
            const Divider(height: 1),
            const SizedBox(height: 20),
            _buildAdvancedSettings(),
          ],
        ),
      ),
    );
  }

  Widget _buildCaptionSection() {
    final bytes = _localImageBytes ?? widget.imageBytes;
    bool isAsset = widget.selectedImage != null && widget.selectedImage!.path.contains('assets/');
    final path = (widget.selectedImage != null ? widget.selectedImage!.path : (widget.filename ?? '')).toLowerCase();
    final bool isVideo = path.contains('.mp4') || path.contains('.mov') || path.contains('.mkv') || path.contains('.avi') || path.contains('/video/');

    final double previewWidth = isVideo ? 96.0 : 64.0;
    final double previewHeight = isVideo ? 54.0 : 80.0;
    final double aspectRatio = isVideo ? (16 / 9) : (4 / 5);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              Container(
                width: previewWidth,
                height: previewHeight,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: const Color(0xffF1F5F9),
                  border: Border.all(color: Colors.grey.shade300, width: 1),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: AspectRatio(
                    aspectRatio: aspectRatio,
                    child: isVideo
                        ? (_videoController != null && _videoController!.value.isInitialized
                            ? SizedBox.expand(
                                child: FittedBox(
                                  fit: BoxFit.cover,
                                  child: SizedBox(
                                    width: _videoController!.value.size.width,
                                    height: _videoController!.value.size.height,
                                    child: VideoPlayer(_videoController!),
                                  ),
                                ),
                              )
                            : const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xff2B1564),
                                ),
                              ))
                        : (bytes != null
                            ? Image.memory(bytes, fit: BoxFit.cover)
                            : (isAsset
                                ? Image.asset(widget.selectedImage!.path, fit: BoxFit.cover)
                                : (widget.selectedImage != null && !kIsWeb
                                    ? Image.file(widget.selectedImage!, fit: BoxFit.cover)
                                    : const Center(
                                        child: Icon(
                                          Icons.image_outlined,
                                          color: Color(0xff2B1564),
                                          size: 28,
                                        ),
                                      )))),
                  ),
                ),
              ),
              if (isVideo)
                const Positioned(
                  bottom: 4,
                  right: 4,
                  child: Icon(
                    Icons.play_circle_fill_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _captionController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: "Write a caption...",
                border: InputBorder.none,
                hintStyle: TextStyle(color: Colors.grey, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySection() {
    return ListTile(
      onTap: () {
        _showCategoryPicker(context);
      },
      leading: const Icon(Icons.category_outlined, color: Colors.black87),
      title: const Text("Category", style: TextStyle(fontSize: 16)),
      subtitle: Text(
        _selectedCategory,
        style: const TextStyle(color: Color(0xff5D3EBC), fontSize: 13, fontWeight: FontWeight.w500),
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
    );
  }

  void _showCategoryPicker(BuildContext context) {
    final categories = [
      'Nature', 'City', 'Mountains', 'Beach', 'Forest', 
      'Desert', 'Historical', 'Adventure', 'Relaxation', 'Other'
    ];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Select Category",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xff1C0D5A)),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final cat = categories[index];
                    return ListTile(
                      title: Text(cat),
                      trailing: _selectedCategory == cat
                          ? const Icon(Icons.check, color: Color(0xff5D3EBC))
                          : null,
                      onTap: () {
                        setState(() {
                          _selectedCategory = cat;
                        });
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showManualLocationDialog() async {
    final controller = TextEditingController(
      text: (_location == "Location access failed" || _location == "Tap to add location" || _location == "Fetching location...") ? "" : _location,
    );
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.location_on, color: Color(0xff2B1564)),
            SizedBox(width: 8),
            Text("Add Location", style: TextStyle(color: Color(0xff1C0D5A), fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                hintText: "Enter location (e.g. Manali, India)",
                filled: true,
                fillColor: const Color(0xffF1F5F9),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _fetchLocation();
              },
              icon: const Icon(Icons.my_location, color: Color(0xff2B1564), size: 18),
              label: const Text("Use Current Location", style: TextStyle(color: Color(0xff2B1564), fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xff2B1564),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text("Set Location", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty && mounted) {
      setState(() {
        _location = result;
      });
    }
  }

  Widget _buildLocationSection() {
    if (_capturedLocation != null) {
      final isHighConfidence = _capturedLocation!.isHighConfidence;
      final accMeters = _capturedLocation!.accuracyMeters.round();

      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isHighConfidence ? const Color(0xffF0FDF4) : const Color(0xffFFFBEB),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isHighConfidence ? const Color(0xffBBF7D0) : const Color(0xffFDE68A),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.my_location_rounded,
                  color: isHighConfidence ? const Color(0xff16A34A) : const Color(0xffD97706),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isHighConfidence ? "Captured Location (High Accuracy)" : "Captured Location (Low Accuracy)",
                    style: TextStyle(
                      color: isHighConfidence ? const Color(0xff15803D) : const Color(0xffB45309),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isHighConfidence ? const Color(0xff86EFAC) : const Color(0xffFCD34D),
                    ),
                  ),
                  child: Text(
                    "± $accMeters m",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isHighConfidence ? const Color(0xff15803D) : const Color(0xffB45309),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _location,
              style: const TextStyle(
                color: Color(0xff1C0D5A),
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _showManualLocationDialog,
                  icon: const Icon(Icons.edit_location_alt_rounded, size: 14, color: Color(0xff2B1564)),
                  label: const Text("Change", style: TextStyle(color: Color(0xff2B1564), fontSize: 12, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    side: const BorderSide(color: Color(0xffCBD5E1)),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _capturedLocation = null;
                      _latitude = null;
                      _longitude = null;
                      _location = "Add location (optional)";
                    });
                  },
                  icon: const Icon(Icons.close_rounded, size: 14, color: Colors.redAccent),
                  label: const Text("Remove", style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    side: const BorderSide(color: Color(0xffFECDD3)),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return ListTile(
      onTap: _showManualLocationDialog,
      leading: const Icon(Icons.location_on_outlined, color: Colors.black87),
      title: const Text("Add Location", style: TextStyle(fontSize: 16)),
      subtitle: _location != "Fetching location..." && _location != "Add location (optional)"
          ? Text(_location, style: const TextStyle(color: Color(0xff5D3EBC), fontSize: 13, fontWeight: FontWeight.w600))
          : null,
      trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
    );
  }

  Widget _buildTagPeopleSection() {
    final hasTags = _taggedUsernames.isNotEmpty;
    final subtitleText = hasTags 
        ? _taggedUsernames.map((u) => '@$u').join(', ') 
        : null;

    return ListTile(
      onTap: _openTagPeopleSheet,
      leading: const Icon(Icons.person_outline, color: Colors.black87),
      title: const Text("Tag People", style: TextStyle(fontSize: 16)),
      subtitle: subtitleText != null 
          ? Text(
              subtitleText, 
              style: const TextStyle(color: Color(0xff5D3EBC), fontSize: 13, fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : null,
      trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
    );
  }

  Widget _buildOptionSection(IconData icon, String title) => ListTile(
    onTap: () {},
    leading: Icon(icon, color: Colors.black87),
    title: Text(title, style: const TextStyle(fontSize: 16)),
    trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
  );

  Widget _buildAdvancedSettings() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Align(
      alignment: Alignment.centerLeft,
      child: TextButton(
        onPressed: () {},
        child: const Text(
          "Advanced Settings",
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
      ),
    ),
  );
}

class TagPeopleSheet extends StatefulWidget {
  final List<String> initialSelection;
  final ValueChanged<List<String>> onSelectionChanged;

  const TagPeopleSheet({
    super.key,
    required this.initialSelection,
    required this.onSelectionChanged,
  });

  @override
  State<TagPeopleSheet> createState() => _TagPeopleSheetState();
}

class _TagPeopleSheetState extends State<TagPeopleSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _allUsers = [];
  List<dynamic> _filteredUsers = [];
  final List<String> _selectedUsernames = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedUsernames.addAll(widget.initialSelection);
    _fetchUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchUsers() async {
    final result = await ApiService().getLeaderboard();
    if (!mounted) return;

    if (result.success) {
      final List<dynamic> users = result.data?['leaderboard'] ?? [];
      final currentUsername = AuthService().userUsername;

      setState(() {
        // Exclude current user from taggable list
        _allUsers = users.where((u) => u['username'] != currentUsername).toList();
        _filteredUsers = _allUsers;
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged(String query) {
    final cleanQuery = query.toLowerCase().trim();
    setState(() {
      if (cleanQuery.isEmpty) {
        _filteredUsers = _allUsers;
      } else {
        _filteredUsers = _allUsers.where((u) {
          final username = (u['username'] ?? '').toString().toLowerCase();
          final name = (u['name'] ?? '').toString().toLowerCase();
          return username.contains(cleanQuery) || name.contains(cleanQuery);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final double keyboardPadding = MediaQuery.of(context).viewInsets.bottom;
    
    return Container(
      height: MediaQuery.of(context).size.height * 0.75 + keyboardPadding,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(bottom: keyboardPadding),
      child: Column(
        children: [
          // Header Drag Handle
          const SizedBox(height: 12),
          Container(
            width: 44,
            height: 4.5,
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(2.5),
            ),
          ),
          const SizedBox(height: 8),

          // Header Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Tag People",
                  style: TextStyle(
                    color: Color(0xff1C0D5A),
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    widget.onSelectionChanged(_selectedUsernames);
                    Navigator.pop(context);
                  },
                  child: const Text(
                    "Done",
                    style: TextStyle(
                      color: Color(0xff5D3EBC),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 6.0),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xffF1F5F9),
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14.0),
              child: Row(
                children: [
                  const Icon(Icons.search, color: Colors.grey, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      decoration: const InputDecoration(
                        hintText: "Search creators...",
                        border: InputBorder.none,
                        hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                      style: const TextStyle(fontSize: 15, color: Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Users List
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xff2B1564),
                    ),
                  )
                : _filteredUsers.isEmpty
                    ? const Center(
                        child: Text(
                          "No creators found.",
                          style: TextStyle(color: Colors.black38, fontSize: 15),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filteredUsers.length,
                        physics: const BouncingScrollPhysics(),
                        itemBuilder: (context, index) {
                          final user = _filteredUsers[index];
                          final username = user['username'] ?? '';
                          final displayName = user['name'] ?? username;
                          final profilePic = user['profile_picture'];
                          final bool isSelected = _selectedUsernames.contains(username);

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                            leading: UserAvatar(
                              avatarUrl: profilePic,
                              displayName: displayName,
                              radius: 20,
                            ),
                            title: Text(
                              displayName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            subtitle: Text(
                              "@$username",
                              style: const TextStyle(color: Colors.black38, fontSize: 13),
                            ),
                            trailing: isSelected
                                ? Container(
                                    decoration: const BoxDecoration(
                                      color: Color(0xff2B1564),
                                      shape: BoxShape.circle,
                                    ),
                                    padding: const EdgeInsets.all(4),
                                    child: const Icon(Icons.check, color: Colors.white, size: 16),
                                  )
                                : Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.black12, width: 1.5),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  _selectedUsernames.remove(username);
                                } else {
                                  _selectedUsernames.add(username);
                                }
                              });
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
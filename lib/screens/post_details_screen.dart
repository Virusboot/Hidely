import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:hidely_new/services/api_service.dart';
import 'package:hidely_new/services/auth_service.dart';
import 'package:hidely_new/services/ai_service.dart';
import 'package:hidely_new/widgets/user_avatar.dart';
import 'package:video_player/video_player.dart';
import 'main_wrapper.dart';
import 'package:hidely_new/services/location_capture_service.dart';
import 'package:hidely_new/config/categories.dart';

class PostDetailsScreen extends StatefulWidget {
  final File? selectedImage;
  final List<File>? selectedImages;
  final Uint8List? imageBytes;
  final String? filename;
  final MediaSource mediaSource;
  final CapturedLocation? initialCapturedLocation;
  final AssetEntity? mediaAsset;

  const PostDetailsScreen({
    super.key,
    this.selectedImage,
    this.selectedImages,
    this.imageBytes,
    this.filename,
    this.mediaSource = MediaSource.gallery,
    this.initialCapturedLocation,
    this.mediaAsset,
  });

  @override
  State<PostDetailsScreen> createState() => _PostDetailsScreenState();
}

class _PostDetailsScreenState extends State<PostDetailsScreen> {
  static const String _placeholderAddLocation = "Add location (optional)";
  static const List<String> _transientLocationLabels = [
    "Fetching location...",
    "Fetching camera location...",
    "Fetching current GPS location...",
    "Detecting photo location...",
    "Location access failed",
    "Tap to add location",
    _placeholderAddLocation,
  ];

  String _location = "Fetching location...";
  final TextEditingController _captionController = TextEditingController();
  final List<String> _taggedUsernames = [];
  bool _isLoading = false;
  bool _isFetchingLocation = false;
  String? _locationStatusHint;

  String _selectedCategory = 'Nature';

  // Coordinates
  double? _latitude;
  double? _longitude;
  Uint8List? _localImageBytes;
  VideoPlayerController? _videoController;
  CapturedLocation? _capturedLocation;
  CapturedLocation? _photoDetectedLocation;

  bool get _isVideoMedia {
    final path = (widget.selectedImage != null
            ? widget.selectedImage!.path
            : (widget.filename ?? ''))
        .toLowerCase();
    return path.contains('.mp4') ||
        path.contains('.mov') ||
        path.contains('.m4v') ||
        path.contains('.mkv') ||
        path.contains('.avi') ||
        path.contains('/video/');
  }

  bool _isRealLocationText(String? value) {
    final clean = value?.trim() ?? '';
    if (clean.isEmpty) return false;
    return !_transientLocationLabels.contains(clean);
  }

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
    if (_isVideoMedia) return;
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

  void _applyCapturedLocation(CapturedLocation loc) {
    _capturedLocation = loc;
    _latitude = loc.latitude;
    _longitude = loc.longitude;
    _location = loc.label;
    _locationStatusHint = null;
  }

  Future<void> _fetchLocation() async {
    if (widget.initialCapturedLocation != null &&
        LocationCaptureService.isValidCoordinatePair(
          widget.initialCapturedLocation!.latitude,
          widget.initialCapturedLocation!.longitude,
        )) {
      final initial = widget.initialCapturedLocation!;
      if (initial.source == 'photo_exif') {
        _photoDetectedLocation = initial;
      }
      if (mounted) {
        setState(() {
          _applyCapturedLocation(initial);
          _isFetchingLocation =
              initial.displayName == null || initial.displayName!.trim().isEmpty;
        });
      }

      if (initial.displayName == null || initial.displayName!.trim().isEmpty) {
        final rev = await LocationCaptureService().reverseGeocodeDetailed(
          initial.latitude,
          initial.longitude,
        );
        if (!mounted) return;
        final updated = initial.copyWith(
          displayName: rev?.displayName ?? initial.formattedCoordinates,
          canonicalName: rev?.canonicalName,
          city: rev?.city,
          state: rev?.state,
          country: rev?.country,
          landmarkType: rev?.landmarkType,
        );
        setState(() {
          if (updated.source == 'photo_exif') {
            _photoDetectedLocation = updated;
          }
          _applyCapturedLocation(updated);
          _isFetchingLocation = false;
        });
      }
      return;
    }

    // Gallery media: extract GPS location from AssetEntity (Android/iOS MediaStore/PHAsset),
    // unredacted image EXIF, or MP4/MOV ISO-6709 atom metadata.
    if (widget.mediaSource == MediaSource.gallery) {
      if (mounted) {
        setState(() {
          _isFetchingLocation = true;
          _location = "Detecting photo location...";
          _locationStatusHint = null;
        });
      }

      final service = LocationCaptureService();
      CapturedLocation? photoLoc;

      if (widget.mediaAsset != null) {
        photoLoc = await service.extractLocationFromAsset(widget.mediaAsset!);
      }

      if (photoLoc == null && widget.selectedImage != null && !kIsWeb) {
        final bytesHint = _isVideoMedia ? null : (_localImageBytes ?? widget.imageBytes);
        photoLoc = await service.extractLocationFromFile(
          widget.selectedImage!,
          bytesHint: bytesHint,
        );
      }

      if (photoLoc == null && !_isVideoMedia) {
        Uint8List? bytes = _localImageBytes ?? widget.imageBytes;
        if (bytes == null && widget.selectedImage != null && !kIsWeb) {
          try {
            bytes = await widget.selectedImage!.readAsBytes();
          } catch (_) {}
        }
        if (bytes != null && bytes.isNotEmpty) {
          photoLoc = await service.extractLocationFromBytes(bytes);
        }
      }

      if (photoLoc == null && widget.selectedImages != null && !kIsWeb) {
        for (final imgFile in widget.selectedImages!) {
          photoLoc = await service.extractLocationFromFile(imgFile);
          if (photoLoc != null) break;
        }
      }

      if (!mounted) return;
      if (photoLoc != null) {
        setState(() {
          _photoDetectedLocation = photoLoc;
          _applyCapturedLocation(photoLoc!);
          _isFetchingLocation = false;
        });
        return;
      }

      setState(() {
        _isFetchingLocation = false;
        _location = _placeholderAddLocation;
        _latitude = null;
        _longitude = null;
        _capturedLocation = null;
        _locationStatusHint =
            "No GPS metadata found in this media. Use your current GPS or search a place.";
      });
      return;
    }

    // Camera media: capture high-accuracy live GPS device location
    await _useCurrentLocation(silentIfEmpty: true);
  }

  Future<void> _useCurrentLocation({bool silentIfEmpty = false}) async {
    final previousLocation = _location;
    final previousCaptured = _capturedLocation;
    final previousLat = _latitude;
    final previousLon = _longitude;

    if (mounted) {
      setState(() {
        _isFetchingLocation = true;
        _locationStatusHint = null;
        _location = "Fetching current GPS location...";
      });
    }

    final service = LocationCaptureService();
    final capLoc = await service.captureCameraLocation(forceFresh: true);
    if (!mounted) return;

    if (capLoc != null) {
      final adjusted = widget.mediaSource == MediaSource.camera
          ? capLoc
          : capLoc.copyWith(
              source: 'manual',
              landmarkType: capLoc.landmarkType ?? 'current_gps',
            );
      setState(() {
        _applyCapturedLocation(adjusted);
        _isFetchingLocation = false;
      });
      return;
    }

    final errMsg = service.lastErrorMessage ??
        "Could not detect your current GPS location.";

    setState(() {
      _isFetchingLocation = false;
      _locationStatusHint = errMsg;
      if (previousCaptured != null) {
        _applyCapturedLocation(previousCaptured);
      } else if (_isRealLocationText(previousLocation)) {
        _location = previousLocation;
        _latitude = previousLat;
        _longitude = previousLon;
      } else {
        _location = _placeholderAddLocation;
        _latitude = null;
        _longitude = null;
      }
    });

    if (!silentIfEmpty) {
      final bool canOpenSettings = !service.lastServiceEnabled ||
          service.lastPermission == LocationPermission.deniedForever;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errMsg),
          behavior: SnackBarBehavior.floating,
          action: canOpenSettings && !kIsWeb
              ? SnackBarAction(
                  label: "Settings",
                  onPressed: () {
                    if (!service.lastServiceEnabled) {
                      Geolocator.openLocationSettings();
                    } else {
                      Geolocator.openAppSettings();
                    }
                  },
                )
              : null,
        ),
      );
    }
  }



  void _onSharePressed() async {
    if (_isLoading) return;

    if (AuthService().isGuest) {
      showLoginRequiredSheet(context, reason: 'share a new travel post');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Uploading post..."),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );

    try {
      Uint8List? bytes = _isVideoMedia ? Uint8List(0) : (_localImageBytes ?? widget.imageBytes);
      if (!_isVideoMedia && bytes == null && widget.selectedImage != null && !kIsWeb) {
        try {
          bytes = await widget.selectedImage!.readAsBytes();
        } catch (_) {}
      }

      if (bytes != null && !AuthService().isOfficialOrAdmin) {
        final valResult = await LocationCaptureService().validateMediaIntegrity(
          bytes: bytes,
          filename: widget.filename ?? widget.selectedImage?.path,
          isOfficialUser: false,
        );

        if (!valResult.isValid) {
          setState(() => _isLoading = false);
          if (!mounted) return;
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: const Row(
                children: [
                  Icon(Icons.screen_lock_portrait_rounded, color: Color(0xffDC2626), size: 24),
                  SizedBox(width: 10),
                  Text("Upload Restricted", style: TextStyle(color: Color(0xff1C0D5A), fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
              content: Text(valResult.reason),
              actions: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff2B1564),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("OK", style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          );
          return;
        }
      }

      String finalCaption = _captionController.text.trim();
      if (_taggedUsernames.isNotEmpty) {
        final String tagsText = _taggedUsernames.map((u) => '@$u').join(' ');
        if (finalCaption.isEmpty) {
          finalCaption = tagsText;
        } else {
          finalCaption = '$finalCaption\n\nwith $tagsText';
        }
      }

      final bool hasRealLocation = _isRealLocationText(_location);
      final String submissionLocation = hasRealLocation ? _location.trim() : "Unknown Location";

      // If user manually typed a location without coordinates, try resolving coordinates briefly
      if (hasRealLocation &&
          !LocationCaptureService.isValidCoordinatePair(_latitude, _longitude)) {
        try {
          final geocoded = await LocationCaptureService()
              .geocodePlace(submissionLocation)
              .timeout(const Duration(seconds: 3));
          if (geocoded != null && mounted) {
            _capturedLocation = geocoded.copyWith(displayName: submissionLocation);
            _latitude = geocoded.latitude;
            _longitude = geocoded.longitude;
          }
        } catch (_) {}
      }

      // Run AI Verification Flow with 8s timeout safeguard
      PlaceVerificationResult verifyResult;
      try {
        verifyResult = await AiService().verifyPlaceSubmission(
          title: finalCaption,
          location: submissionLocation,
          latitude: _latitude,
          longitude: _longitude,
          imageFile: widget.selectedImage,
        ).timeout(const Duration(seconds: 8));
      } catch (_) {
        verifyResult = PlaceVerificationResult(
          isApproved: true,
          isDuplicate: false,
          isWrongLocation: false,
          isSpam: false,
          status: 'verified',
          badge: '',
          reason: 'Auto verified.',
        );
      }

      if (verifyResult.isSpam) {
        if (mounted) {
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

      final String? sourceToSend = _capturedLocation?.source ??
          (hasRealLocation ? 'manual' : null);

      final result = await ApiService().createPost(
        token: AuthService().token ?? '',
        caption: finalCaption,
        location: submissionLocation,
        category: _selectedCategory,
        image: widget.selectedImage,
        images: widget.selectedImages,
        imageBytes: (!kIsWeb && widget.selectedImage != null) ? null : widget.imageBytes,
        filename: widget.filename,
        latitude: _latitude,
        longitude: _longitude,
        locationAccuracyMeters: _capturedLocation?.accuracyMeters,
        locationSource: sourceToSend,
        locationCapturedAt: _capturedLocation?.capturedAt.toIso8601String(),
        canonicalName: _capturedLocation?.canonicalName ??
            (hasRealLocation ? submissionLocation.split(',').first.trim() : null),
        landmarkType: _capturedLocation?.landmarkType,
        city: _capturedLocation?.city,
        state: _capturedLocation?.state,
        country: _capturedLocation?.country,
        taggedUsernames: _taggedUsernames,
      );

      if (!mounted) return;

      if (result.success) {
        final String verificationMsg = (!hasRealLocation || verifyResult.isApproved)
            ? "Post published successfully."
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Post creation error: ${e.toString().replaceAll('Exception:', '')}"),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
    const categories = AppCategories.creationCategories;

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
                    final emoji = AppCategories.getEmoji(cat);
                    final isSelected = _selectedCategory == cat;
                    return ListTile(
                      leading: Text(emoji, style: const TextStyle(fontSize: 22)),
                      title: Text(
                        cat,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? const Color(0xff5D3EBC) : const Color(0xff1C0D5A),
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle_rounded, color: Color(0xff5D3EBC))
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

  Future<void> _showLocationPickerSheet() async {
    final initialText = _isRealLocationText(_location) ? _location : "";
    final selection = await showModalBottomSheet<_LocationPickerResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _LocationPickerSheet(
        initialQuery: initialText,
        photoDetectedLocation: _photoDetectedLocation,
        biasLatitude: _latitude,
        biasLongitude: _longitude,
      ),
    );

    if (selection == null || !mounted) return;

    if (selection.useCurrentGps) {
      await _useCurrentLocation();
      return;
    }

    if (selection.usePhotoLocation && _photoDetectedLocation != null) {
      setState(() {
        _applyCapturedLocation(_photoDetectedLocation!);
      });
      return;
    }

    if (selection.suggestion != null) {
      setState(() {
        _isFetchingLocation = true;
        _location = selection.suggestion!.displayName;
        _locationStatusHint = null;
      });
      final resolved = await LocationCaptureService().resolvePlaceSuggestion(selection.suggestion!);
      if (!mounted) return;
      setState(() {
        _isFetchingLocation = false;
        if (resolved != null) {
          _applyCapturedLocation(resolved);
        } else {
          // Clear any old coordinates so text & coordinates never mismatch!
          _capturedLocation = null;
          _latitude = null;
          _longitude = null;
          _location = selection.suggestion!.displayName;
        }
      });
      return;
    }

    final customText = selection.customText?.trim() ?? '';
    if (customText.isNotEmpty) {
      setState(() {
        _isFetchingLocation = true;
        _location = customText;
        _capturedLocation = null;
        _latitude = null;
        _longitude = null;
        _locationStatusHint = null;
      });
      final geocoded = await LocationCaptureService().geocodePlace(customText);
      if (!mounted) return;
      setState(() {
        _isFetchingLocation = false;
        if (geocoded != null) {
          _applyCapturedLocation(geocoded.copyWith(displayName: customText));
        } else {
          _location = customText;
          _capturedLocation = null;
          _latitude = null;
          _longitude = null;
        }
      });
    }
  }

  Widget _buildLocationSection() {
    if (_isFetchingLocation) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xffF5F3FF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xffDDD6FE)),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: Color(0xff5D3EBC),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _location,
                style: const TextStyle(
                  color: Color(0xff1C0D5A),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_capturedLocation != null) {
      final isExif = _capturedLocation!.source == 'photo_exif';
      final isCameraGps = _capturedLocation!.source == 'camera_capture' ||
          _capturedLocation!.landmarkType == 'current_gps';
      final isHighConfidence = _capturedLocation!.isHighConfidence;
      final accMeters = _capturedLocation!.accuracyMeters.round();

      final Color bgColor = isExif
          ? const Color(0xffF5F3FF)
          : (isCameraGps
              ? (isHighConfidence ? const Color(0xffF0FDF4) : const Color(0xffFFFBEB))
              : const Color(0xffEFF6FF));
      final Color borderColor = isExif
          ? const Color(0xffDDD6FE)
          : (isCameraGps
              ? (isHighConfidence ? const Color(0xffBBF7D0) : const Color(0xffFDE68A))
              : const Color(0xffBFDBFE));
      final Color accentColor = isExif
          ? const Color(0xff7C3AED)
          : (isCameraGps
              ? (isHighConfidence ? const Color(0xff16A34A) : const Color(0xffD97706))
              : const Color(0xff2563EB));
      final Color chipBorder = isExif
          ? const Color(0xffC4B5FD)
          : (isCameraGps
              ? (isHighConfidence ? const Color(0xff86EFAC) : const Color(0xffFCD34D))
              : const Color(0xff93C5FD));

      final String headerTitle = isExif
          ? "Photo/Video Location (Auto-Detected)"
          : (isCameraGps
              ? (isHighConfidence
                  ? "Current Location (High Accuracy)"
                  : "Current Location (Low Accuracy)")
              : "Selected Location");

      final String badgeText = isExif
          ? "EXIF GPS"
          : (isCameraGps ? "± $accMeters m" : "Pinned");

      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isExif
                      ? Icons.photo_camera_rounded
                      : (isCameraGps ? Icons.my_location_rounded : Icons.place_rounded),
                  color: accentColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    headerTitle,
                    style: TextStyle(
                      color: accentColor,
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
                    border: Border.all(color: chipBorder),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: accentColor,
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
            const SizedBox(height: 2),
            Text(
              _capturedLocation!.formattedCoordinates,
              style: const TextStyle(
                color: Colors.black45,
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                OutlinedButton.icon(
                  onPressed: _showLocationPickerSheet,
                  icon: const Icon(Icons.edit_location_alt_rounded, size: 14, color: Color(0xff2B1564)),
                  label: const Text("Change", style: TextStyle(color: Color(0xff2B1564), fontSize: 12, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    side: const BorderSide(color: Color(0xffCBD5E1)),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _useCurrentLocation,
                  icon: const Icon(Icons.my_location_rounded, size: 14, color: Color(0xff15803D)),
                  label: const Text("Current GPS", style: TextStyle(color: Color(0xff15803D), fontSize: 12, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    side: const BorderSide(color: Color(0xffBBF7D0)),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _capturedLocation = null;
                      _latitude = null;
                      _longitude = null;
                      _location = _placeholderAddLocation;
                      _locationStatusHint = null;
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          onTap: _showLocationPickerSheet,
          leading: const Icon(Icons.location_on_outlined, color: Colors.black87),
          title: const Text("Add Location", style: TextStyle(fontSize: 16)),
          subtitle: _isRealLocationText(_location)
              ? Text(
                  _location,
                  style: const TextStyle(color: Color(0xff5D3EBC), fontSize: 13, fontWeight: FontWeight.w600),
                )
              : (_locationStatusHint != null
                  ? Text(
                      _locationStatusHint!,
                      style: const TextStyle(color: Colors.black45, fontSize: 12),
                    )
                  : null),
          trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(56, 0, 16, 10),
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              ActionChip(
                avatar: const Icon(Icons.my_location_rounded, size: 16, color: Color(0xff2B1564)),
                label: const Text(
                  "Use Current Location",
                  style: TextStyle(color: Color(0xff2B1564), fontSize: 12, fontWeight: FontWeight.w600),
                ),
                backgroundColor: const Color(0xffF5F3FF),
                side: const BorderSide(color: Color(0xffDDD6FE)),
                onPressed: _useCurrentLocation,
              ),
              if (_photoDetectedLocation != null)
                ActionChip(
                  avatar: const Icon(Icons.photo_camera_rounded, size: 16, color: Color(0xff6D28D9)),
                  label: const Text(
                    "Use Photo Location",
                    style: TextStyle(color: Color(0xff6D28D9), fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xffDDD6FE)),
                  onPressed: () {
                    setState(() {
                      _applyCapturedLocation(_photoDetectedLocation!);
                    });
                  },
                ),
            ],
          ),
        ),
      ],
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
  bool _isSearching = false;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _selectedUsernames.addAll(widget.initialSelection);
    _fetchUsers();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  bool _isEligibleUserRecord(dynamic user) {
    if (user is! Map) return false;
    final uname = (user['username'] ?? '').toString().trim();
    if (uname.isEmpty) return false;
    final currentUsername = AuthService().userUsername.trim();
    if (currentUsername.isNotEmpty &&
        uname.toLowerCase() == currentUsername.toLowerCase()) {
      return false;
    }
    if (AuthService().isUserBlockedSync(uname)) {
      return false;
    }
    return true;
  }

  Future<void> _fetchUsers() async {
    final result = await ApiService().getLeaderboard(token: AuthService().token);
    if (!mounted) return;

    if (result.success) {
      final List<dynamic> users = result.data?['leaderboard'] ?? [];
      setState(() {
        _allUsers = users.where(_isEligibleUserRecord).toList();
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
    _searchDebounce?.cancel();

    setState(() {
      if (cleanQuery.isEmpty) {
        _filteredUsers = _allUsers;
        _isSearching = false;
      } else {
        _filteredUsers = _allUsers.where((u) {
          final username = (u['username'] ?? '').toString().toLowerCase();
          final name = (u['name'] ?? '').toString().toLowerCase();
          return username.contains(cleanQuery) || name.contains(cleanQuery);
        }).toList();
        _isSearching = true;
      }
    });

    if (cleanQuery.isEmpty) return;

    _searchDebounce = Timer(const Duration(milliseconds: 280), () async {
      final res = await ApiService().searchUsers(
        query: cleanQuery,
        token: AuthService().token,
      );
      if (!mounted) return;
      if (_searchController.text.toLowerCase().trim() != cleanQuery) return;

      final List<dynamic> remote =
          (res.success ? (res.data?['users'] as List? ?? []) : const [])
              .where(_isEligibleUserRecord)
              .toList();

      final Map<String, dynamic> byLowerUsername = <String, dynamic>{};
      for (final u in _filteredUsers) {
        final key = (u['username'] ?? '').toString().toLowerCase();
        if (key.isNotEmpty) byLowerUsername[key] = u;
      }
      for (final u in remote) {
        final key = (u['username'] ?? '').toString().toLowerCase();
        if (key.isNotEmpty) byLowerUsername[key] = u;
      }

      setState(() {
        _filteredUsers = byLowerUsername.values.toList();
        _isSearching = false;
      });
    });
  }

  String? _restrictionReason(dynamic user) {
    if (user is! Map) return null;
    final bool canBeTagged = user['can_be_tagged'] != false;
    final String policy = (user['allow_tags_from'] ?? 'everyone').toString();
    if (canBeTagged && policy != 'no_one') return null;
    if (policy == 'no_one') {
      return 'Tags turned off';
    }
    if (policy == 'following') {
      return 'Only people they follow can tag';
    }
    return 'Tags restricted';
  }

  @override
  Widget build(BuildContext context) {
    final double keyboardPadding = MediaQuery.of(context).viewInsets.bottom;
    
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.75 + keyboardPadding,
      child: Material(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        clipBehavior: Clip.antiAlias,
        child: Padding(
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
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                textAlignVertical: TextAlignVertical.center,
                style: const TextStyle(fontSize: 15, color: Colors.black87, height: 1.2),
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  prefixIcon: Icon(Icons.search, color: Colors.grey, size: 20),
                  prefixIconConstraints: BoxConstraints(minWidth: 42, minHeight: 46),
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                  hintText: "Search creators...",
                  hintStyle: TextStyle(color: Colors.grey, fontSize: 14, height: 1.2),
                ),
              ),
            ),
          ),

          if (_isSearching)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.0),
              child: LinearProgressIndicator(
                minHeight: 2,
                color: Color(0xff5D3EBC),
                backgroundColor: Color(0xffEDE9FC),
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
                          final username = (user['username'] ?? '').toString();
                          final displayName = (user['name'] ?? username).toString();
                          final profilePic = user['profile_picture'];
                          final String? restriction = _restrictionReason(user);
                          final bool isTagRestricted = restriction != null;
                          final bool isSelected = !isTagRestricted && _selectedUsernames.contains(username);

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                            leading: Opacity(
                              opacity: isTagRestricted ? 0.5 : 1.0,
                              child: UserAvatar(
                                avatarUrl: profilePic,
                                displayName: displayName,
                                radius: 20,
                              ),
                            ),
                            title: Text(
                              displayName,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: isTagRestricted ? Colors.black45 : Colors.black87,
                              ),
                            ),
                            subtitle: Text(
                              isTagRestricted ? '@$username · $restriction' : '@$username',
                              style: TextStyle(
                                color: isTagRestricted ? Colors.deepOrange.shade400 : Colors.black38,
                                fontSize: 12.5,
                              ),
                            ),
                            trailing: isTagRestricted
                                ? const Icon(Icons.lock_outline_rounded, color: Colors.black26, size: 20)
                                : isSelected
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
                              if (isTagRestricted) {
                                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('@$username: $restriction'),
                                    behavior: SnackBarBehavior.floating,
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                                return;
                              }
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
        ),
      ),
    );
  }
}

class _LocationPickerResult {
  final bool useCurrentGps;
  final bool usePhotoLocation;
  final PlaceSuggestion? suggestion;
  final String? customText;

  const _LocationPickerResult({
    this.useCurrentGps = false,
    this.usePhotoLocation = false,
    this.suggestion,
    this.customText,
  });
}

class _LocationPickerSheet extends StatefulWidget {
  final String initialQuery;
  final CapturedLocation? photoDetectedLocation;
  final double? biasLatitude;
  final double? biasLongitude;

  const _LocationPickerSheet({
    required this.initialQuery,
    this.photoDetectedLocation,
    this.biasLatitude,
    this.biasLongitude,
  });

  @override
  State<_LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<_LocationPickerSheet> {
  late final TextEditingController _searchController;
  Timer? _debounce;
  List<PlaceSuggestion> _suggestions = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialQuery);
    if (widget.initialQuery.trim().length >= 2) {
      _runSearch(widget.initialQuery.trim());
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    final trimmed = value.trim();
    if (trimmed.length < 2) {
      setState(() {
        _suggestions = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _runSearch(trimmed);
    });
  }

  Future<void> _runSearch(String query) async {
    final results = await LocationCaptureService().searchPlaceSuggestions(
      query,
      biasLat: widget.biasLatitude,
      biasLon: widget.biasLongitude,
    );
    if (!mounted) return;
    if (_searchController.text.trim() != query) return;
    setState(() {
      _suggestions = results;
      _isSearching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final double keyboardPadding = MediaQuery.of(context).viewInsets.bottom;
    final String typedQuery = _searchController.text.trim();

    final double maxHeight = MediaQuery.of(context).size.height * 0.94;
    return SizedBox(
      height: (MediaQuery.of(context).size.height * 0.78 + keyboardPadding)
          .clamp(0.0, maxHeight),
      child: Material(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: EdgeInsets.only(bottom: keyboardPadding),
          child: Column(
            children: [
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Select Location",
                      style: TextStyle(
                        color: Color(0xff1C0D5A),
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        if (typedQuery.isNotEmpty) {
                          Navigator.pop(
                            context,
                            _LocationPickerResult(customText: typedQuery),
                          );
                        } else {
                          Navigator.pop(context);
                        }
                      },
                      child: Text(
                        typedQuery.isNotEmpty ? "Done" : "Close",
                        style: const TextStyle(
                          color: Color(0xff5D3EBC),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xffF1F5F9),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: TextField(
                    controller: _searchController,
                    autofocus: true,
                    onChanged: _onQueryChanged,
                    onSubmitted: (val) {
                      final trimmed = val.trim();
                      if (trimmed.isNotEmpty) {
                        Navigator.pop(
                          context,
                          _LocationPickerResult(customText: trimmed),
                        );
                      }
                    },
                    textAlignVertical: TextAlignVertical.center,
                    style: const TextStyle(fontSize: 15, color: Colors.black87),
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      prefixIcon: const Icon(Icons.search, color: Colors.grey, size: 20),
                      suffixIcon: typedQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close, color: Colors.grey, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                _onQueryChanged('');
                              },
                            )
                          : null,
                      prefixIconConstraints: const BoxConstraints(minWidth: 42, minHeight: 46),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      hintText: "Search place, waterfall, temple, city...",
                      hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  ),
                ),
              ),
              if (_isSearching)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.0),
                  child: LinearProgressIndicator(
                    minHeight: 2,
                    color: Color(0xff5D3EBC),
                    backgroundColor: Color(0xffEDE9FC),
                  ),
                ),
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  children: [
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Color(0xffF0FDF4),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.my_location_rounded, color: Color(0xff16A34A), size: 20),
                      ),
                      title: const Text(
                        "Use Current Location (Live GPS)",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: Color(0xff1C0D5A)),
                      ),
                      subtitle: const Text(
                        "Detect your exact live coordinates",
                        style: TextStyle(fontSize: 12, color: Colors.black45),
                      ),
                      onTap: () => Navigator.pop(
                        context,
                        const _LocationPickerResult(useCurrentGps: true),
                      ),
                    ),
                    if (widget.photoDetectedLocation != null)
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Color(0xffF5F3FF),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.photo_camera_rounded, color: Color(0xff7C3AED), size: 20),
                        ),
                        title: const Text(
                          "Use Photo/Video Location",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: Color(0xff1C0D5A)),
                        ),
                        subtitle: Text(
                          widget.photoDetectedLocation!.label,
                          style: const TextStyle(fontSize: 12, color: Color(0xff6D28D9)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => Navigator.pop(
                          context,
                          const _LocationPickerResult(usePhotoLocation: true),
                        ),
                      ),
                    const Divider(height: 1),
                    ..._suggestions.map(
                      (s) => ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                        leading: const Icon(Icons.place_outlined, color: Color(0xff2B1564), size: 22),
                        title: Text(
                          s.displayName,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5, color: Color(0xff1C0D5A)),
                        ),
                        subtitle: s.subtitle.isNotEmpty
                            ? Text(
                                s.subtitle,
                                style: const TextStyle(fontSize: 12, color: Colors.black45),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              )
                            : null,
                        trailing: s.hasCoordinates
                            ? const Icon(Icons.gps_fixed_rounded, size: 16, color: Color(0xff16A34A))
                            : null,
                        onTap: () => Navigator.pop(
                          context,
                          _LocationPickerResult(suggestion: s),
                        ),
                      ),
                    ),
                    if (typedQuery.isNotEmpty)
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                        leading: const Icon(Icons.add_location_alt_outlined, color: Color(0xff5D3EBC), size: 22),
                        title: Text(
                          'Set custom location: "$typedQuery"',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xff5D3EBC)),
                        ),
                        onTap: () => Navigator.pop(
                          context,
                          _LocationPickerResult(customText: typedQuery),
                        ),
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
}

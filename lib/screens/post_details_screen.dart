import 'package:flutter/material.dart';
import 'dart:io';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'main_wrapper.dart';
import 'package:hidely_new/services/api_service.dart';
import 'package:hidely_new/services/auth_service.dart';
import 'package:hidely_new/services/ai_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:exif/exif.dart';
import 'package:hidely_new/widgets/user_avatar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter/foundation.dart';

class PostDetailsScreen extends StatefulWidget {
  final File? selectedImage;
  final Uint8List? imageBytes;
  final String? filename;

  const PostDetailsScreen({
    super.key,
    this.selectedImage,
    this.imageBytes,
    this.filename,
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

  @override
  void initState() {
    super.initState();
    _fetchLocation();
    _runAiPlaceDetection();
    _loadLocalImageBytes();
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

  Future<void> _fetchLocation() async {
    try {
      final bytes = widget.imageBytes ?? (widget.selectedImage != null ? await widget.selectedImage!.readAsBytes() : null);
      if (bytes == null) return;
      final tags = await readExifFromBytes(bytes);
      
      if (tags.isNotEmpty) {
        final latRef = tags['GPS GPSLatitudeRef']?.toString();
        final latTag = tags['GPS GPSLatitude'];
        final lonRef = tags['GPS GPSLongitudeRef']?.toString();
        final lonTag = tags['GPS GPSLongitude'];

        if (latRef != null && latTag != null && lonRef != null && lonTag != null) {
          final lat = _convertTagToDouble(latTag, latRef);
          final lon = _convertTagToDouble(lonTag, lonRef);
          
          if (lat != null && lon != null) {
            _latitude = lat;
            _longitude = lon;
            List<Placemark> marks = await placemarkFromCoordinates(lat, lon);
            if (marks.isNotEmpty && mounted) {
              _updateLocationState(marks[0]);
              return;
            }
          }
        }
      }
    } catch (e) {
      debugPrint("EXIF location read failed/not present: $e");
    }

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
        // Try to get a high-accuracy position within 100 meters
        // Stream positions and accept the first one with accuracy <= 100m
        Position? bestPos;

        try {
          await for (final pos in Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.bestForNavigation,
              distanceFilter: 0,
            ),
          ).timeout(const Duration(seconds: 8))) {
            if (bestPos == null || pos.accuracy < bestPos.accuracy) {
              bestPos = pos;
            }
            // Lock position as soon as we get sub-15 meter pinpoint accuracy
            if (pos.accuracy <= 15.0) {
              break;
            }
          }
        } catch (_) {
          // Timeout or stream error — use best position captured
        }

        // Fallback: if stream gave nothing, try a direct single fix
        bestPos ??= await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.bestForNavigation,
          ),
        ).timeout(const Duration(seconds: 6)).catchError((_) async =>
          Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
            ),
          ));

        _latitude = bestPos.latitude;
        _longitude = bestPos.longitude;
        debugPrint('[Location] Pinpoint Accuracy: ${bestPos.accuracy.toStringAsFixed(1)}m');

        List<Placemark> marks = await placemarkFromCoordinates(bestPos.latitude, bestPos.longitude);
        if (marks.isNotEmpty && mounted) {
          _updateLocationState(marks[0]);
        }
      } else {
        if (mounted) setState(() => _location = "Permission denied");
      }
    } catch (e) {
      if (mounted) setState(() => _location = "Location access failed");
    }
  }

  void _updateLocationState(Placemark mark) {
    final name = mark.name ?? '';
    final subLocality = mark.subLocality ?? '';
    final thoroughfare = mark.thoroughfare ?? '';
    final subThoroughfare = mark.subThoroughfare ?? '';
    final locality = mark.locality ?? '';
    final subAdministrativeArea = mark.subAdministrativeArea ?? '';
    final country = mark.country ?? '';
    
    List<String> parts = [];

    // 1. Street or Building Name / Number
    if (thoroughfare.isNotEmpty && !thoroughfare.contains('+')) {
      if (subThoroughfare.isNotEmpty && !thoroughfare.contains(subThoroughfare)) {
        parts.add("$subThoroughfare $thoroughfare");
      } else {
        parts.add(thoroughfare);
      }
    } else if (name.isNotEmpty &&
        !name.contains('+') &&
        double.tryParse(name) == null &&
        name.toLowerCase() != locality.toLowerCase() &&
        name.toLowerCase() != subLocality.toLowerCase()) {
      parts.add(name);
    }

    // 2. SubLocality / Sector / Block / Neighborhood
    if (subLocality.isNotEmpty && !parts.contains(subLocality) && subLocality.toLowerCase() != locality.toLowerCase()) {
      parts.add(subLocality);
    }

    // 3. Locality / City
    if (locality.isNotEmpty && !parts.contains(locality)) {
      parts.add(locality);
    } else if (subAdministrativeArea.isNotEmpty && !parts.contains(subAdministrativeArea)) {
      parts.add(subAdministrativeArea);
    }

    if (parts.isEmpty && country.isNotEmpty) {
      parts.add(country);
    }

    String formattedLoc = parts.join(", ");
    if (formattedLoc.isEmpty) {
      formattedLoc = "Unknown Location";
    }

    setState(() => _location = formattedLoc);
  }

  double? _convertTagToDouble(IfdTag tag, String ref) {
    try {
      final list = tag.values.toList();
      if (list.length == 3) {
        double degrees = _ratioToDouble(list[0]);
        double minutes = _ratioToDouble(list[1]);
        double seconds = _ratioToDouble(list[2]);
        
        double decimal = degrees + (minutes / 60.0) + (seconds / 3600.0);
        if (ref == 'S' || ref == 'W') {
          decimal = -decimal;
        }
        return decimal;
      }
    } catch (e) {
      debugPrint("Error converting tag: $e");
    }
    return null;
  }

  double _ratioToDouble(dynamic ratio) {
    if (ratio is Ratio) {
      return ratio.numerator / ratio.denominator;
    }
    return double.tryParse(ratio.toString()) ?? 0.0;
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
      location: _location == "Fetching location..." || _location == "Location access failed" ? "Unknown Location" : _location,
      category: _selectedCategory,
      image: widget.selectedImage,
      imageBytes: widget.imageBytes,
      filename: widget.filename,
      latitude: _latitude,
      longitude: _longitude,
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
      await _showNewPlaceNotification();
      
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

  Future<void> _showNewPlaceNotification() async {
    final prefs = await SharedPreferences.getInstance();
    final notificationsEnabled = prefs.getBool('enable_notifications') ?? true;
    if (!notificationsEnabled) return;

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings initializationSettingsDarwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);

    const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'new_place_channel',
      'New Places',
      channelDescription: 'Notifications for newly discovered places',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );
    
    // Slight delay so the user transitions back to the main screen before the notification pops
    Future.delayed(const Duration(seconds: 1), () async {
      await flutterLocalNotificationsPlugin.show(
        0,
        'New Hidden Place Found! 🗺️',
        'A new spot has just been added to the map. Be the first to explore it!',
        platformChannelSpecifics,
      );
    });
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
    final bool isVideo = path.endsWith('.mp4') || path.endsWith('.mov') || path.endsWith('.mkv') || path.endsWith('.avi');

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              Container(
                height: 70,
                width: 70,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: const Color(0xffF1F5F9),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: isVideo
                      ? const Center(
                          child: Icon(
                            Icons.play_circle_fill_rounded,
                            color: Color(0xff2B1564),
                            size: 32,
                          ),
                        )
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
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _captionController,
              maxLines: 3,
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

  Widget _buildLocationSection() => ListTile(
    onTap: () {},
    leading: const Icon(Icons.location_on_outlined, color: Colors.black87),
    title: const Text("Add Location", style: TextStyle(fontSize: 16)),
    subtitle: _location != "Fetching location..." 
        ? Text(_location, style: const TextStyle(color: Color(0xff5D3EBC), fontSize: 13))
        : null,
    trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
  );

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
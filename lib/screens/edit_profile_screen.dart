import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:hidely_new/services/auth_service.dart';
import 'package:hidely_new/services/api_service.dart';
import 'package:hidely_new/widgets/user_avatar.dart';
import 'package:hidely_new/widgets/profile_photo_cropper_dialog.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}


class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _usernameController;
  late final TextEditingController _bioController;


  // Profile Image State Variables
  String? _selectedImagePath;
  Uint8List? _selectedImageBytes;
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;
  String? _selectedGender;
  final List<Map<String, String>> _customLinks = [];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: AuthService().userName);
    _usernameController = TextEditingController(text: AuthService().userUsername);
    
    final originalBio = AuthService().userBio;
    final RegExp linkLineReg = RegExp(r'^([^:\n]+):\s*(https?://[^\s\n]+|@[^\s\n]+|[^\s\n]+)', caseSensitive: false);

    final lines = originalBio.split('\n');
    final bioLines = <String>[];
    final Set<String> seenLinks = {};

    for (final line in lines) {
      final trimmed = line.trim();
      final match = linkLineReg.firstMatch(trimmed);
      if (match != null) {
        final key = match.group(1)?.trim() ?? '';
        final val = match.group(2)?.trim() ?? '';
        
        String normVal = val;
        if (key.toLowerCase() == 'instagram') {
          if (!normVal.startsWith('http')) {
            if (normVal.startsWith('@')) normVal = normVal.substring(1);
            normVal = 'https://instagram.com/$normVal';
          }
        } else if (key.toLowerCase() == 'youtube') {
          if (!normVal.startsWith('http')) {
            if (normVal.startsWith('@')) normVal = normVal.substring(1);
            normVal = 'https://youtube.com/@$normVal';
          }
        } else if (!normVal.startsWith('http')) {
          normVal = 'https://$normVal';
        }
        final cleanUrl = normVal.toLowerCase().replaceAll(RegExp(r'/$'), '');
        final linkKey = '${key.toLowerCase()}:$cleanUrl';

        if (!seenLinks.contains(cleanUrl) && !seenLinks.contains(linkKey)) {
          seenLinks.add(cleanUrl);
          seenLinks.add(linkKey);
          _customLinks.add({'title': key, 'url': val});
        }
      } else {
        bioLines.add(line);
      }
    }

    final cleanBio = bioLines.join('\n').trim();
    _bioController = TextEditingController(text: cleanBio);
    
    final rawGender = AuthService().userGender;
    if (rawGender.isNotEmpty) {
      const allowedGenders = ["Male", "Female", "Other", "Prefer not to say"];
      final matched = allowedGenders.firstWhere(
        (g) => g.toLowerCase() == rawGender.trim().toLowerCase(),
        orElse: () => rawGender,
      );
      _selectedGender = allowedGenders.contains(matched) ? matched : null;
    } else {
      _selectedGender = null;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();

    super.dispose();
  }

  Future<void> _pickProfileImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 95,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (image != null && mounted) {
        final initialBytes = await image.readAsBytes();
        final croppedBytes = await ProfilePhotoCropperDialog.cropProfilePhoto(
          context: context,
          imageBytes: initialBytes,
          imagePath: image.path,
        );
        if (croppedBytes != null) {
          setState(() {
            _selectedImageBytes = croppedBytes;
            _selectedImagePath = image.path;
          });
        }
      }
    } catch (e) {
      debugPrint("Error picking profile image: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xffE0F2FE), Color(0xffFFFFFF)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // 1. Header
               Padding(
                 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                 child: Stack(
                   alignment: Alignment.center,
                   children: [
                     Align(
                       alignment: Alignment.centerLeft,
                       child: GestureDetector(
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
                     ),
                     const Text(
                       "Edit Profile",
                       style: TextStyle(
                         fontSize: 18,
                         fontWeight: FontWeight.bold,
                         color: Color(0xff1C0D5A),
                       ),
                     ),
                     Align(
                       alignment: Alignment.centerRight,
                        child: GestureDetector(
                          onTap: () async {
                            if (_isLoading) return;

                            final name = _nameController.text.trim();
                            final username = _usernameController.text.trim().toLowerCase();
                            final bio = _bioController.text.trim();


                            // 1. Validations (Instagram-like limitations)
                            if (name.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Name cannot be empty"), behavior: SnackBarBehavior.floating),
                              );
                              return;
                            }
                            if (username.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Username cannot be empty"), behavior: SnackBarBehavior.floating),
                              );
                              return;
                            }
                            if (username.length < 3) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Username must be at least 3 characters long"), behavior: SnackBarBehavior.floating),
                              );
                              return;
                            }
                            // Regex: Lowercase alphanumeric, underscores, and periods. Cannot start or end with a period/underscore.
                            final usernameRegex = RegExp(r'^[a-z0-9]([a-z0-9_.]*[a-z0-9])?$');
                            if (!usernameRegex.hasMatch(username)) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Username can only contain lowercase letters, numbers, underscores, and periods. It cannot start or end with a period/underscore."),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                              return;
                            }



                            setState(() {
                              _isLoading = true;
                            });
                            
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Saving profile changes..."),
                                behavior: SnackBarBehavior.floating,
                                duration: Duration(seconds: 1),
                              ),
                            );

                            final rawBio = bio;
                            final RegExp linkLineReg = RegExp(r'^([^:\n]+):\s*(https?://[^\s\n]+|@[^\s\n]+|[^\s\n]+)', caseSensitive: false);
                            final cleanBioLines = rawBio.split('\n').where((line) => !linkLineReg.hasMatch(line.trim())).toList();
                            String finalBio = cleanBioLines.join('\n').trim();

                            for (final link in _customLinks) {
                              final title = link['title'] ?? 'Link';
                              final url = link['url'] ?? '';
                              if (url.isNotEmpty) {
                                if (finalBio.isNotEmpty) {
                                  finalBio = '$finalBio\n$title: $url';
                                } else {
                                  finalBio = '$title: $url';
                                }
                              }
                            }

                            final result = await ApiService().updateUserProfile(
                              token: AuthService().token ?? '',
                              name: name,
                              username: username,
                              gender: _selectedGender,
                              bio: finalBio,
                              avatarBytes: _selectedImageBytes,
                              avatar: (!kIsWeb && _selectedImagePath != null) ? File(_selectedImagePath!) : null,
                            );

                            if (!context.mounted) return;

                            setState(() {
                              _isLoading = false;
                            });

                            if (result.success) {
                              final updatedUser = result.data?['user'];
                              if (updatedUser != null) {
                                await AuthService().login(AuthService().token ?? '', updatedUser);
                              }

                              if (!context.mounted) return;

                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Profile updated successfully!"),
                                  behavior: SnackBarBehavior.floating,
                                  duration: Duration(seconds: 2),
                                ),
                              );
                              Navigator.pop(context, true);
                            } else {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(result.message),
                                  behavior: SnackBarBehavior.floating,
                                  backgroundColor: Colors.redAccent,
                                  duration: const Duration(seconds: 3),
                                ),
                              );
                            }
                          },
                         child: Container(
                           width: 44,
                           height: 44,
                           decoration: const BoxDecoration(
                             color: Colors.white,
                             shape: BoxShape.circle,
                           ),
                           child: Icon(
                             Icons.check_rounded,
                             color: const Color(0xff1C0D5A).withOpacity(_isLoading ? 0.3 : 1.0),
                             size: 22,
                           ),
                         ),
                       ),
                     ),
                   ],
                 ),
               ),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // 2. Profile Picture Section (Wrapped in GestureDetector for Native Gallery Access)
                      const SizedBox(height: 25),
                      GestureDetector(
                        onTap: _pickProfileImage,
                        behavior: HitTestBehavior.opaque,
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(3.0),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xff5D3EBC).withOpacity(0.8), width: 2),
                              ),
                              child: _selectedImageBytes != null
                                  ? ClipOval(
                                      child: SizedBox(
                                        width: 108,
                                        height: 108,
                                        child: Image.memory(
                                          _selectedImageBytes!,
                                          fit: BoxFit.cover,
                                          alignment: Alignment.center,
                                        ),
                                      ),
                                    )
                                  : (!kIsWeb && _selectedImagePath != null)
                                      ? ClipOval(
                                          child: SizedBox(
                                            width: 108,
                                            height: 108,
                                            child: Image.file(
                                              File(_selectedImagePath!),
                                              fit: BoxFit.cover,
                                              alignment: Alignment.center,
                                            ),
                                          ),
                                        )
                                      : UserAvatar(
                                          avatarUrl: AuthService().userProfilePicture,
                                          displayName: AuthService().userName,
                                          radius: 54,
                                          fontSize: 40,
                                        ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              "Edit picture",
                              style: TextStyle(
                                color: Color(0xff1C0D5A),
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // 3. Editable Fields List
                      const SizedBox(height: 40),
                      _buildEditableField(
                        "Name",
                        _nameController,
                        inputFormatters: [LengthLimitingTextInputFormatter(30)],
                      ),
                      _buildEditableField(
                        "Username",
                        _usernameController,
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(30),
                          FilteringTextInputFormatter.allow(RegExp(r'[a-z0-9_.]')),
                        ],
                      ),
                      _buildGenderDropdownField(),
                      _buildEditableField(
                        "Bio",
                        _bioController,
                        maxLines: 4,
                        inputFormatters: [LengthLimitingTextInputFormatter(150)],
                      ),
                      
                      // 4. Links Section
                      const Divider(height: 1, thickness: 0.5, color: Colors.black12),
                      _buildLinksRow(),

                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper for creating editable rows exactly like the design
  Widget _buildEditableField(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
    String? hint,
    List<TextInputFormatter>? inputFormatters,
  }) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 100,
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xff1C0D5A),
                ),
              ),
            ),
            Expanded(
              child: TextFormField(
                controller: controller,
                maxLines: maxLines,
                inputFormatters: inputFormatters,
                style: const TextStyle(fontSize: 15, color: Colors.black87),
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: const TextStyle(color: Colors.black38),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ],
        ),
      ),
      const Divider(height: 1, thickness: 0.5, color: Colors.black12),
    ],
  );

  Widget _buildGenderDropdownField() => Column(
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            const SizedBox(
              width: 100,
              child: Text(
                "Gender",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xff1C0D5A),
                ),
              ),
            ),
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedGender,
                  isExpanded: true,
                  hint: const Text(
                    "Select Gender",
                    style: TextStyle(fontSize: 15, color: Colors.black38),
                  ),
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.black54),
                  dropdownColor: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  style: const TextStyle(fontSize: 15, color: Colors.black87),
                  items: const [
                    DropdownMenuItem(value: "Male", child: Text("Male")),
                    DropdownMenuItem(value: "Female", child: Text("Female")),
                    DropdownMenuItem(value: "Other", child: Text("Other")),
                    DropdownMenuItem(value: "Prefer not to say", child: Text("Prefer not to say")),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedGender = value;
                    });
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      const Divider(height: 1, thickness: 0.5, color: Colors.black12),
    ],
  );

  Widget _buildLinksRow() {
    int totalCount = _customLinks.length;
    String subtitle = totalCount == 0 ? "Add external link" : "$totalCount ${totalCount == 1 ? 'link' : 'links'}";

    return Column(
      children: [
        GestureDetector(
          onTap: () => _showLinksManagerBottomSheet(context),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                const SizedBox(
                  width: 100,
                  child: Text(
                    "Links",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xff1C0D5A),
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 15,
                      color: totalCount == 0 ? const Color(0xff5D3EBC) : Colors.black87,
                      fontWeight: totalCount == 0 ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 15,
                  color: Colors.black38,
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1, thickness: 0.5, color: Colors.black12),
      ],
    );
  }

  void _showLinksManagerBottomSheet(BuildContext outerContext) {
    showModalBottomSheet(
      context: outerContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return SafeArea(
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                top: 12,
                left: 20,
                right: 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Handle Bar
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Links",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xff1C0D5A),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close_rounded, size: 18, color: Colors.black87),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Add links to your profile",
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 20),

                    for (int i = 0; i < _customLinks.length; i++)
                      _buildModalLinkItem(
                        title: _customLinks[i]['title'] ?? 'Link',
                        url: _customLinks[i]['url'] ?? '',
                        icon: Icons.link_rounded,
                        iconColor: const Color(0xff5D3EBC),
                        onDelete: () {
                          setState(() => _customLinks.removeAt(i));
                          setModalState(() {});
                        },
                      ),

                    const SizedBox(height: 12),

                    // Add External Link Button
                    GestureDetector(
                      onTap: () {
                        _showAddSingleLinkDialog(outerContext, setModalState);
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xffF1F5F9),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.add_rounded, color: Color(0xff5D3EBC), size: 22),
                            SizedBox(width: 12),
                            Text(
                              "Add external link",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xff5D3EBC),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildModalLinkItem({
    required String title,
    required String url,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onDelete,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xff1C0D5A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  url,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }

  void _showAddSingleLinkDialog(BuildContext parentContext, StateSetter setModalState) {
    final titleController = TextEditingController();
    final urlController = TextEditingController();

    showDialog(
      context: parentContext,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "Add Link",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xff1C0D5A),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: urlController,
              decoration: InputDecoration(
                hintText: "URL (e.g. https://... or @username)",
                labelText: "URL",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: titleController,
              decoration: InputDecoration(
                hintText: "Title (e.g. Instagram, Website, Portfolio)",
                labelText: "Title (Optional)",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              final url = urlController.text.trim();
              String title = titleController.text.trim();

              if (url.isEmpty) {
                ScaffoldMessenger.of(parentContext).showSnackBar(
                  const SnackBar(content: Text("Please enter a valid URL")),
                );
                return;
              }

              if (title.isEmpty) {
                if (url.toLowerCase().contains("instagram") || url.startsWith("@")) {
                  title = "Instagram";
                } else if (url.toLowerCase().contains("youtube")) {
                  title = "YouTube";
                } else {
                  title = "Website";
                }
              }

              setState(() {
                _customLinks.add({'title': title, 'url': url});
              });
              setModalState(() {});

              Navigator.pop(dialogContext);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xff2B1564),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("Add", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

}

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:hidely_new/services/auth_service.dart';
import 'package:hidely_new/services/api_service.dart';
import 'package:hidely_new/widgets/user_avatar.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}


class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _usernameController;
  late final TextEditingController _pronounsController;
  late final TextEditingController _bioController;
  late final TextEditingController _instagramController;
  late final TextEditingController _youtubeController;

  // Profile Image State Variables
  String? _selectedImagePath;
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: AuthService().userName);
    _usernameController = TextEditingController(text: AuthService().userUsername);
    _pronounsController = TextEditingController(text: AuthService().userPronouns);
    
    final originalBio = AuthService().userBio;
    String cleanBio = originalBio;
    String instagramUrl = '';
    String youtubeUrl = '';

    final RegExp instaReg = RegExp(r'Instagram:\s*(https?://[^\s\n]+|@[^\s\n]+|[^\s\n]+)', caseSensitive: false);
    final RegExp ytReg = RegExp(r'YouTube:\s*(https?://[^\s\n]+|@[^\s\n]+|[^\s\n]+)', caseSensitive: false);

    final instaMatch = instaReg.firstMatch(originalBio);
    if (instaMatch != null) {
      instagramUrl = instaMatch.group(1) ?? '';
      cleanBio = cleanBio.replaceAll(instaMatch.group(0) ?? '', '').trim();
    }

    final ytMatch = ytReg.firstMatch(originalBio);
    if (ytMatch != null) {
      youtubeUrl = ytMatch.group(1) ?? '';
      cleanBio = cleanBio.replaceAll(ytMatch.group(0) ?? '', '').trim();
    }

    _bioController = TextEditingController(text: cleanBio);
    _instagramController = TextEditingController(text: instagramUrl);
    _youtubeController = TextEditingController(text: youtubeUrl);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _pronounsController.dispose();
    _bioController.dispose();
    _instagramController.dispose();
    _youtubeController.dispose();
    super.dispose();
  }

  Future<void> _pickProfileImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _selectedImagePath = image.path;
        });
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

                            String finalBio = _bioController.text.trim();
                            if (_instagramController.text.trim().isNotEmpty) {
                              finalBio = '$finalBio\nInstagram: ${_instagramController.text.trim()}';
                            }
                            if (_youtubeController.text.trim().isNotEmpty) {
                              finalBio = '$finalBio\nYouTube: ${_youtubeController.text.trim()}';
                            }

                            final result = await ApiService().updateUserProfile(
                              token: AuthService().token ?? '',
                              name: _nameController.text,
                              username: _usernameController.text,
                              pronouns: _pronounsController.text,
                              bio: finalBio,
                              avatar: _selectedImagePath != null ? File(_selectedImagePath!) : null,
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
                              child: _selectedImagePath != null
                                  ? CircleAvatar(
                                      radius: 54,
                                      backgroundImage: FileImage(File(_selectedImagePath!)),
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
                              "Edit picture or avatar",
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
                      _buildEditableField("Name", _nameController),
                      _buildEditableField("Username", _usernameController),
                      _buildEditableField("Pronouns", _pronounsController, hint: "Optional"),
                      _buildEditableField("Bio", _bioController, maxLines: 4),
                      
                      // 4. Links Section
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            "Social Links",
                            style: TextStyle(
                                fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xff1C0D5A),
                            ),
                          ),
                        ),
                      ),
                      const Divider(height: 1, thickness: 0.5, color: Colors.black12),
                      _buildEditableField("Instagram", _instagramController, hint: "@username or link"),
                      _buildEditableField("YouTube", _youtubeController, hint: "@channel or link"),

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
  Widget _buildEditableField(String label, TextEditingController controller, {int maxLines = 1, String? hint}) => Column(
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

}

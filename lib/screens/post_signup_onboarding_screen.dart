import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:hidely_new/screens/main_wrapper.dart';
import 'package:hidely_new/services/api_service.dart';
import 'package:hidely_new/services/auth_service.dart';
import 'package:hidely_new/widgets/custom_snackbar.dart';
import 'package:hidely_new/widgets/user_avatar.dart';

class PostSignupOnboardingScreen extends StatefulWidget {
  const PostSignupOnboardingScreen({super.key});

  @override
  State<PostSignupOnboardingScreen> createState() =>
      _PostSignupOnboardingScreenState();
}

class _PostSignupOnboardingScreenState
    extends State<PostSignupOnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  File? _avatarFile;
  bool _isUploadingAvatar = false;
  String _username = "";
  String _displayName = "";
  String _bio = "";
  bool _inviteShared = false;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _username = AuthService().userUsername;
    _displayName = AuthService().userName;
    _bio = AuthService().userBio;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToNextPage() {
    FocusScope.of(context).unfocus();
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _finishOnboarding();
    }
  }

  void _goToPreviousPage() {
    FocusScope.of(context).unfocus();
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  Future<void> _finishOnboarding() async {
    if (_isUploadingAvatar) return;
    final token = AuthService().token;
    if (token != null && token.isNotEmpty) {
      final needsAvatar = _avatarFile != null;
      final needsUsername = _username.isNotEmpty && _username.toLowerCase() != AuthService().userUsername.toLowerCase();
      final needsName = _displayName.isNotEmpty && _displayName != AuthService().userName;
      final needsBio = _bio.isNotEmpty && _bio != AuthService().userBio;

      if (needsAvatar || needsUsername || needsName || needsBio) {
        setState(() => _isUploadingAvatar = true);
        try {
          final result = await ApiService().updateUserProfile(
            token: token,
            avatar: _avatarFile,
            username: needsUsername ? _username : null,
            name: needsName ? _displayName : null,
            bio: needsBio ? _bio : null,
          );
          if (result.success && result.data != null) {
            final userMap = result.data?['user'];
            if (userMap is Map) {
              await AuthService().updateUserData(Map<String, dynamic>.from(userMap));
            }
          }
        } catch (_) {
        } finally {
          if (mounted) setState(() => _isUploadingAvatar = false);
        }
      }
    }
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: "/main"),
        builder: (context) => const MainWrapper(),
      ),
      (route) => false,
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    Navigator.pop(context); // Close bottom sheet
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (picked != null) {
        setState(() {
          _avatarFile = File(picked.path);
        });
      }
    } catch (e) {
      if (mounted) {
        showHidelySnackBar(context, "Could not access photo: $e", isError: true);
      }
    }
  }

  void _showImagePickerSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                "Change Profile Photo",
                style: TextStyle(
                  color: Color(0xff1C0D5A),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xff2B1564).withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.photo_library_outlined, color: Color(0xff2B1564)),
                ),
                title: const Text(
                  "Choose from Gallery",
                  style: TextStyle(
                    color: Color(0xff1C0D5A),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () => _pickImage(ImageSource.gallery),
              ),
              ListTile(
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xff2B1564).withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.camera_alt_outlined, color: Color(0xff2B1564)),
                ),
                title: const Text(
                  "Take Photo",
                  style: TextStyle(
                    color: Color(0xff1C0D5A),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () => _pickImage(ImageSource.camera),
              ),
              if (_avatarFile != null)
                ListTile(
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.delete_outline, color: Colors.red),
                  ),
                  title: const Text(
                    "Remove Photo",
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _avatarFile = null;
                    });
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _uploadAvatarAndProceed() async {
    if (_avatarFile == null) {
      _goToNextPage();
      return;
    }

    final token = AuthService().token;
    if (token == null || token.isEmpty) {
      _goToNextPage();
      return;
    }

    setState(() {
      _isUploadingAvatar = true;
    });

    try {
      final result = await ApiService().updateUserProfile(
        token: token,
        avatar: _avatarFile,
      );

      if (result.success && result.data != null) {
        final newPic = result.data?['user']?['profile_picture'];
        if (newPic != null) {
          await AuthService().updateUserData({'profile_picture': newPic});
        }
      }
    } catch (_) {
      // Continue gracefully even if network is slow
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingAvatar = false;
        });
        _goToNextPage();
      }
    }
  }

  Future<void> _shareInviteWithFriends() async {
    const inviteText =
        'Join me on Hidely to discover hidden places and travel spots! https://hidely.app';
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: inviteText,
          subject: 'Join me on Hidely',
        ),
      );
    } catch (_) {
      await Clipboard.setData(const ClipboardData(text: inviteText));
    }
    if (!mounted) return;
    setState(() {
      _inviteShared = true;
    });
    showHidelySnackBar(context, "Invite link ready to share!", isError: false);
  }

  Future<void> _copyInviteLink() async {
    await Clipboard.setData(
      const ClipboardData(text: 'https://hidely.app'),
    );
    if (!mounted) return;
    setState(() {
      _inviteShared = true;
    });
    showHidelySnackBar(context, "Invite link copied!", isError: false);
  }

  // --- Sub-Screen 0: Edit Username ---
  void _openUsernameEditor() {
    final controller = TextEditingController(text: _username);
    String? localError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalContext, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.9,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xffE0F2FE), Color(0xffFDF7FF)],
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    // Header with back and checkmark
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(ctx),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: Color(0xff1C0D5A)),
                          ),
                        ),
                        const Text(
                          "Username",
                          style: TextStyle(
                            color: Color(0xff1C0D5A),
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        GestureDetector(
                          onTap: () async {
                            final newUsername = controller.text.trim().toLowerCase();
                            if (newUsername.isEmpty) {
                              setModalState(() {
                                localError = "Username cannot be empty";
                              });
                              return;
                            }
                            final usernameRegex = RegExp(r'^[a-z0-9]([a-z0-9_.]*[a-z0-9])?$');
                            if (newUsername.length < 3) {
                              setModalState(() {
                                localError = "Username must be at least 3 characters";
                              });
                              return;
                            }
                            if (newUsername.length > 30) {
                              setModalState(() {
                                localError = "Username cannot exceed 30 characters";
                              });
                              return;
                            }
                            if (!usernameRegex.hasMatch(newUsername)) {
                              setModalState(() {
                                localError = "Username can only contain lowercase letters, numbers, underscores, and periods.";
                              });
                              return;
                            }

                            // 15-day cooldown check if user already had a set username
                            if (_username.isNotEmpty && newUsername != _username.toLowerCase()) {
                              final daysLeft = AuthService().daysUntilUsernameChange;
                              if (daysLeft > 0) {
                                setModalState(() {
                                  localError = "You can only change your username once every 15 days. Please wait $daysLeft more day${daysLeft == 1 ? '' : 's'}.";
                                });
                                return;
                              }

                              final checkRes = await ApiService().checkUsernameAvailable(username: newUsername);
                              if (!checkRes.success) {
                                setModalState(() {
                                  localError = checkRes.message.isNotEmpty ? checkRes.message : "Username is already taken.";
                                });
                                return;
                              }
                            }

                            Navigator.pop(ctx);
                            setState(() {
                              _username = newUsername;
                            });

                            final token = AuthService().token;
                            if (token != null) {
                              await AuthService().updateUserData({
                                'username': newUsername,
                                'username_changed_at': DateTime.now().toIso8601String(),
                              });
                              ApiService().updateUserProfile(token: token, username: newUsername);
                            }
                          },
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: const BoxDecoration(
                              color: Color(0xff2B1564),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check, size: 20, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),

                    // Username Input Card
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.white.withOpacity(0.9), width: 1.2),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Username",
                            style: TextStyle(
                              color: const Color(0xff1C0D5A).withOpacity(0.5),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          TextField(
                            controller: controller,
                            autofocus: true,
                            inputFormatters: [
                              LengthLimitingTextInputFormatter(30),
                              FilteringTextInputFormatter.allow(RegExp(r'[a-z0-9_.]')),
                            ],
                            style: const TextStyle(
                              color: Color(0xff1C0D5A),
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            decoration: InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                              prefixText: "@",
                              prefixStyle: TextStyle(
                                color: const Color(0xff1C0D5A).withOpacity(0.6),
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              contentPadding: const EdgeInsets.symmetric(vertical: 6),
                              suffixIcon: controller.text.isNotEmpty
                                  ? GestureDetector(
                                      onTap: () {
                                        controller.clear();
                                        setModalState(() {});
                                      },
                                      child: const Icon(Icons.cancel, size: 18, color: Colors.grey),
                                    )
                                  : null,
                              suffixIconConstraints: const BoxConstraints(minWidth: 24, minHeight: 0),
                            ),
                            onChanged: (_) {
                              if (localError != null) setModalState(() => localError = null);
                            },
                          ),
                        ],
                      ),
                    ),
                    if (localError != null) ...[
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text(
                          localError!,
                          style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Text(
                      AuthService().daysUntilUsernameChange > 0
                          ? "You can only change your username once every 15 days. You will be able to change it again in ${AuthService().daysUntilUsernameChange} days."
                          : "You can change your username to any available handle. Once changed, you will be able to change it again after 15 days.",
                      style: TextStyle(
                        color: const Color(0xff1C0D5A).withOpacity(0.6),
                        fontSize: 13.5,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // --- Sub-Screen 1: Edit Name (Matching Image 5) ---
  void _openNameEditor() {
    final controller = TextEditingController(text: _displayName);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalContext, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.9,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xffE0F2FE), Color(0xffFDF7FF)],
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    // Header with back and checkmark
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(ctx),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: Color(0xff1C0D5A)),
                          ),
                        ),
                        const Text(
                          "Name",
                          style: TextStyle(
                            color: Color(0xff1C0D5A),
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        GestureDetector(
                          onTap: () async {
                            final newName = controller.text.trim();
                            if (newName.isEmpty) {
                              showHidelySnackBar(context, "Name cannot be empty", isError: true);
                              return;
                            }
                            Navigator.pop(ctx);
                            setState(() {
                              _displayName = newName;
                            });
                            final token = AuthService().token;
                            if (token != null) {
                              ApiService().updateUserProfile(token: token, name: newName);
                              AuthService().updateUserData({'name': newName});
                            }
                          },
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: const BoxDecoration(
                              color: Color(0xff2B1564),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check, size: 20, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),

                    // Name Input Card
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.white.withOpacity(0.9), width: 1.2),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Name",
                            style: TextStyle(
                              color: const Color(0xff1C0D5A).withOpacity(0.5),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          TextField(
                            controller: controller,
                            autofocus: true,
                            textCapitalization: TextCapitalization.words,
                            style: const TextStyle(
                              color: Color(0xff1C0D5A),
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            decoration: InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 6),
                              suffixIcon: controller.text.isNotEmpty
                                  ? GestureDetector(
                                      onTap: () {
                                        controller.clear();
                                        setModalState(() {});
                                      },
                                      child: const Icon(Icons.cancel, size: 18, color: Colors.grey),
                                    )
                                  : null,
                              suffixIconConstraints: const BoxConstraints(minWidth: 24, minHeight: 0),
                            ),
                            onChanged: (_) => setModalState(() {}),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Help people discover your profile by using the name that you're known by: either your full name, nickname or business name.\n\nYou can only change your name twice within 14 days.\n\nYour name is visible to everyone on and off Hidely.",
                      style: TextStyle(
                        color: const Color(0xff1C0D5A).withOpacity(0.6),
                        fontSize: 13.5,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // --- Sub-Screen 2: Edit Bio (Matching Image 4) ---
  void _openBioEditor() {
    final controller = TextEditingController(text: _bio);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalContext, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.9,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xffE0F2FE), Color(0xffFDF7FF)],
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    // Header with back and checkmark
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(ctx),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: Color(0xff1C0D5A)),
                          ),
                        ),
                        const Text(
                          "Bio",
                          style: TextStyle(
                            color: Color(0xff1C0D5A),
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        GestureDetector(
                          onTap: () async {
                            final newBio = controller.text.trim();
                            Navigator.pop(ctx);
                            setState(() {
                              _bio = newBio;
                            });
                            final token = AuthService().token;
                            if (token != null) {
                              ApiService().updateUserProfile(token: token, bio: newBio);
                              AuthService().updateUserData({'bio': newBio});
                            }
                          },
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: const BoxDecoration(
                              color: Color(0xff2B1564),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check, size: 20, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),

                    // Bio Input Card
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.white.withOpacity(0.9), width: 1.2),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Bio",
                                style: TextStyle(
                                  color: const Color(0xff1C0D5A).withOpacity(0.5),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                "${controller.text.length} / 150",
                                style: TextStyle(
                                  color: const Color(0xff1C0D5A).withOpacity(0.45),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: controller,
                            autofocus: true,
                            maxLines: 5,
                            maxLength: 150,
                            style: const TextStyle(
                              color: Color(0xff1C0D5A),
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              height: 1.4,
                            ),
                            decoration: const InputDecoration(
                              isDense: true,
                              counterText: "",
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                              hintText: "Tell your squad about yourself...",
                            ),
                            onChanged: (_) => setModalState(() {}),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Your bio is visible to everyone on and off Hidely.",
                      style: TextStyle(
                        color: const Color(0xff1C0D5A).withOpacity(0.6),
                        fontSize: 13.5,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          if (_currentPage > 0) {
            _goToPreviousPage();
          } else {
            _finishOnboarding();
          }
        },
        child: Scaffold(
          body: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xffE0F2FE), Color(0xffFDF7FF)],
              ),
            ),
            child: SafeArea(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (idx) {
                  setState(() {
                    _currentPage = idx;
                  });
                },
                children: [
                  _buildAddPictureStep(),
                  _buildSyncContactsStep(),
                  _buildProfileVibeStep(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // SCREEN 1: Add a profile picture (Image 1)
  // ==========================================
  Widget _buildAddPictureStep() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),
          const Text(
            "Add a profile picture",
            style: TextStyle(
              color: Color(0xff1C0D5A),
              fontSize: 28,
              fontWeight: FontWeight.bold,
              height: 1.25,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "Add a profile picture so that your friends know it's you. Everyone will be able to see your picture.",
            style: TextStyle(
              color: const Color(0xff1C0D5A).withOpacity(0.65),
              fontSize: 15,
              height: 1.45,
            ),
          ),
          const Spacer(flex: 2),

          // Large Avatar Circle
          Center(
            child: GestureDetector(
              onTap: _showImagePickerSheet,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.8),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.9),
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xff1C0D5A).withOpacity(0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: _avatarFile != null
                      ? Image.file(
                          _avatarFile!,
                          width: 180,
                          height: 180,
                          fit: BoxFit.cover,
                        )
                      : Center(
                          child: Icon(
                            Icons.person_rounded,
                            size: 96,
                            color: const Color(0xff1C0D5A).withOpacity(0.25),
                          ),
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (_avatarFile != null)
            Center(
              child: Text(
                "Tap circle to change",
                style: TextStyle(
                  color: const Color(0xff1C0D5A).withOpacity(0.5),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

          const Spacer(flex: 3),

          // Action Buttons
          if (_avatarFile == null) ...[
            _buildPillButton(
              text: "Add picture",
              isPrimary: true,
              onPressed: _showImagePickerSheet,
            ),
            const SizedBox(height: 14),
            _buildPillButton(
              text: "Skip",
              isPrimary: false,
              onPressed: _goToNextPage,
            ),
          ] else ...[
            _buildPillButton(
              text: _isUploadingAvatar ? "Saving..." : "Next",
              isPrimary: true,
              isLoading: _isUploadingAvatar,
              onPressed: _uploadAvatarAndProceed,
            ),
            const SizedBox(height: 14),
            _buildPillButton(
              text: "Change picture",
              isPrimary: false,
              onPressed: _showImagePickerSheet,
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ==========================================
  // SCREEN 2: Sync Device Contacts (Image 2)
  // ==========================================
  Widget _buildSyncContactsStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          // Top bar with Back and Skip
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: _goToPreviousPage,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Image.asset(
                      'assets/images/back_icon.png',
                      color: const Color(0xff1C0D5A),
                      width: 18.0,
                      height: 18.0,
                    ),
                  ),
                ),
              ),
              GestureDetector(
                onTap: _goToNextPage,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    "Skip",
                    style: TextStyle(
                      color: Color(0xff5D3EBC),
                      fontWeight: FontWeight.bold,
                      fontSize: 14.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            "Invite friends to explore with you",
            style: TextStyle(
              color: Color(0xff1C0D5A),
              fontSize: 27,
              fontWeight: FontWeight.bold,
              height: 1.25,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "Share your Hidely invite link using your device share sheet. Hidely never accesses, uploads, or stores your device contacts.",
            style: TextStyle(
              color: const Color(0xff1C0D5A).withOpacity(0.65),
              fontSize: 14.5,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),

          // Graphic Illustration Card matching Instagram
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.75),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: Colors.white.withOpacity(0.9), width: 1.4),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xff1C0D5A).withOpacity(0.05),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                // Mock contact list placeholders
                for (int i = 0; i < 3; i++) ...[
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xff1C0D5A).withOpacity(0.08),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.person,
                          size: 20,
                          color: const Color(0xff1C0D5A).withOpacity(0.3),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              height: 10,
                              width: i == 0 ? 120 : (i == 1 ? 95 : 140),
                              decoration: BoxDecoration(
                                color: const Color(0xff1C0D5A).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(5),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              height: 8,
                              width: 70,
                              decoration: BoxDecoration(
                                color: const Color(0xff1C0D5A).withOpacity(0.06),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xff1C0D5A).withOpacity(0.2),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (i < 2) const SizedBox(height: 14),
                ],
                const SizedBox(height: 24),

                // Card action buttons
                _buildPillButton(
                  text: "Copy invite link",
                  isPrimary: false,
                  height: 48,
                  onPressed: _copyInviteLink,
                ),
                const SizedBox(height: 10),
                _buildPillButton(
                  text: _inviteShared ? "Invite Shared ✓" : "Share invite link",
                  isPrimary: true,
                  height: 48,
                  onPressed: _shareInviteWithFriends,
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),
          Center(
            child: Text(
              "Privacy-first: your phone contacts stay private on your device.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: const Color(0xff1C0D5A).withOpacity(0.55),
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 16),

          _buildPillButton(
            text: "Next",
            isPrimary: true,
            onPressed: _goToNextPage,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ==========================================
  // SCREEN 3: Create a profile that shows your vibe (Image 3)
  // ==========================================
  Widget _buildProfileVibeStep() {
    final activeUsername = _username.isNotEmpty ? _username : AuthService().userUsername;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          // Top bar with Back and Skip
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: _goToPreviousPage,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Image.asset(
                      'assets/images/back_icon.png',
                      color: const Color(0xff1C0D5A),
                      width: 18.0,
                      height: 18.0,
                    ),
                  ),
                ),
              ),
              GestureDetector(
                onTap: _finishOnboarding,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    "Skip",
                    style: TextStyle(
                      color: Color(0xff5D3EBC),
                      fontWeight: FontWeight.bold,
                      fontSize: 14.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            "Create a profile that shows your vibe",
            style: TextStyle(
              color: Color(0xff1C0D5A),
              fontSize: 27,
              fontWeight: FontWeight.bold,
              height: 1.25,
              letterSpacing: -0.6,
            ),
          ),
          const Spacer(flex: 1),

          // Central Profile Card matching Image 3
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.8),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withOpacity(0.9), width: 1.4),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xff1C0D5A).withOpacity(0.06),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                // Avatar with Camera Overlay
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    GestureDetector(
                      onTap: _showImagePickerSheet,
                      child: Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xffE2E8F0),
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xff1C0D5A).withOpacity(0.08),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: _avatarFile != null
                              ? Image.file(
                                  _avatarFile!,
                                  width: 110,
                                  height: 110,
                                  fit: BoxFit.cover,
                                )
                              : UserAvatar(
                                  avatarUrl: AuthService().userProfilePicture,
                                  displayName: _displayName.isNotEmpty ? _displayName : activeUsername,
                                  radius: 55,
                                ),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: _showImagePickerSheet,
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: const Color(0xff5D3EBC),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.5),
                        ),
                        child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Username Pill Tag
                GestureDetector(
                  onTap: _openUsernameEditor,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xff2B1564).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xff5D3EBC).withOpacity(0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "@${activeUsername.isNotEmpty ? activeUsername : 'username'}",
                          style: const TextStyle(
                            color: Color(0xff2B1564),
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.edit_rounded, size: 14, color: Color(0xff5D3EBC)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Add / Edit Username
                GestureDetector(
                  onTap: _openUsernameEditor,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.8), width: 1.2),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.alternate_email_rounded, size: 20, color: const Color(0xff1C0D5A).withOpacity(0.6)),
                            const SizedBox(width: 12),
                            Text(
                              activeUsername.isNotEmpty ? "@$activeUsername" : "Add username",
                              style: TextStyle(
                                color: activeUsername.isNotEmpty ? const Color(0xff1C0D5A) : const Color(0xff5D3EBC),
                                fontSize: 15,
                                fontWeight: activeUsername.isNotEmpty ? FontWeight.w600 : FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Icon(Icons.chevron_right_rounded, size: 20, color: const Color(0xff1C0D5A).withOpacity(0.4)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Add / Edit Name
                GestureDetector(
                  onTap: _openNameEditor,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.8), width: 1.2),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.person_outline, size: 20, color: const Color(0xff1C0D5A).withOpacity(0.6)),
                            const SizedBox(width: 12),
                            Text(
                              _displayName.isNotEmpty ? _displayName : "Add name",
                              style: TextStyle(
                                color: _displayName.isNotEmpty ? const Color(0xff1C0D5A) : const Color(0xff5D3EBC),
                                fontSize: 15,
                                fontWeight: _displayName.isNotEmpty ? FontWeight.w600 : FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Icon(Icons.chevron_right_rounded, size: 20, color: const Color(0xff1C0D5A).withOpacity(0.4)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Add / Edit Bio
                GestureDetector(
                  onTap: _openBioEditor,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.8), width: 1.2),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Icon(Icons.edit_note_rounded, size: 22, color: const Color(0xff1C0D5A).withOpacity(0.6)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _bio.isNotEmpty ? _bio : "Add bio",
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: _bio.isNotEmpty ? const Color(0xff1C0D5A) : const Color(0xff5D3EBC),
                                    fontSize: 15,
                                    fontWeight: _bio.isNotEmpty ? FontWeight.w500 : FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, size: 20, color: const Color(0xff1C0D5A).withOpacity(0.4)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Spacer(flex: 2),

          _buildPillButton(
            text: "Next",
            isPrimary: true,
            isLoading: _isUploadingAvatar,
            onPressed: _finishOnboarding,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // --- Reusable Pill Button Widget matching Hidely Theme ---
  Widget _buildPillButton({
    required String text,
    required bool isPrimary,
    required VoidCallback onPressed,
    bool isLoading = false,
    double height = 56,
  }) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isPrimary ? const Color(0xff2B1564) : Colors.white.withOpacity(0.75),
          disabledBackgroundColor: const Color(0xff2B1564).withOpacity(0.7),
          elevation: 0,
          side: isPrimary ? null : BorderSide(color: Colors.white.withOpacity(0.8), width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                text,
                style: TextStyle(
                  color: isPrimary ? Colors.white : const Color(0xff1C0D5A),
                  fontSize: 16.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.2,
                ),
              ),
      ),
    );
  }
}


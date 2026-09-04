import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hidely_new/services/auth_service.dart';
import 'main_wrapper.dart';
import 'edit_profile_screen.dart';
import 'change_password_screen.dart';
import 'privacy_policy_screen.dart';
import 'terms_of_service_screen.dart';
import 'blocked_accounts_screen.dart';
import 'help_center_screen.dart';
import 'about_screen.dart';
import 'add_account_screen.dart';
import 'saved_trips_screen.dart';
import 'hire_traveller_screen.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsAndPrivacyScreen extends StatefulWidget {
  const SettingsAndPrivacyScreen({super.key});

  @override
  State<SettingsAndPrivacyScreen> createState() =>
      _SettingsAndPrivacyScreenState();
}

class _SettingsAndPrivacyScreenState
    extends State<SettingsAndPrivacyScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadApiKey();
  }

  void _loadApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    final notifsEnabled = prefs.getBool('enable_notifications') ?? true;
    if (mounted) {
      setState(() {
        _enableNotifications = notifsEnabled;
      });
    }
  }

  // Toggle states
  bool _enableNotifications = true;
  bool _saveOriginalPhotos = true;
  bool _highQualityUploads = false;

  static const Color _primary = Color(0xff2B1564);
  static const Color _primaryLight = Color(0xff4B2D8E);
  static const Color _bgTop = Color(0xffE0F2FE);
  static const Color _bgBottom = Colors.white;
  static const Color _cardBg = Colors.white;
  static const Color _dividerColor = Color(0xffF0EEFB);
  static const Color _subtitleColor = Color(0xff8E8AA0);
  static const Color _labelColor = Color(0xff3D2A7A);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _getSettingsList() {
    return [
      {
        'category': 'Your Account',
        'icon': Icons.person_outline_rounded,
        'items': [
          {
            'title': 'Edit Profile',
            'subtitle': 'Name, username, bio, profile photo',
            'icon': Icons.manage_accounts_outlined,
            'iconBg': const Color(0xffEDE9FC),
            'iconColor': const Color(0xff5B3EC8),
            'onTap': () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const EditProfileScreen())),
          },
          {
            'title': 'Password & Security',
            'subtitle': 'Change password and protect account',
            'icon': Icons.shield_outlined,
            'iconBg': const Color(0xffE6F7EE),
            'iconColor': const Color(0xff29A96A),
            'onTap': () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const ChangePasswordScreen())),
          },
          {
            'title': 'App Permissions',
            'subtitle': 'Location, camera, microphone, gallery',
            'icon': Icons.security_outlined,
            'iconBg': const Color(0xffE8F5E9),
            'iconColor': const Color(0xff388E3C),
            'onTap': () => openAppSettings(),
          },
          {
            'title': 'Download My Data',
            'subtitle': 'Request an archive of your account data',
            'icon': Icons.download_for_offline_outlined,
            'iconBg': const Color(0xffE0F2FE),
            'iconColor': const Color(0xff0288D1),
            'onTap': () => _handleDownloadMyData(),
          },
        ],
      },
      {
        'category': 'Travel Tools',
        'icon': Icons.travel_explore_rounded,
        'items': [
          {
            'title': 'Trip Planner & My Trips',
            'subtitle': 'AI-powered trip planner & your saved itineraries',
            'icon': Icons.map_rounded,
            'iconBg': const Color(0xffEDE9FC),
            'iconColor': const Color(0xff7C3AED),
            'onTap': () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SavedTripsScreen()),
            ),
          },
          {
            'title': 'Hire a Traveller',
            'subtitle': 'Connect with verified local explorers & guides',
            'icon': Icons.travel_explore_rounded,
            'iconBg': const Color(0xffE6F7EE),
            'iconColor': const Color(0xff059669),
            'onTap': () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HireTravellerScreen()),
            ),
          },
        ],
      },
      {
        'category': 'How you use Hidely',
        'icon': Icons.explore_outlined,
        'items': [
          {
            'title': 'Notifications',
            'subtitle': 'Receive push notifications',
            'icon': Icons.notifications_outlined,
            'iconBg': const Color(0xffFFF3E0),
            'iconColor': const Color(0xffF57C00),
            'toggle': true,
            'toggleValue': _enableNotifications,
            'onToggle': (val) async {
              setState(() => _enableNotifications = val);
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('enable_notifications', val);
              _showSnack(val ? 'Notifications enabled' : 'Notifications paused');
            },
          },
        ],
      },
      {
        'category': 'Who can see your content',
        'icon': Icons.visibility_outlined,
        'items': [
          {
            'title': 'Blocked Accounts',
            'subtitle': 'Manage who you have blocked',
            'icon': Icons.block_rounded,
            'iconBg': const Color(0xffFFEBEE),
            'iconColor': const Color(0xffD32F2F),
            'onTap': () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const BlockedAccountsScreen(),
              ),
            ),
          },
        ],
      },
      {
        'category': 'How others interact with you',
        'icon': Icons.people_outline_rounded,
        'items': [
          {
            'title': 'Tags and Mentions',
            'subtitle': 'Who can tag or mention you',
            'icon': Icons.alternate_email_rounded,
            'iconBg': const Color(0xffE8EAF6),
            'iconColor': const Color(0xff3949AB),
            'onTap': () => _showComingSoon('Tags & Mentions'),
          },
        ],
      },
      {
        'category': 'Your app and media',
        'icon': Icons.phone_android_outlined,
        'items': [
          {
            'title': 'Save Original Photos',
            'subtitle': 'Automatically save to camera roll',
            'icon': Icons.downloading_outlined,
            'iconBg': const Color(0xffE1F5FE),
            'iconColor': const Color(0xff0288D1),
            'toggle': true,
            'toggleValue': _saveOriginalPhotos,
            'onToggle': (val) => setState(() => _saveOriginalPhotos = val),
          },
          {
            'title': 'High Quality Uploads',
            'subtitle': 'Upload higher resolution media',
            'icon': Icons.hd_outlined,
            'iconBg': const Color(0xffECEFF1),
            'iconColor': const Color(0xff546E7A),
            'toggle': true,
            'toggleValue': _highQualityUploads,
            'onToggle': (val) => setState(() => _highQualityUploads = val),
          },
          {
            'title': 'Language',
            'subtitle': 'English (US)',
            'icon': Icons.language_outlined,
            'iconBg': const Color(0xffE0F7FA),
            'iconColor': const Color(0xff00ACC1),
            'onTap': () => _showComingSoon('Language Settings'),
          },
        ],
      },

      {
        'category': 'More info and support',
        'icon': Icons.help_outline_rounded,
        'items': [
          {
            'title': 'Help Center',
            'subtitle': 'Find answers to your questions',
            'icon': Icons.help_outline_rounded,
            'iconBg': const Color(0xffFFF3E0),
            'iconColor': const Color(0xffF4511E),
            'onTap': () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const HelpCenterScreen(),
              ),
            ),
          },
          {
            'title': 'Privacy Policy',
            'subtitle': 'How we handle your data',
            'icon': Icons.privacy_tip_outlined,
            'iconBg': const Color(0xffEDE7F6),
            'iconColor': const Color(0xff6A1B9A),
            'onTap': () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen())),
          },
          {
            'title': 'Terms of Service',
            'subtitle': 'Read our usage terms',
            'icon': Icons.article_outlined,
            'iconBg': const Color(0xffE8EAF6),
            'iconColor': const Color(0xff3949AB),
            'onTap': () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const TermsOfServiceScreen())),
          },
          {
            'title': 'Contact Support',
            'subtitle': 'Reach out to our 24/7 team',
            'icon': Icons.headset_mic_outlined,
            'iconBg': const Color(0xffE0F2FE),
            'iconColor': const Color(0xff0288D1),
            'onTap': () => _handleContactSupport(),
          },
          {
            'title': 'About Hidely',
            'subtitle': 'Version 1.0.0 (Build 100)',
            'icon': Icons.info_outline_rounded,
            'iconBg': const Color(0xffECEFF1),
            'iconColor': const Color(0xff607D8B),
            'onTap': () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AboutScreen(),
              ),
            ),
          },
        ],
      },
      {
        'category': 'Account Actions',
        'icon': Icons.logout_rounded,
        'items': [
          {
            'title': 'Add Account',
            'subtitle': 'Switch between multiple accounts',
            'icon': Icons.add_circle_outline_rounded,
            'iconBg': const Color(0xffEDE9FC),
            'iconColor': _primary,
            'onTap': () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AddAccountScreen(),
              ),
            ),
          },
          {
            'title': 'Logout',
            'subtitle': 'Sign out from your account',
            'icon': Icons.logout_rounded,
            'iconBg': const Color(0xffFFEBEE),
            'iconColor': const Color(0xffD32F2F),
            'isDestructive': true,
            'onTap': () => _handleLogout(),
          },
          {
            'title': 'Delete Account',
            'subtitle': 'Permanently remove your data and account',
            'icon': Icons.delete_forever_rounded,
            'iconBg': const Color(0xffFFEBEE),
            'iconColor': Colors.redAccent,
            'isDestructive': true,
            'onTap': () => _handleDeleteAccount(),
          },
        ],
      },
    ];
  }

  void _handleDownloadMyData() {
    _showSnack('Data export requested! We will email your archive link within 24 hours.');
  }

  void _handleContactSupport() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Contact Support', style: TextStyle(color: Color(0xff1C0D5A), fontWeight: FontWeight.bold)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Need help or found an issue? Our team is available 24/7.', style: TextStyle(fontSize: 13, color: Colors.black87)),
            SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.email_outlined, size: 18, color: Color(0xff2B1564)),
                SizedBox(width: 8),
                Text('support@hidely.app', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xff2B1564))),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Color(0xff2B1564), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _handleDeleteAccount() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.red.shade50, shape: BoxShape.circle),
                child: const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 36),
              ),
              const SizedBox(height: 16),
              const Text('Delete Account?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xff1C0D5A))),
              const SizedBox(height: 8),
              const Text(
                'Are you sure you want to permanently delete your account? All your posts, saved places, and data will be erased immediately and cannot be recovered.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.black54, height: 1.4),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: const Text('Cancel', style: TextStyle(color: Color(0xff1C0D5A), fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await AuthService().logout();
                        if (mounted) {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(builder: (_) => const MainWrapper(initialIndex: 0)),
                            (route) => false,
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: const TextStyle(fontFamily: 'PublicSans', fontWeight: FontWeight.w500)),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: _primary,
      duration: const Duration(seconds: 2),
    ));
  }

  void _showComingSoon(String feature) {
    _showSnack('$feature coming soon!');
  }

  void _handleLogout() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: Color(0xffFFEBEE),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.logout_rounded,
                    color: Color(0xffD32F2F), size: 28),
              ),
              const SizedBox(height: 16),
              const Text(
                'Logout',
                style: TextStyle(
                  fontFamily: 'PublicSans',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xff1A1A2E),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Are you sure you want to\nlogout from Hidely?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'PublicSans',
                  fontSize: 14,
                  color: Color(0xff8E8AA0),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        height: 46,
                        decoration: BoxDecoration(
                          color: const Color(0xffF4F2FB),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Text('Cancel',
                              style: TextStyle(
                                fontFamily: 'PublicSans',
                                fontWeight: FontWeight.w600,
                                color: Color(0xff2B1564),
                              )),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        Navigator.pop(ctx);
                        await AuthService().logout();
                        if (context.mounted) {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(builder: (_) => const MainWrapper(initialIndex: 0)),
                            (route) => false,
                          );
                        }
                      },
                      child: Container(
                        height: 46,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xffD32F2F), Color(0xffEF5350)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Text('Logout',
                              style: TextStyle(
                                fontFamily: 'PublicSans',
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              )),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allCategories = _getSettingsList();
    final List<Map<String, dynamic>> filteredCategories = [];

    for (var cat in allCategories) {
      final items = cat['items'] as List<Map<String, dynamic>>;
      final filteredItems = items.where((item) {
        final title = item['title'].toString().toLowerCase();
        final subtitle = (item['subtitle'] ?? '').toString().toLowerCase();
        return title.contains(_searchQuery.toLowerCase()) ||
            subtitle.contains(_searchQuery.toLowerCase());
      }).toList();

      if (filteredItems.isNotEmpty) {
        filteredCategories.add({
          'category': cat['category'],
          'icon': cat['icon'],
          'items': filteredItems,
        });
      }
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xffF8F6FF),
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_bgTop, _bgBottom],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // ─── Custom App Bar ───────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: _primary.withOpacity(0.08),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Image.asset(
                              'assets/images/back_icon.png',
                              color: _primary,
                              width: 18,
                              height: 18,
                            ),
                          ),
                        ),
                      ),
                      const Expanded(
                        child: Text(
                          'Settings & Privacy',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'PublicSans',
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Color(0xff1A1235),
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                      const SizedBox(width: 40), // Balance the back button on the left
                    ],
                  ),
                ),

                // ─── Search Bar ───────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: _primary.withOpacity(0.06),
                          blurRadius: 12,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) => setState(() => _searchQuery = val),
                      style: const TextStyle(
                        fontFamily: 'PublicSans',
                        fontSize: 14,
                        color: Color(0xff1A1235),
                      ),
                      decoration: InputDecoration(
                        prefixIcon: Icon(Icons.search_rounded,
                            color: _primary.withOpacity(0.4), size: 20),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? GestureDetector(
                                onTap: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                                child: const Icon(Icons.close_rounded,
                                    color: _subtitleColor, size: 18),
                              )
                            : null,
                        hintText: 'Search settings...',
                        hintStyle: TextStyle(
                          fontFamily: 'PublicSans',
                          fontSize: 14,
                          color: _subtitleColor.withOpacity(0.7),
                        ),
                        border: InputBorder.none,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ),

                // ─── List ─────────────────────────────────────────────────
                Expanded(
                  child: filteredCategories.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  color: _primary.withOpacity(0.06),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.search_off_rounded,
                                    size: 36,
                                    color: _primary.withOpacity(0.3)),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No results for "$_searchQuery"',
                                style: const TextStyle(
                                  fontFamily: 'PublicSans',
                                  fontSize: 15,
                                  color: Color(0xff8E8AA0),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.only(bottom: 40),
                          itemCount: filteredCategories.length,
                          itemBuilder: (context, catIdx) {
                            final cat = filteredCategories[catIdx];
                            final items =
                                cat['items'] as List<Map<String, dynamic>>;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Category header
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                      20, 18, 20, 8),
                                  child: Row(
                                    children: [
                                      Icon(
                                        cat['icon'] as IconData,
                                        size: 14,
                                        color: _primaryLight,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        (cat['category'] as String)
                                            .toUpperCase(),
                                        style: const TextStyle(
                                          fontFamily: 'PublicSans',
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: _labelColor,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Category items card
                                Container(
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  decoration: BoxDecoration(
                                    color: _cardBg,
                                    borderRadius: BorderRadius.circular(18),
                                    boxShadow: [
                                      BoxShadow(
                                        color: _primary.withOpacity(0.05),
                                        blurRadius: 16,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(18),
                                    child: Column(
                                      children: List.generate(items.length,
                                          (itemIdx) {
                                        final item = items[itemIdx];
                                        final isDestructive =
                                            item['isDestructive'] == true;
                                        final hasToggle =
                                            item['toggle'] == true;
                                        final isLast =
                                            itemIdx == items.length - 1;

                                        return Column(
                                          children: [
                                            InkWell(
                                              onTap: hasToggle
                                                  ? null
                                                  : item['onTap']
                                                      as VoidCallback?,
                                              borderRadius: itemIdx == 0
                                                  ? const BorderRadius.only(
                                                      topLeft:
                                                          Radius.circular(18),
                                                      topRight:
                                                          Radius.circular(18),
                                                    )
                                                  : isLast
                                                      ? const BorderRadius.only(
                                                          bottomLeft:
                                                              Radius.circular(
                                                                  18),
                                                          bottomRight:
                                                              Radius.circular(
                                                                  18),
                                                        )
                                                      : null,
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 16,
                                                        vertical: 13),
                                                child: Row(
                                                  children: [
                                                    // Icon container
                                                    Container(
                                                      width: 40,
                                                      height: 40,
                                                      decoration: BoxDecoration(
                                                        color: item['iconBg']
                                                            as Color,
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(11),
                                                      ),
                                                      child: Icon(
                                                        item['icon'] as IconData,
                                                        color: item['iconColor']
                                                            as Color,
                                                        size: 20,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 14),

                                                    // Text
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            item['title']
                                                                as String,
                                                            style: TextStyle(
                                                              fontFamily:
                                                                  'PublicSans',
                                                              fontSize: 14.5,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              color: isDestructive
                                                                  ? const Color(
                                                                      0xffD32F2F)
                                                                  : const Color(
                                                                      0xff1A1235),
                                                            ),
                                                          ),
                                                          if (item['subtitle'] !=
                                                              null) ...[
                                                            const SizedBox(
                                                                height: 2),
                                                            Text(
                                                              item['subtitle']
                                                                  as String,
                                                              style:
                                                                  const TextStyle(
                                                                fontFamily:
                                                                    'PublicSans',
                                                                fontSize: 12,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w400,
                                                                color: Color(
                                                                    0xff8E8AA0),
                                                              ),
                                                            ),
                                                          ],
                                                        ],
                                                      ),
                                                    ),

                                                    // Trailing: toggle or chevron
                                                    if (hasToggle)
                                                      Transform.scale(
                                                        scale: 0.85,
                                                        child: Switch(
                                                          value: item[
                                                                  'toggleValue']
                                                              as bool,
                                                          activeThumbColor: _primary,
                                                          activeTrackColor:
                                                              _primary
                                                                  .withOpacity(
                                                                      0.25),
                                                          onChanged:
                                                              item['onToggle']
                                                                  as Function(
                                                                      bool),
                                                        ),
                                                      )
                                                    else
                                                      Icon(
                                                        Icons
                                                            .chevron_right_rounded,
                                                        color: isDestructive
                                                            ? const Color(
                                                                0xffD32F2F)
                                                            : _subtitleColor
                                                                .withOpacity(
                                                                    0.5),
                                                        size: 20,
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            ),

                                            // Divider (not after last item)
                                            if (!isLast)
                                              const Padding(
                                                padding: EdgeInsets.only(
                                                    left: 70, right: 16),
                                                child: Divider(
                                                  height: 1,
                                                  color: _dividerColor,
                                                ),
                                              ),
                                          ],
                                        );
                                      }),
                                    ),
                                  ),
                                ),
                              ],
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
}

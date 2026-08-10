import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:hidely_new/widgets/report_bottom_sheet.dart';
import 'package:hidely_new/services/api_service.dart';
import 'package:hidely_new/services/auth_service.dart';
import 'package:hidely_new/screens/feed_screen.dart';
import 'package:hidely_new/screens/user_profile_screen.dart';
import 'package:hidely_new/screens/creator_profile_screen.dart';
import 'package:hidely_new/screens/single_post_view_screen.dart';
import 'package:hidely_new/screens/reels_screen.dart';

class PostOptionsBottomSheet extends StatefulWidget {
  final dynamic post;

  const PostOptionsBottomSheet({super.key, required this.post});

  @override
  State<PostOptionsBottomSheet> createState() => _PostOptionsBottomSheetState();
}

class _PostOptionsBottomSheetState extends State<PostOptionsBottomSheet> {
  final TextEditingController _aiQueryController = TextEditingController();
  bool _isSaved = false;
  bool _isFavourite = false;

  @override
  void initState() {
    super.initState();
    _isSaved = widget.post['is_saved'] == true || widget.post['isSaved'] == true;
    _isFavourite = widget.post['is_favourite'] == true;
  }

  @override
  void dispose() {
    _aiQueryController.dispose();
    super.dispose();
  }

  bool get _isMyPost {
    final String currentUsername = AuthService().userUsername;
    final String currentUserId = AuthService().userId;

    final String authorUsername = (widget.post["author_username"] ?? widget.post["username"] ?? '').toString();
    final String authorId = (widget.post["author_id"] ?? widget.post["user_id"] ?? '').toString();

    if (widget.post["isAsset"] == true) return false;

    if (currentUsername.isNotEmpty && authorUsername.isNotEmpty && authorUsername == currentUsername) {
      return true;
    }
    if (currentUserId.isNotEmpty && authorId.isNotEmpty && authorId == currentUserId) {
      return true;
    }

    return authorUsername.isEmpty && authorId.isEmpty;
  }

  void _askAi(String query) {
    if (query.trim().isEmpty) return;
    final q = _aiQueryController.text;
    _aiQueryController.clear();
    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                "Asking AI: \"$q\"...",
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xff1C0D5A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _toggleSave() {
    setState(() {
      _isSaved = !_isSaved;
      widget.post['is_saved'] = _isSaved;
      widget.post['isSaved'] = _isSaved;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(_isSaved ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Text(_isSaved ? "Saved to your bookmarks!" : "Removed from bookmarks."),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xff1C0D5A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showQrCode() {
    final String postId = widget.post['id']?.toString() ?? '8924';
    final String shareUrl = "https://hidely.app/post/$postId";

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text("Post QR Code", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.qr_code_2_rounded, size: 140, color: Color(0xff1C0D5A)),
            ),
            const SizedBox(height: 12),
            Text(shareUrl, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Close", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _toggleFavourite() {
    setState(() {
      _isFavourite = !_isFavourite;
      widget.post['is_favourite'] = _isFavourite;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(_isFavourite ? Icons.star_rounded : Icons.star_outline_rounded, color: Colors.amber, size: 20),
            const SizedBox(width: 10),
            Text(_isFavourite ? "Added to Favourites!" : "Removed from Favourites."),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xff1C0D5A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _unfollowUser() {
    final username = widget.post['author_username'] ?? widget.post['username'] ?? 'user';
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Unfollowed @$username"),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xff1C0D5A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _aboutAccount() {
    Navigator.pop(context);
    final String authorUsername = (widget.post["author_username"] ?? widget.post["username"] ?? 'Traveler').toString();
    final String authorAvatar = (widget.post["author_avatar"] ?? widget.post["avatar"] ?? '').toString();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreatorProfileScreen(
          username: authorUsername.isNotEmpty ? authorUsername : 'Traveler',
          avatarPath: authorAvatar,
          rank: 'Explorer',
        ),
      ),
    );
  }

  void _whySeeingThis() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.info_outline_rounded, color: Color(0xff1C0D5A)),
            SizedBox(width: 8),
            Text("Why you're seeing this", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          "This post is shown based on travel destinations you explore and creators you interact with on Hidely.",
          style: TextStyle(fontSize: 13.5, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Got it", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _notInterested() {
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text("We'll show fewer posts like this."),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xff1C0D5A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _reportPost() {
    Navigator.pop(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReportBottomSheet(
        targetType: 'Post',
        targetName: widget.post['caption']?.toString() ?? 'Post',
        onSubmitSuccess: () {},
      ),
    );
  }

  void _deletePost() {
    final String postIdStr = widget.post['id']?.toString() ?? '';
    if (postIdStr.isEmpty) return;
    final int postId = int.tryParse(postIdStr) ?? 0;

    AuthService().markPostAsDeletedLocally(postIdStr);

    final messenger = ScaffoldMessenger.of(context);

    FeedScreen.activeState?.removePostLocally(postId);
    UserProfileScreen.activeState?.removePostLocally(postId);
    SinglePostViewScreen.activeState?.removePostLocally(postId);
    ReelsScreen.activeState?.removePostLocally(postId);

    Navigator.of(context).pop();

    messenger.showSnackBar(
      SnackBar(
        content: const Text("Post deleted successfully!"),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xff1C0D5A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
      ),
    );

    if (postId != 0) {
      final token = AuthService().token ?? '';
      ApiService().deletePost(postId: postId, token: token);
    }
  }

  void _editPost() {
    Navigator.pop(context);
    final TextEditingController captionController = TextEditingController(text: widget.post['caption']?.toString() ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Edit Post Caption", style: TextStyle(color: Color(0xff1C0D5A), fontWeight: FontWeight.bold)),
        content: TextField(
          controller: captionController,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: "Update caption...",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xff1C0D5A)),
            onPressed: () {
              widget.post['caption'] = captionController.text;
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Post caption updated!"), behavior: SnackBarBehavior.floating),
              );
            },
            child: const Text("Save", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildGroupTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color color = Colors.black87,
    bool isDestructive = false,
  }) {
    final textColor = isDestructive ? const Color(0xFFEF4444) : color;
    final iconColor = isDestructive ? const Color(0xFFEF4444) : color;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: 21),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isDestructive ? FontWeight.w600 : FontWeight.w500,
                    color: textColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(16, 12, 16, bottomPadding > 0 ? bottomPadding + 12 : 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // About this post section (Instagram Style)
          const Text(
            "About this post",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            widget.post['caption']?.toString() ??
                "Discover amazing travel spots and hidden gems curated by travelers around the world.",
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13.5,
              color: Colors.black87,
              height: 1.38,
            ),
          ),
          const SizedBox(height: 12),

          // Ask Meta/Hidely AI anything input bar
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome_rounded, color: Color(0xff8B5CF6), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _aiQueryController,
                    style: const TextStyle(fontSize: 13.5, color: Colors.black87),
                    decoration: const InputDecoration(
                      hintText: "Ask Hidely AI anything...",
                      hintStyle: TextStyle(fontSize: 13.5, color: Colors.black45),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onSubmitted: (q) => _askAi(q),
                  ),
                ),
                GestureDetector(
                  onTap: () => _askAi(_aiQueryController.text),
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: const BoxDecoration(
                      color: Color(0xFFCBD5E1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.navigation_rounded, color: Colors.white, size: 14),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Group 1 Card: Save, QR code
          _buildGroupCard(
            children: [
              _buildGroupTile(
                icon: _isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                title: _isSaved ? "Saved" : "Save",
                color: _isSaved ? const Color(0xff1C0D5A) : Colors.black87,
                onTap: _toggleSave,
              ),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              _buildGroupTile(
                icon: Icons.qr_code_scanner_rounded,
                title: "QR code",
                onTap: _showQrCode,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Group 2 Card: Add to Favourites, Unfollow
          _buildGroupCard(
            children: [
              _buildGroupTile(
                icon: _isFavourite ? Icons.star_rounded : Icons.star_outline_rounded,
                title: _isFavourite ? "Favourited" : "Add to Favourites",
                color: _isFavourite ? Colors.amber.shade700 : Colors.black87,
                onTap: _toggleFavourite,
              ),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              _buildGroupTile(
                icon: Icons.person_remove_outlined,
                title: "Unfollow",
                onTap: _unfollowUser,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Group 3 Card: About account, Why seeing, Not interested, Report
          _buildGroupCard(
            children: [
              _buildGroupTile(
                icon: Icons.account_circle_outlined,
                title: "About this account",
                onTap: _aboutAccount,
              ),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              _buildGroupTile(
                icon: Icons.info_outline_rounded,
                title: "Why you're seeing this post",
                onTap: _whySeeingThis,
              ),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              _buildGroupTile(
                icon: Icons.visibility_off_outlined,
                title: "Not interested",
                onTap: _notInterested,
              ),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              _buildGroupTile(
                icon: Icons.error_outline_rounded,
                title: "Report",
                isDestructive: true,
                onTap: _reportPost,
              ),
            ],
          ),

          // Author options if author of post
          if (_isMyPost) ...[
            const SizedBox(height: 12),
            _buildGroupCard(
              children: [
                _buildGroupTile(
                  icon: Icons.edit_note_rounded,
                  title: "Edit Post Caption",
                  onTap: _editPost,
                ),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                _buildGroupTile(
                  icon: Icons.delete_outline_rounded,
                  title: "Delete Post",
                  isDestructive: true,
                  onTap: _deletePost,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Instagram-Style Share Sheet Widget
class ShareToChatBottomSheet extends StatefulWidget {
  final dynamic post;

  const ShareToChatBottomSheet({super.key, required this.post});

  @override
  State<ShareToChatBottomSheet> createState() => _ShareToChatBottomSheetState();
}

class _ShareToChatBottomSheetState extends State<ShareToChatBottomSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  final List<Map<String, dynamic>> _users = [
    {
      "id": "1",
      "name": "Eleni K.",
      "username": "eleni_k",
      "avatar": "https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=150",
      "selected": false,
    },
    {
      "id": "2",
      "name": "Manali Squad 🏔️",
      "username": "group_manali",
      "avatar": "https://images.unsplash.com/photo-1506744038136-46273834b3fb?w=150",
      "selected": false,
    },
    {
      "id": "3",
      "name": "Aarav Sharma",
      "username": "aarav_s",
      "avatar": "https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=150",
      "selected": false,
    },
    {
      "id": "4",
      "name": "Priya Verma",
      "username": "priya_v",
      "avatar": "https://images.unsplash.com/photo-1570295999919-56ceb5ecca61?w=150",
      "selected": false,
    },
    {
      "id": "5",
      "name": "Goa Lovers 🏖️",
      "username": "goa_squad",
      "avatar": "https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=150",
      "selected": false,
    },
    {
      "id": "6",
      "name": "Rohan Gupta",
      "username": "rohan_g",
      "avatar": "https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150",
      "selected": false,
    },
    {
      "id": "7",
      "name": "Sneha Kapoor",
      "username": "sneha_k",
      "avatar": "https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=150",
      "selected": false,
    },
    {
      "id": "8",
      "name": "Vikram Singh",
      "username": "vikram_s",
      "avatar": "https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=150",
      "selected": false,
    },
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool get _hasSelection => _users.any((u) => u["selected"] == true);
  int get _selectedCount => _users.where((u) => u["selected"] == true).length;

  void _handleSend() {
    final selectedNames = _users
        .where((u) => u["selected"] == true)
        .map((u) => u["name"])
        .join(", ");

    HapticFeedback.lightImpact();
    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                "Sent to $selectedNames!",
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xff1C0D5A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _copyLink() {
    final String postId = widget.post?['id']?.toString() ?? '';
    Clipboard.setData(ClipboardData(text: "https://hidely.app/post/$postId"));
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.link_rounded, color: Colors.white, size: 20),
            SizedBox(width: 10),
            Text("Link copied to clipboard!"),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xff1C0D5A),
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _shareExternal() {
    Navigator.pop(context);
    final String postId = widget.post?['id']?.toString() ?? '';
    // ignore: deprecated_member_use
    Share.share("Check out this post on Hidely! https://hidely.app/post/$postId");
  }

  void _reportPost() {
    Navigator.pop(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReportBottomSheet(
        targetType: 'Post',
        targetName: widget.post?['caption']?.toString() ?? 'Post',
        onSubmitSuccess: () {},
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double bottomPadding = MediaQuery.of(context).padding.bottom;
    final double bottomKeyboard = MediaQuery.of(context).viewInsets.bottom;

    final filteredUsers = _users.where((u) {
      final name = u["name"].toString().toLowerCase();
      final username = u["username"].toString().toLowerCase();
      return name.contains(_searchQuery.toLowerCase()) ||
          username.contains(_searchQuery.toLowerCase());
    }).toList();

    return Padding(
      padding: EdgeInsets.only(bottom: bottomKeyboard),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.74,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            // Drag Handle
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Instagram Style Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val),
                  style: const TextStyle(fontSize: 14, color: Color(0xff1C0D5A)),
                  decoration: InputDecoration(
                    hintText: "Search...",
                    hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                    prefixIcon: const Icon(Icons.search_rounded, color: Colors.grey, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? GestureDetector(
                            onTap: () {
                              _searchController.clear();
                              setState(() => _searchQuery = "");
                            },
                            child: const Icon(Icons.close_rounded, color: Colors.grey, size: 18),
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Instagram-Style Friends Grid
            Expanded(
              child: filteredUsers.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.search_off_rounded, size: 40, color: Colors.grey),
                          const SizedBox(height: 8),
                          Text(
                            "No matches for '$_searchQuery'",
                            style: const TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                        ],
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      physics: const BouncingScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 8,
                        childAspectRatio: 0.72,
                      ),
                      itemCount: filteredUsers.length,
                      itemBuilder: (context, index) {
                        final user = filteredUsers[index];
                        final isSelected = user["selected"] == true;

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              user["selected"] = !isSelected;
                            });
                          },
                          behavior: HitTestBehavior.opaque,
                          child: Column(
                            children: [
                              Stack(
                                children: [
                                  // Avatar
                                  Container(
                                    width: 58,
                                    height: 58,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isSelected ? const Color(0xff1C0D5A) : const Color(0xFFE2E8F0),
                                        width: isSelected ? 2 : 1,
                                      ),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(29),
                                      child: Image.network(
                                        user["avatar"],
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => CircleAvatar(
                                          backgroundColor: const Color(0xff1C0D5A).withOpacity(0.1),
                                          child: Text(
                                            user["name"].substring(0, 1).toUpperCase(),
                                            style: const TextStyle(
                                              color: Color(0xff1C0D5A),
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Instagram-style selection checkmark badge
                                  Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: Container(
                                      width: 20,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        color: isSelected ? const Color(0xff1C0D5A) : Colors.white,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isSelected ? Colors.white : const Color(0xFFCBD5E1),
                                          width: 1.5,
                                        ),
                                      ),
                                      child: isSelected
                                          ? const Icon(Icons.check_rounded, color: Colors.white, size: 12)
                                          : null,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                user["name"],
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xff1C0D5A),
                                ),
                              ),
                              Text(
                                "@${user["username"]}",
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),

            // Instagram Bottom Actions / Send Button Container
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            SafeArea(
              top: false,
              child: Container(
                padding: EdgeInsets.fromLTRB(16, 12, 16, bottomPadding > 0 ? bottomPadding + 4 : 12),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _hasSelection
                      ? SizedBox(
                          key: const ValueKey("send_button"),
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _handleSend,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xff1C0D5A),
                              foregroundColor: Colors.white,
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text(
                              "Send to $_selectedCount friend${_selectedCount > 1 ? 's' : ''}",
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        )
                      : Row(
                          key: const ValueKey("actions_row"),
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildInstaBottomAction(
                              icon: Icons.report_gmailerrorred_rounded,
                              label: "Report",
                              color: Colors.redAccent,
                              bgColor: Colors.red.shade50,
                              onTap: _reportPost,
                            ),
                            _buildInstaBottomAction(
                              icon: Icons.link_rounded,
                              label: "Copy link",
                              onTap: _copyLink,
                            ),
                            _buildInstaBottomAction(
                              icon: Icons.ios_share_rounded,
                              label: "Share to...",
                              onTap: _shareExternal,
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstaBottomAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = const Color(0xff1C0D5A),
    Color? bgColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: bgColor ?? const Color(0xFFF1F5F9),
              shape: BoxShape.circle,
              border: Border.all(color: color == Colors.redAccent ? Colors.red.shade200 : const Color(0xFFE2E8F0)),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: color == Colors.redAccent ? Colors.redAccent : const Color(0xff1C0D5A),
            ),
          ),
        ],
      ),
    );
  }
}

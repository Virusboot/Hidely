import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:hidely_new/screens/single_post_view_screen.dart';
import 'package:hidely_new/services/api_service.dart';
import 'package:hidely_new/services/auth_service.dart';
import 'package:hidely_new/widgets/user_avatar.dart';

class TagsAndMentionsScreen extends StatefulWidget {
  const TagsAndMentionsScreen({super.key});

  @override
  State<TagsAndMentionsScreen> createState() => _TagsAndMentionsScreenState();
}

class _TagsAndMentionsScreenState extends State<TagsAndMentionsScreen> {
  static const Color _primary = Color(0xff2B1564);
  static const Color _accent = Color(0xff5D3EBC);
  static const Color _titleColor = Color(0xff1C0D5A);
  static const Color _subtitleColor = Color(0xff8E8AA0);
  static const Color _dividerColor = Color(0xffF0EEFB);

  late String _allowTagsFrom;
  late String _allowMentionsFrom;
  late bool _manuallyApproveTags;

  bool _isSaving = false;
  bool _isLoadingTags = true;
  String? _tagsLoadError;
  List<Map<String, dynamic>> _taggedPosts = <Map<String, dynamic>>[];
  final Set<int> _processingPostIds = <int>{};

  @override
  void initState() {
    super.initState();
    _readFromAuthService();
    AuthService().tagMentionSettingsNotifier.addListener(_onSettingsNotifierChanged);
    _loadServerState();
  }

  @override
  void dispose() {
    AuthService().tagMentionSettingsNotifier.removeListener(_onSettingsNotifierChanged);
    super.dispose();
  }

  void _readFromAuthService() {
    final auth = AuthService();
    _allowTagsFrom = auth.allowTagsFrom;
    _allowMentionsFrom = auth.allowMentionsFrom;
    _manuallyApproveTags = auth.manuallyApproveTags;
  }

  void _onSettingsNotifierChanged() {
    if (!mounted) return;
    setState(_readFromAuthService);
  }

  Future<void> _loadServerState() async {
    await AuthService().syncTagMentionSettingsFromServer();
    await _loadTaggedPosts();
  }

  Future<void> _loadTaggedPosts() async {
    final token = AuthService().token ?? '';
    if (token.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoadingTags = false;
          _taggedPosts = <Map<String, dynamic>>[];
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isLoadingTags = true;
        _tagsLoadError = null;
      });
    }

    final result = await ApiService().getTaggedPosts(token: token);
    if (!mounted) return;

    if (result.success && result.data != null) {
      final raw = result.data?['tags'] as List? ?? [];
      setState(() {
        _taggedPosts = raw
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .where((e) => !AuthService().isPostFromBlockedUser(e))
            .toList();
        _isLoadingTags = false;
        _tagsLoadError = null;
      });
    } else {
      setState(() {
        _isLoadingTags = false;
        _tagsLoadError = result.statusCode == 404
            ? 'Tagged posts sync will become available once the backend update is deployed.'
            : (result.message.isNotEmpty ? result.message : 'Unable to load tagged posts.');
      });
    }
  }

  Future<void> _saveSettings({
    String? allowTagsFrom,
    String? allowMentionsFrom,
    bool? manuallyApproveTags,
  }) async {
    setState(() {
      if (allowTagsFrom != null) _allowTagsFrom = allowTagsFrom;
      if (allowMentionsFrom != null) _allowMentionsFrom = allowMentionsFrom;
      if (manuallyApproveTags != null) _manuallyApproveTags = manuallyApproveTags;
      _isSaving = true;
    });

    final res = await AuthService().updateTagMentionSettings(
      allowTagsFrom: allowTagsFrom,
      allowMentionsFrom: allowMentionsFrom,
      manuallyApproveTags: manuallyApproveTags,
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    final bool synced = res.data?['synced'] == true;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          synced
              ? 'Privacy preferences updated'
              : 'Saved on device. Will sync with server shortly.',
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _handleTagAction(Map<String, dynamic> tagItem, String action) async {
    final token = AuthService().token ?? '';
    final postIdRaw = tagItem['post_id'] ?? tagItem['id'];
    final int? postId = postIdRaw is int ? postIdRaw : int.tryParse(postIdRaw?.toString() ?? '');
    if (token.isEmpty || postId == null) return;

    setState(() => _processingPostIds.add(postId));
    final res = await ApiService().respondToPostTag(
      token: token,
      postId: postId,
      action: action,
    );
    if (!mounted) return;

    setState(() => _processingPostIds.remove(postId));

    if (res.success) {
      setState(() {
        if (action == 'remove') {
          _taggedPosts.removeWhere((item) {
            final itemId = item['post_id'] ?? item['id'];
            return itemId?.toString() == postId.toString();
          });
        } else if (action == 'approve') {
          for (final item in _taggedPosts) {
            final itemId = item['post_id'] ?? item['id'];
            if (itemId?.toString() == postId.toString()) {
              item['tag_status'] = 'approved';
            }
          }
        }
      });
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            action == 'approve' ? 'Tag approved' : 'Tag removed from post',
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message.isNotEmpty ? res.message : 'Action failed.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _openTaggedPost(Map<String, dynamic> tagItem) {
    final normalized = Map<String, dynamic>.from(tagItem);
    normalized['id'] = tagItem['post_id'] ?? tagItem['id'];
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SinglePostViewScreen(
          posts: [normalized],
          initialIndex: 0,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final int pendingCount =
        _taggedPosts.where((t) => (t['tag_status'] ?? 'approved') == 'pending').length;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xffE0F2FE), Colors.white],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Image.asset(
                            'assets/images/back_icon.png',
                            color: _titleColor,
                            width: 18.0,
                            height: 18.0,
                          ),
                        ),
                      ),
                    ),
                    const Expanded(
                      child: Text(
                        'Tags & Mentions',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'PublicSans',
                          color: _titleColor,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: _isSaving
                          ? const Center(
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: _primary,
                                ),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.only(
                    left: 18,
                    right: 18,
                    top: 6,
                    bottom: 24 + MediaQuery.of(context).padding.bottom,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader(
                        icon: Icons.local_offer_outlined,
                        title: 'Allow tags from',
                        subtitle: 'Choose who can tag you in photos and reels',
                      ),
                      const SizedBox(height: 8),
                      _buildAudienceCard(
                        selectedValue: _allowTagsFrom,
                        onSelect: (val) => _saveSettings(allowTagsFrom: val),
                        followingSubtitle: 'Only people you follow can tag you',
                        noOneSubtitle: 'Nobody can tag you in posts',
                        everyoneSubtitle: 'Anyone on Hidely can tag you',
                      ),
                      const SizedBox(height: 22),

                      _buildSectionHeader(
                        icon: Icons.verified_user_outlined,
                        title: 'Tagged posts approval',
                        subtitle: 'Review tags before approving them on posts',
                      ),
                      const SizedBox(height: 8),
                      _buildManualApprovalCard(pendingCount),
                      const SizedBox(height: 22),

                      _buildSectionHeader(
                        icon: Icons.alternate_email_rounded,
                        title: 'Allow @mentions from',
                        subtitle: 'Choose who can @mention you in captions and comments',
                      ),
                      const SizedBox(height: 8),
                      _buildAudienceCard(
                        selectedValue: _allowMentionsFrom,
                        onSelect: (val) => _saveSettings(allowMentionsFrom: val),
                        followingSubtitle: 'Only people you follow can @mention you',
                        noOneSubtitle: 'Nobody can @mention you',
                        everyoneSubtitle: 'Anyone on Hidely can @mention you',
                      ),
                      const SizedBox(height: 24),

                      _buildTaggedPostsSection(pendingCount),
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

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 17, color: _primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'PublicSans',
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _titleColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: const TextStyle(
              fontFamily: 'PublicSans',
              fontSize: 12.5,
              color: _subtitleColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAudienceCard({
    required String selectedValue,
    required ValueChanged<String> onSelect,
    required String everyoneSubtitle,
    required String followingSubtitle,
    required String noOneSubtitle,
  }) {
    final options = [
      (
        value: 'everyone',
        title: 'Everyone',
        subtitle: everyoneSubtitle,
        icon: Icons.public_rounded,
      ),
      (
        value: 'following',
        title: 'People you follow',
        subtitle: followingSubtitle,
        icon: Icons.people_outline_rounded,
      ),
      (
        value: 'no_one',
        title: 'No one',
        subtitle: noOneSubtitle,
        icon: Icons.block_outlined,
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xff2B1564).withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: Column(
          children: List.generate(options.length, (idx) {
            final opt = options[idx];
            final isSelected = selectedValue == opt.value;
            final isLast = idx == options.length - 1;

            return Column(
              children: [
                InkWell(
                  onTap: () => onSelect(opt.value),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(idx == 0 ? 18 : 0),
                    topRight: Radius.circular(idx == 0 ? 18 : 0),
                    bottomLeft: Radius.circular(isLast ? 18 : 0),
                    bottomRight: Radius.circular(isLast ? 18 : 0),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xffEDE9FC)
                                : const Color(0xffF4F6FA),
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: Icon(
                            opt.icon,
                            size: 20,
                            color: isSelected ? _accent : _subtitleColor,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                opt.title,
                                style: const TextStyle(
                                  fontFamily: 'PublicSans',
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xff1A1235),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                opt.subtitle,
                                style: const TextStyle(
                                  fontFamily: 'PublicSans',
                                  fontSize: 12,
                                  color: _subtitleColor,
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
                              color: isSelected ? _primary : Colors.black26,
                              width: isSelected ? 6.5 : 1.8,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (!isLast)
                  const Padding(
                    padding: EdgeInsets.only(left: 68, right: 16),
                    child: Divider(height: 1, color: _dividerColor),
                  ),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _buildManualApprovalCard(int pendingCount) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xff2B1564).withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xffE8EAF6),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.how_to_reg_outlined,
                  size: 20,
                  color: Color(0xff3949AB),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Manually approve tags',
                          style: TextStyle(
                            fontFamily: 'PublicSans',
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xff1A1235),
                          ),
                        ),
                        if (pendingCount > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xffFEF3C7),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$pendingCount pending',
                              style: const TextStyle(
                                color: Color(0xffB45309),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'When on, you can approve or remove posts before your tag appears.',
                      style: TextStyle(
                        fontFamily: 'PublicSans',
                        fontSize: 12,
                        color: _subtitleColor,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _manuallyApproveTags,
                activeThumbColor: _primary,
                activeTrackColor: _primary.withOpacity(0.25),
                onChanged: (val) => _saveSettings(manuallyApproveTags: val),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTaggedPostsSection(int pendingCount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.collections_bookmark_outlined, size: 17, color: _primary),
                  const SizedBox(width: 8),
                  Text(
                    pendingCount > 0
                        ? "Posts you're tagged in ($pendingCount pending)"
                        : "Posts you're tagged in",
                    style: const TextStyle(
                      fontFamily: 'PublicSans',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _titleColor,
                    ),
                  ),
                ],
              ),
              IconButton(
                onPressed: _loadTaggedPosts,
                icon: const Icon(Icons.refresh_rounded, size: 20, color: _primary),
                tooltip: 'Refresh tagged posts',
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        if (_isLoadingTags)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Center(
              child: CircularProgressIndicator(color: _primary),
            ),
          )
        else if (_tagsLoadError != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              _tagsLoadError!,
              style: const TextStyle(
                fontFamily: 'PublicSans',
                color: _subtitleColor,
                fontSize: 13,
              ),
            ),
          )
        else if (_taggedPosts.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Column(
              children: [
                Icon(Icons.local_offer_outlined, size: 32, color: Color(0xffC5BEE0)),
                SizedBox(height: 8),
                Text(
                  'No tagged posts yet',
                  style: TextStyle(
                    fontFamily: 'PublicSans',
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: _titleColor,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Posts where friends tag you will show up here for approval or removal.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'PublicSans',
                    fontSize: 12.5,
                    color: _subtitleColor,
                  ),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _taggedPosts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = _taggedPosts[index];
              final postIdRaw = item['post_id'] ?? item['id'];
              final int? postId =
                  postIdRaw is int ? postIdRaw : int.tryParse(postIdRaw?.toString() ?? '');
              final bool isPending = (item['tag_status'] ?? 'approved') == 'pending';
              final bool isBusy = postId != null && _processingPostIds.contains(postId);
              final String authorUsername = (item['author_username'] ?? 'explorer').toString();
              final String authorName = (item['author_name'] ?? authorUsername).toString();
              final String caption = (item['caption'] ?? '').toString();
              final String imgUrl = (item['image_url'] ?? '').toString();
              final String fullImgUrl = imgUrl.startsWith('http') || imgUrl.startsWith('assets/')
                  ? imgUrl
                  : '${ApiService().baseUrl}/$imgUrl';

              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isPending ? const Color(0xffFDE68A) : const Color(0xffEEF0F8),
                  ),
                ),
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => _openTaggedPost(item),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: imgUrl.startsWith('assets/')
                                ? Image.asset(imgUrl, width: 56, height: 56, fit: BoxFit.cover)
                                : imgUrl.isNotEmpty
                                    ? CachedNetworkImage(
                                        imageUrl: fullImgUrl,
                                        width: 56,
                                        height: 56,
                                        fit: BoxFit.cover,
                                        errorWidget: (_, __, ___) => _thumbPlaceholder(),
                                      )
                                    : _thumbPlaceholder(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  UserAvatar(
                                    avatarUrl: item['author_profile_picture']?.toString(),
                                    displayName: authorName,
                                    radius: 11,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      '@$authorUsername',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13.5,
                                        color: _titleColor,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isPending
                                          ? const Color(0xffFEF3C7)
                                          : const Color(0xffDCFCE7),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      isPending ? 'Pending' : 'Approved',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: isPending
                                            ? const Color(0xffB45309)
                                            : const Color(0xff15803D),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (caption.isNotEmpty) ...[
                                const SizedBox(height: 5),
                                Text(
                                  caption,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (isPending) ...[
                          ElevatedButton(
                            onPressed: isBusy
                                ? null
                                : () => _handleTagAction(item, 'approve'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              'Approve',
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        OutlinedButton(
                          onPressed: isBusy ? null : () => _handleTagAction(item, 'remove'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            side: const BorderSide(color: Color(0xffFCA5A5)),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            'Remove Tag',
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _thumbPlaceholder() {
    return Container(
      width: 56,
      height: 56,
      color: const Color(0xffEDE9FC),
      child: const Icon(Icons.photo_outlined, color: _accent),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:hidely_new/widgets/report_bottom_sheet.dart';

class PostOptionsBottomSheet extends StatelessWidget {
  final dynamic post;

  const PostOptionsBottomSheet({super.key, required this.post});

  void _sharePost(BuildContext context) {
    Navigator.pop(context);
    final String postId = post['id']?.toString() ?? '';
    final String shareUrl = "https://hidely.app/post/$postId";
    // ignore: deprecated_member_use
    Share.share("Check out this amazing post on Hidely! 🌍✨\n$shareUrl");
  }

  void _copyLink(BuildContext context) {
    Navigator.pop(context);
    final String postId = post['id']?.toString() ?? '';
    Clipboard.setData(ClipboardData(text: "https://hidely.app/post/$postId"));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Link copied to clipboard!"),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _reportPost(BuildContext context) {
    Navigator.pop(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReportBottomSheet(
        targetType: 'Post',
        targetName: post['caption']?.toString() ?? 'Post',
        onSubmitSuccess: () {},
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    
    return Wrap(
      children: [
        Container(
          padding: EdgeInsets.only(bottom: bottomPadding > 0 ? bottomPadding : 24, top: 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 32),
              
              // Horizontal Quick Actions
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildQuickAction(
                      icon: Icons.ios_share_rounded,
                      label: "Share",
                      color: const Color(0xff1C0D5A),
                      bgColor: const Color(0xffF1F5F9),
                      onTap: () => _sharePost(context),
                    ),
                    _buildQuickAction(
                      icon: Icons.copy_rounded,
                      label: "Copy Link",
                      color: const Color(0xff1C0D5A),
                      bgColor: const Color(0xffF1F5F9),
                      onTap: () => _copyLink(context),
                    ),
                    _buildQuickAction(
                      icon: Icons.report_gmailerrorred_rounded,
                      label: "Report",
                      color: Colors.redAccent,
                      bgColor: Colors.red.shade50,
                      onTap: () => _reportPost(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required Color color,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

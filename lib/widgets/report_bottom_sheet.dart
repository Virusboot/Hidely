import 'package:flutter/material.dart';
import 'package:hidely_new/screens/main_wrapper.dart' show showLoginRequiredSheet;
import 'package:hidely_new/services/api_service.dart';
import 'package:hidely_new/services/auth_service.dart';
import 'package:hidely_new/widgets/custom_snackbar.dart';

class ReportReason {
  final String title;
  final String description;
  final IconData icon;

  const ReportReason({
    required this.title,
    required this.description,
    required this.icon,
  });
}

class ReportBottomSheet extends StatefulWidget {
  final String targetType; // 'Post', 'Reel', 'Profile', or 'Comment'
  final String targetName; // e.g. post caption or username
  final int? targetId;
  final String? targetUsername;
  final VoidCallback onSubmitSuccess;

  const ReportBottomSheet({
    super.key,
    required this.targetType,
    required this.targetName,
    this.targetId,
    this.targetUsername,
    required this.onSubmitSuccess,
  });

  @override
  State<ReportBottomSheet> createState() => _ReportBottomSheetState();
}

class _ReportBottomSheetState extends State<ReportBottomSheet> {
  int _currentStep = 0; // 0 = Select Reason, 1 = Additional Details
  ReportReason? _selectedReason;
  final TextEditingController _detailsController = TextEditingController();
  bool _isSubmitting = false;

  final List<ReportReason> _reasons = const [
    ReportReason(
      title: "Spam",
      description: "Scam, advertising, or repetitive promotional content",
      icon: Icons.alternate_email_rounded,
    ),
    ReportReason(
      title: "Fake",
      description: "Impersonation, fabricated place, or deceptive information",
      icon: Icons.face_retouching_off_rounded,
    ),
    ReportReason(
      title: "Abuse",
      description: "Abusive comments, harassment, or hate speech",
      icon: Icons.gavel_rounded,
    ),
    ReportReason(
      title: "Child Safety / CSAE",
      description: "Zero tolerance: child sexual abuse, exploitation, or endangerment",
      icon: Icons.shield_outlined,
    ),
    ReportReason(
      title: "Inappropriate Content",
      description: "Explicit nudity, graphic violence, illegal goods, or self-harm",
      icon: Icons.visibility_off_outlined,
    ),
    ReportReason(
      title: "Wrong Location",
      description: "Inaccurate GPS coordinates, wrong pin, or false address",
      icon: Icons.wrong_location_rounded,
    ),
    ReportReason(
      title: "Other",
      description: "Any other community guidelines violation",
      icon: Icons.warning_amber_rounded,
    ),
  ];

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    final token = AuthService().token ?? '';
    if (AuthService().isGuest || token.isEmpty) {
      showLoginRequiredSheet(context, reason: 'submit a safety report');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final reasonTitle = _selectedReason?.title ?? 'Other';
    final result = await ApiService().submitReport(
      token: token,
      targetType: widget.targetType,
      targetId: widget.targetId,
      targetUsername: widget.targetUsername,
      targetName: widget.targetName,
      reason: reasonTitle,
      details: _detailsController.text.trim(),
    );

    if (!mounted) return;

    setState(() {
      _isSubmitting = false;
    });

    if (!result.success) {
      showHidelySnackBar(
        context,
        result.message.isNotEmpty
            ? result.message
            : 'Unable to submit report. Please check your connection and try again.',
        isError: true,
      );
      return;
    }

    final navigator = Navigator.of(context, rootNavigator: false);
    final hostContext = navigator.context;
    final cleanUsername = (widget.targetUsername ?? '').replaceFirst(RegExp(r'^@+'), '').trim();
    final isOwnAccount = cleanUsername.isNotEmpty &&
        cleanUsername.toLowerCase() == AuthService().userUsername.toLowerCase();

    Navigator.pop(context); // Close bottom sheet
    widget.onSubmitSuccess();

    if (!hostContext.mounted) return;

    showDialog(
      context: hostContext,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xffE6F7EE),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: Color(0xff29A96A),
                size: 48,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "Report Submitted",
              style: TextStyle(
                color: Color(0xff1C0D5A),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              reasonTitle.contains('Child Safety')
                  ? "Thank you. Urgent Child Safety (CSAE) reports are prioritized for immediate review and takedown within 24 hours."
                  : "Thank you for keeping Hidely safe! Our moderation team will review this ${widget.targetType.toLowerCase()} within 24 hours.",
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),
            if (cleanUsername.isNotEmpty && !isOwnAccount) ...[
              SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.block_rounded, size: 18, color: Colors.redAccent),
                  label: Text(
                    "Block @$cleanUsername",
                    style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.redAccent),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    Navigator.pop(dialogCtx);
                    await AuthService().blockUser(cleanUsername);
                    if (hostContext.mounted) {
                      showHidelySnackBar(
                        hostContext,
                        "@$cleanUsername blocked. Their posts and profile are now hidden.",
                        isError: false,
                      );
                    }
                  },
                ),
              ),
              const SizedBox(height: 10),
            ],
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xff2B1564),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text(
                  "Dismiss",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double keyboardPadding = MediaQuery.of(context).viewInsets.bottom;
    final double bottomPadding = keyboardPadding > 0 ? keyboardPadding + 12 : 8.0;

    return Wrap(
      children: [
        Material(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          clipBehavior: Clip.antiAlias,
          child: SafeArea(
            top: false,
            bottom: true,
            child: Padding(
              padding: EdgeInsets.only(bottom: bottomPadding),
              child: Column(
                mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              const SizedBox(height: 12),
              Container(
                width: 44,
                height: 4.5,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
              const SizedBox(height: 16),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: _currentStep > 0
                          ? GestureDetector(
                              onTap: () => setState(() => _currentStep = 0),
                              child: Center(
                                child: Image.asset(
                                  'assets/images/back_icon.png',
                                  color: const Color(0xff1C0D5A),
                                  width: 18.0,
                                  height: 18.0,
                                ),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                    Expanded(
                      child: Text(
                        _currentStep == 0 
                            ? "Report ${widget.targetType}" 
                            : "Add Details",
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xff1C0D5A),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 22,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(),

              // Body steps
              if (_currentStep == 0) _buildReasonSelector() else _buildDetailsForm(),
            ],
          ),
        ),
      ),
    ),
  ],
);
}

  Widget _buildReasonSelector() {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.56,
      ),
      child: ListView.builder(
        shrinkWrap: true,
        physics: const BouncingScrollPhysics(),
        itemCount: _reasons.length,
        itemBuilder: (context, index) {
          final reason = _reasons[index];
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xffF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(reason.icon, color: const Color(0xff1C0D5A), size: 20),
            ),
            title: Text(
              reason.title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            subtitle: Text(
              reason.description,
              style: const TextStyle(color: Colors.black38, fontSize: 12),
            ),
            trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
            onTap: () {
              setState(() {
                _selectedReason = reason;
                _currentStep = 1;
              });
            },
          );
        },
      ),
    );
  }

  Widget _buildDetailsForm() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Reason: ${_selectedReason?.title}",
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Color(0xff2B1564),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xffF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: TextField(
              controller: _detailsController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: "Add any additional context or details...",
                hintStyle: TextStyle(color: Colors.black38, fontSize: 13),
                border: InputBorder.none,
              ),
              style: const TextStyle(fontSize: 14, color: Colors.black87),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff2B1564),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              onPressed: _isSubmitting ? null : _submitReport,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      "Submit Report",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

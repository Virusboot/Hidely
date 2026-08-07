import 'package:flutter/material.dart';
import 'package:hidely_new/widgets/verified_badge.dart';

class AdminReviewSheet extends StatefulWidget {
  final Map<String, dynamic> placeSubmission;
  final Function(bool approved, String badge) onDecision;

  const AdminReviewSheet({
    super.key,
    required this.placeSubmission,
    required this.onDecision,
  });

  @override
  State<AdminReviewSheet> createState() => _AdminReviewSheetState();
}

class _AdminReviewSheetState extends State<AdminReviewSheet> {
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final title = widget.placeSubmission['title'] ?? widget.placeSubmission['name'] ?? 'Submitted Place';
    final location = widget.placeSubmission['location'] ?? 'Unknown Location';
    final aiReason = widget.placeSubmission['ai_reason'] ?? 'AI scan completed cleanly.';
    final isDuplicate = widget.placeSubmission['is_duplicate'] == true;
    final isWrongLocation = widget.placeSubmission['is_wrong_location'] == true;
    final isSpam = widget.placeSubmission['is_spam'] == true;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle indicator
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
              const Row(
                children: [
                  Icon(Icons.admin_panel_settings_rounded, color: Color(0xFF7C3AED), size: 24),
                  SizedBox(width: 8),
                  Text(
                    'Admin Verification Review',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1C0D5A),
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(),
          const SizedBox(height: 12),

          // Place Details
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
              ),
              const SizedBox(width: 8),
              const VerifiedHiddenPlaceBadge(),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 16, color: Colors.grey),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  location,
                  style: const TextStyle(fontSize: 13, color: Colors.black54),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // AI Diagnostics Box
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AI Verification Checks:',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                ),
                const SizedBox(height: 8),
                _buildCheckRow('Duplicate Check', !isDuplicate, isDuplicate ? 'Nearby match found' : 'Passed'),
                _buildCheckRow('Location Verification', !isWrongLocation, isWrongLocation ? 'Invalid GPS' : 'Valid GPS'),
                _buildCheckRow('Spam & Quality Filter', !isSpam, isSpam ? 'Flagged' : 'Clean'),
                const SizedBox(height: 8),
                Text(
                  'AI Scan Note: $aiReason',
                  style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.black54),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isProcessing
                      ? null
                      : () {
                          setState(() => _isProcessing = true);
                          widget.onDecision(false, '');
                          Navigator.pop(context);
                        },
                  icon: const Icon(Icons.close_rounded, color: Colors.redAccent),
                  label: const Text('Reject', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.redAccent),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isProcessing
                      ? null
                      : () {
                          setState(() => _isProcessing = true);
                          widget.onDecision(true, 'Verified Hidden Place');
                          Navigator.pop(context);
                        },
                  icon: const Icon(Icons.verified_rounded, color: Colors.white, size: 18),
                  label: const Text('Approve Badge', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C3AED),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildCheckRow(String title, bool isPassed, String statusText) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 12, color: Colors.black87)),
          Row(
            children: [
              Icon(
                isPassed ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                color: isPassed ? Colors.green : Colors.orange,
                size: 14,
              ),
              const SizedBox(width: 4),
              Text(
                statusText,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isPassed ? Colors.green : Colors.orange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

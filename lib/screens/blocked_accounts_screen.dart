import 'package:flutter/material.dart';
import 'package:hidely_new/services/auth_service.dart';

class BlockedAccountsScreen extends StatefulWidget {
  const BlockedAccountsScreen({super.key});

  @override
  State<BlockedAccountsScreen> createState() => _BlockedAccountsScreenState();
}

class _BlockedAccountsScreenState extends State<BlockedAccountsScreen> {
  List<String> _blockedUsers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBlockedUsers();
  }

  Future<void> _loadBlockedUsers() async {
    final list = await AuthService().getBlockedUsers();
    if (mounted) {
      setState(() {
        _blockedUsers = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _unblockUser(String username) async {
    await AuthService().unblockUser(username);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('@$username unblocked successfully.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    _loadBlockedUsers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF6F9FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xff1C0D5A), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Blocked Accounts",
          style: TextStyle(
            color: Color(0xff1C0D5A),
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xff2B1564),
              ),
            )
          : _blockedUsers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.block_flipped,
                        size: 64,
                        color: const Color(0xff1C0D5A).withOpacity(0.3),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "No Blocked Accounts",
                        style: TextStyle(
                          color: Color(0xff1C0D5A),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Accounts you block will appear here.",
                        style: TextStyle(
                          color: const Color(0xff1C0D5A).withOpacity(0.6),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: _blockedUsers.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final username = _blockedUsers[index];
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: const Color(0xffE0F2FE),
                            child: Text(
                              username.isNotEmpty ? username[0].toUpperCase() : 'U',
                              style: const TextStyle(
                                color: Color(0xff0284C7),
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              "@$username",
                              style: const TextStyle(
                                color: Color(0xff1C0D5A),
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => _unblockUser(username),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xffF1F5F9),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                "Unblock",
                                style: TextStyle(
                                  color: Color(0xff64748B),
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}

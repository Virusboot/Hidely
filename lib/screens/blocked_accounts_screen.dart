import 'package:flutter/material.dart';
import 'package:hidely_new/services/auth_service.dart';

import 'package:hidely_new/widgets/empty_state.dart';

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
    final double bottomPadding = MediaQuery.of(context).padding.bottom + 16.0;

    return Scaffold(
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
          child: Column(
            children: [
              // --- 1. PREMIUM CENTERED HEADER BAR ---
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
                            color: const Color(0xff1C0D5A),
                            width: 18.0,
                            height: 18.0,
                          ),
                        ),
                      ),
                    ),
                    const Expanded(
                      child: Text(
                        "Blocked Accounts",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xff1C0D5A),
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 40), // Balance the back button on the left
                  ],
                ),
              ),

              // --- 2. BODY CONTENT ---
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xff2B1564),
                        ),
                      )
                    : _blockedUsers.isEmpty
                        ? const EmptyStateWidget(
                            icon: Icons.block_flipped,
                            title: "No Blocked Accounts",
                            description: "Accounts you block will appear here.",
                          )
                        : ListView.separated(
                            padding: EdgeInsets.only(
                              left: 16.0,
                              right: 16.0,
                              top: 12.0,
                              bottom: bottomPadding,
                            ),
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}

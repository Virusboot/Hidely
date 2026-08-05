import 'package:flutter/material.dart';
import 'package:hidely_new/services/auth_service.dart';
import 'login_screen.dart';
import 'main_wrapper.dart';
import 'package:hidely_new/widgets/user_avatar.dart';

class AddAccountScreen extends StatefulWidget {
  const AddAccountScreen({super.key});

  @override
  State<AddAccountScreen> createState() => _AddAccountScreenState();
}

class _AddAccountScreenState extends State<AddAccountScreen> {
  List<Map<String, dynamic>> _sessions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    // Sync current session to list if not already present
    if (AuthService().isLoggedIn) {
      final token = AuthService().token!;
      final user = AuthService().user!;
      await AuthService().login(token, user);
    }
    
    final list = await AuthService().getSessions();
    if (mounted) {
      setState(() {
        _sessions = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _switchAccount(int index) async {
    setState(() => _isLoading = true);
    await AuthService().switchAccount(index);
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Switched to @${AuthService().user!['username']}"),
        behavior: SnackBarBehavior.floating,
      ),
    );

    // Refresh and navigate to home wrapper
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(settings: const RouteSettings(name: "/main"), builder: (context) => const MainWrapper(initialIndex: 3)),
      (route) => false,
    );
  }

  Future<void> _removeAccount(int index) async {
    final targetUser = _sessions[index]['user'];
    await AuthService().removeSession(index);
    
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Logged out from @${targetUser['username']}"),
        behavior: SnackBarBehavior.floating,
      ),
    );

    if (AuthService().isLoggedIn) {
      // Refresh current screen
      _loadSessions();
    } else {
      // Go to Login Screen if all sessions removed
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeUser = AuthService().user;
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
          bottom: false,
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
                        "Switch Accounts",
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
                    ? const Center(child: CircularProgressIndicator(color: Color(0xff2B1564)))
                    : Column(
                        children: [
                          Expanded(
                            child: ListView.separated(
                              padding: const EdgeInsets.all(20),
                              itemCount: _sessions.length,
                              separatorBuilder: (context, index) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final session = _sessions[index];
                                final user = session['user'];
                                final isCurrent = activeUser != null && (activeUser['id'] == user['id'] || activeUser['username'] == user['username']);

                                return Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: isCurrent ? const Color(0xff6C5DD3) : Colors.transparent,
                                      width: 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.015),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      UserAvatar(
                                        avatarUrl: user['profile_picture'],
                                        displayName: user['name'] ?? user['username'],
                                        radius: 24,
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              user['name'] ?? user['username'],
                                              style: const TextStyle(
                                                color: Color(0xff1C0D5A),
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              "@${user['username']}",
                                              style: TextStyle(
                                                color: const Color(0xff1C0D5A).withOpacity(0.5),
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (isCurrent)
                                        const Icon(Icons.check_circle_rounded, color: Color(0xff6C5DD3), size: 24)
                                      else ...[
                                        TextButton(
                                          onPressed: () => _switchAccount(index),
                                          child: const Text(
                                            "Switch",
                                            style: TextStyle(
                                              color: Color(0xff2B1564),
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 20),
                                          onPressed: () => _removeAccount(index),
                                        ),
                                      ],
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                          // Bottom Button block to add new account
                          Padding(
                            padding: EdgeInsets.only(
                              left: 24.0,
                              right: 24.0,
                              top: 12.0,
                              bottom: bottomPadding,
                            ),
                            child: Container(
                              width: double.infinity,
                              height: 56,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xff2B1564), Color(0xff4B2D8E)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(28),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xff2B1564).withOpacity(0.2),
                                    blurRadius: 16,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(28),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const LoginScreen(isAddingAccount: true),
                                      ),
                                    ).then((_) => _loadSessions());
                                  },
                                  child: const Center(
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.add_circle_outline_rounded, color: Colors.white, size: 20),
                                        SizedBox(width: 8),
                                        Text(
                                          "Add Existing Account",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

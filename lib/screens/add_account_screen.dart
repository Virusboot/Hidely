import 'package:flutter/material.dart';
import 'package:hidely_new/services/auth_service.dart';
import 'login_screen.dart';
import 'main_wrapper.dart';

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
      MaterialPageRoute(builder: (context) => const MainWrapper(initialIndex: 3)),
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
          "Switch Accounts",
          style: TextStyle(
            color: Color(0xff1C0D5A),
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: _isLoading
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
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: const Color(0xffE0F2FE),
                              child: Text(
                                user['name'] != null && user['name'].toString().isNotEmpty
                                    ? user['name'][0].toUpperCase()
                                    : user['username'][0].toUpperCase(),
                                style: const TextStyle(
                                  color: Color(0xff0284C7),
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
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
                  padding: const EdgeInsets.all(24.0),
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
    );
  }
}

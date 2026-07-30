import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hidely_new/screens/create_account_screen.dart';
import 'package:hidely_new/screens/forget_password_screen.dart';
import 'package:hidely_new/screens/main_wrapper.dart';
import 'package:hidely_new/services/auth_service.dart';
import 'package:hidely_new/services/api_service.dart';
import 'package:hidely_new/screens/otp_verification_screen.dart';

class LoginScreen extends StatefulWidget {
  final bool isAddingAccount;
  const LoginScreen({super.key, this.isAddingAccount = false});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordObscured = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _emailController.text = prefs.getString('saved_email') ?? '';
      _passwordController.text = prefs.getString('saved_password') ?? '';
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark, // Black status bar icons for Android
        statusBarBrightness: Brightness.light, // Black status bar icons for iOS
      ),
      child: Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xffE0F2FE),
              Color(0xffFDF7FF),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 60),
                const Text(
                  "Welcome\nBack!",
                  style: TextStyle(
                    color: Color(0xff1C0D5A),
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                    letterSpacing: -1.0,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "Sign in to continue your cinematic travel journey.",
                  style: TextStyle(
                    color: const Color(0xff1C0D5A).withOpacity(0.6),
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 50),

                // Email Input
                _buildInputField(
                  controller: _emailController,
                  hintText: "Email Address",
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 20),

                // Password Input
                _buildInputField(
                  controller: _passwordController,
                  hintText: "Password",
                  icon: Icons.lock_outline,
                  isPassword: true,
                  obscureText: _isPasswordObscured,
                  onSuffixTap: () {
                    setState(() {
                      _isPasswordObscured = !_isPasswordObscured;
                    });
                  },
                ),

                // Forgot Password Button
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ForgetPasswordScreen()),
                      );
                    },
                    child: const Text(
                      "Forgot Password?",
                      style: TextStyle(
                        color: Color(0xff5D3EBC),
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),

                // Sign In Button (Always kept in color)
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                      onPressed: () async {
                        if (_isLoading) return;
                        final email = _emailController.text.trim();
                        final password = _passwordController.text;

                        // Email format validation using RegExp
                        final emailRegex = RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+");

                        if (email.isEmpty) {
                          _showCustomSnackBar(context, "Please enter your email", isError: true);
                        } else if (!emailRegex.hasMatch(email)) {
                          _showCustomSnackBar(context, "Please enter a valid email", isError: true);
                        } else if (password.isEmpty) {
                          _showCustomSnackBar(context, "Please enter your password", isError: true);
                        } else {
                          setState(() {
                            _isLoading = true;
                          });

                          final result = await ApiService().login(
                            email: email,
                            password: password,
                          );

                          if (!context.mounted) return;

                          setState(() {
                            _isLoading = false;
                          });

                          if (result.success) {
                            final token = result.data?['token'];
                            final userData = result.data?['user'];

                            if (token != null && userData != null) {
                              await AuthService().login(token, userData);
                            }

                            // Save credentials to shared preferences
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setString('saved_email', email);
                            await prefs.setString('saved_password', password);

                            if (!context.mounted) return;

                            Future.delayed(const Duration(milliseconds: 100), () {
                              if (!context.mounted) return;
                              if (widget.isAddingAccount) {
                                Navigator.pop(context);
                              } else {
                                Navigator.pushAndRemoveUntil(
                                  context,
                                  MaterialPageRoute(builder: (context) => const MainWrapper()),
                                  (route) => false,
                                );
                              }
                            });
                          } else if (result.error == 'UNVERIFIED') {
                            if (!context.mounted) return;
                            _showCustomSnackBar(context, "Account unverified. Redirecting to verification...", isError: true);
                            
                            Future.delayed(const Duration(milliseconds: 1000), () {
                              if (!context.mounted) return;
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => OtpVerificationScreen(
                                    email: email,
                                    isSignupFlow: true,
                                    devOtp: result.data?['dev_otp']?.toString(),
                                  ),
                                ),
                              );
                            });
                          } else {
                            if (!context.mounted) return;
                            _showCustomSnackBar(context, result.message, isError: true);
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xff2B1564),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        _isLoading ? "Please wait..." : "Sign In",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 40),

                // Bottom Register Link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account? ",
                      style: TextStyle(
                        color: const Color(0xff1C0D5A).withOpacity(0.6),
                        fontSize: 15,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const CreateAccountScreen()),
                        );
                      },
                      child: const Text(
                        "Sign Up",
                        style: TextStyle(
                          color: Color(0xff5D3EBC),
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

  // Modern Matte White Input Builder Component
  Widget _buildInputField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    bool isPassword = false,
    bool obscureText = false,
    VoidCallback? onSuffixTap,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.6),
          width: 1.2,
        ),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        style: const TextStyle(color: Color(0xff1C0D5A), fontSize: 16),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(color: const Color(0xff1C0D5A).withOpacity(0.4)),
          prefixIcon: Icon(icon, color: const Color(0xff1C0D5A).withOpacity(0.6)),
          suffixIcon: isPassword
              ? GestureDetector(
            onTap: onSuffixTap,
            child: Icon(
              obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: const Color(0xff1C0D5A).withOpacity(0.6),
            ),
          )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        ),
      ),
    );
  }

  // --- FIXED: Complete Custom SnackBar definition rebuilt correctly without messy line-breaks ---
  void _showCustomSnackBar(BuildContext context, String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? Colors.redAccent.shade700 : const Color(0xff2B1564),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
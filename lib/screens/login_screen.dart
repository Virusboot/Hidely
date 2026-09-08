import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hidely_new/screens/create_account_screen.dart';
import 'package:hidely_new/screens/forget_password_screen.dart';
import 'package:hidely_new/screens/main_wrapper.dart';
import 'package:hidely_new/services/auth_service.dart';
import 'package:hidely_new/services/api_service.dart';
import 'package:hidely_new/screens/otp_verification_screen.dart';
import 'package:hidely_new/widgets/custom_snackbar.dart';

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
                if (widget.isAddingAccount || Navigator.canPop(context)) ...[
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 44,
                      height: 44,
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
                  const SizedBox(height: 24),
                ] else
                  const SizedBox(height: 60),
                const Text(
                  "Welcome\nBack!",
                  style: TextStyle(
                    color: Color(0xff1C0D5A),
                    fontSize: 32,
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

                // Email/Username Input
                _buildInputField(
                  controller: _emailController,
                  hintText: "Email or Username",
                  icon: Icons.person_outline_rounded,
                  keyboardType: TextInputType.text,
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

                        final isEmailFormat = email.contains('@');
                        final emailRegex = RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+");

                        if (email.isEmpty) {
                          _showCustomSnackBar(context, "Please enter your email or username", isError: true);
                        } else if (isEmailFormat && !emailRegex.hasMatch(email)) {
                          _showCustomSnackBar(context, "Please enter a valid email address", isError: true);
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

                            if (!context.mounted) return;

                            Future.delayed(const Duration(milliseconds: 100), () {
                              if (!context.mounted) return;
                              if (widget.isAddingAccount) {
                                Navigator.pop(context);
                              } else {
                                Navigator.pushAndRemoveUntil(
                                  context,
                                  MaterialPageRoute(settings: const RouteSettings(name: "/main"), builder: (context) => const MainWrapper()),
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
        textAlignVertical: TextAlignVertical.center,
        style: const TextStyle(color: Color(0xff1C0D5A), fontSize: 16),
        decoration: InputDecoration(
          isDense: true,
          hintText: hintText,
          hintStyle: TextStyle(color: const Color(0xff1C0D5A).withOpacity(0.4), fontSize: 16),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 16, right: 12),
            child: Icon(icon, color: const Color(0xff1C0D5A).withOpacity(0.6), size: 22),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 50, minHeight: 0),
          suffixIcon: isPassword
              ? GestureDetector(
                  onTap: onSuffixTap,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Icon(
                      obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: const Color(0xff1C0D5A).withOpacity(0.6),
                      size: 22,
                    ),
                  ),
                )
              : null,
          suffixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 0),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 18),
        ),
      ),
    );
  }

  // --- FIXED: Complete Custom SnackBar definition rebuilt correctly without messy line-breaks ---
  void _showCustomSnackBar(BuildContext context, String message, {required bool isError}) {
    showHidelySnackBar(context, message, isError: isError);
  }
}
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:hidely_new/services/auth_service.dart';
import 'package:hidely_new/screens/main_wrapper.dart';
import 'package:hidely_new/services/api_service.dart';
import 'package:hidely_new/widgets/custom_snackbar.dart';
import 'package:hidely_new/screens/terms_of_service_screen.dart';
import 'package:hidely_new/screens/privacy_policy_screen.dart';

class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _usernameController = TextEditingController();

  bool _isPasswordObscured = true;
  bool _isConfirmPasswordObscured = true;
  bool _agreeToTerms = false;
  bool _isLoading = false;

  late final TapGestureRecognizer _termsRecognizer = TapGestureRecognizer()
    ..onTap = () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const TermsOfServiceScreen(),
        ),
      );
    };

  late final TapGestureRecognizer _privacyRecognizer = TapGestureRecognizer()
    ..onTap = () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const PrivacyPolicyScreen(),
        ),
      );
    };

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _termsRecognizer.dispose();
    _privacyRecognizer.dispose();
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
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 28.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Safe breathing space matching the login header padding
                        const SizedBox(height: 50),
                        const Text(
                          "Create\nAccount",
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
                          "Join Hidely today and capture the world contextually.",
                          style: TextStyle(
                            color: const Color(0xff1C0D5A).withOpacity(0.6),
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 35),

                        _buildInputField(
                          controller: _nameController,
                          hintText: "Full Name",
                          icon: Icons.person_outline,
                          maxLength: 30,
                        ),
                        const SizedBox(height: 16),

                        _buildInputField(
                          controller: _usernameController,
                          hintText: "Username",
                          icon: Icons.alternate_email_rounded,
                          maxLength: 30,
                        ),
                        const SizedBox(height: 16),

                        _buildInputField(
                          controller: _emailController,
                          hintText: "Email Address",
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 16),

                        _buildInputField(
                          controller: _passwordController,
                          hintText: "Password",
                          icon: Icons.lock_outline,
                          isPassword: true,
                          obscureText: _isPasswordObscured,
                          maxLength: 30,
                          onSuffixTap: () {
                            setState(() {
                              _isPasswordObscured = !_isPasswordObscured;
                            });
                          },
                        ),
                        const SizedBox(height: 16),

                        _buildInputField(
                          controller: _confirmPasswordController,
                          hintText: "Confirm Password",
                          icon: Icons.lock_clock_outlined,
                          isPassword: true,
                          obscureText: _isConfirmPasswordObscured,
                          maxLength: 30,
                          onSuffixTap: () {
                            setState(() {
                              _isConfirmPasswordObscured = !_isConfirmPasswordObscured;
                            });
                          },
                        ),
                        const SizedBox(height: 20),

                        Row(
                          children: [
                            SizedBox(
                              height: 24,
                              width: 24,
                              child: Checkbox(
                                value: _agreeToTerms,
                                activeColor: const Color(0xff2B1564),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                onChanged: (value) {
                                  setState(() {
                                    _agreeToTerms = value ?? false;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: RichText(
                                text: TextSpan(
                                  style: TextStyle(
                                    color: const Color(0xff1C0D5A).withOpacity(0.7),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
                                  ),
                                  children: [
                                    const TextSpan(text: "I agree to the "),
                                    TextSpan(
                                      text: "Terms of Service",
                                      style: const TextStyle(
                                        color: Color(0xff2B1564),
                                        fontWeight: FontWeight.bold,
                                        decoration: TextDecoration.underline,
                                      ),
                                      recognizer: _termsRecognizer,
                                    ),
                                    const TextSpan(text: " & "),
                                    TextSpan(
                                      text: "Privacy Policy",
                                      style: const TextStyle(
                                        color: Color(0xff2B1564),
                                        fontWeight: FontWeight.bold,
                                        decoration: TextDecoration.underline,
                                      ),
                                      recognizer: _privacyRecognizer,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 30),

                        // Sign Up Button (Always kept in color)
                        SizedBox(
                          width: double.infinity,
                          height: 60,
                          child: ElevatedButton(
                            onPressed: () {
                              if (_isLoading) return;
                              final name = _nameController.text.trim();
                              final username = _usernameController.text.trim();
                              final email = _emailController.text.trim();
                              final password = _passwordController.text;
                              final confirmPassword = _confirmPasswordController.text;

                              final emailRegex = RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+");

                              final usernameRegex = RegExp(r'^(?!.*\.\.)(?!.*__)(?!.*_\.)(?!.*\._)[a-zA-Z0-9._]{3,30}$');
                              final startEndCheck = RegExp(r'^[a-zA-Z0-9].*[a-zA-Z0-9]$');

                              if (name.isEmpty) {
                                _showCustomSnackBar(context, "Please write your full name", isError: true);
                              } else if (name.length > 30) {
                                _showCustomSnackBar(context, "Name cannot exceed 30 characters", isError: true);
                              } else if (username.isEmpty) {
                                _showCustomSnackBar(context, "Please create a username", isError: true);
                              } else if (username.length < 3) {
                                _showCustomSnackBar(context, "Username must be at least 3 characters", isError: true);
                              } else if (username.length > 30) {
                                _showCustomSnackBar(context, "Username cannot exceed 30 characters", isError: true);
                              } else if (!startEndCheck.hasMatch(username) || !usernameRegex.hasMatch(username)) {
                                _showCustomSnackBar(
                                  context, 
                                  "Username can only contain letters, numbers, underscores, and periods. It cannot start/end with or have consecutive dots or underscores.", 
                                  isError: true,
                                );
                              } else if (email.isEmpty) {
                                _showCustomSnackBar(context, "Please enter your email", isError: true);
                              } else if (!emailRegex.hasMatch(email)) {
                                _showCustomSnackBar(context, "Please enter a valid email", isError: true);
                              } else if (password.isEmpty) {
                                _showCustomSnackBar(context, "Please enter your password", isError: true);
                              } else if (password.length < 6) {
                                _showCustomSnackBar(context, "Password must be at least 6 characters", isError: true);
                              } else if (password.length > 30) {
                                _showCustomSnackBar(context, "Password cannot exceed 30 characters", isError: true);
                              } else if (confirmPassword.isEmpty) {
                                _showCustomSnackBar(context, "Please confirm your password", isError: true);
                              } else if (password != confirmPassword) {
                                _showCustomSnackBar(context, "Passwords do not match", isError: true);
                              } else if (!_agreeToTerms) {
                                _showCustomSnackBar(context, "Please agree to terms & policy", isError: true);
                              } else {
                                  setState(() {
                                    _isLoading = true;
                                  });
                                  _showCustomSnackBar(context, "Creating account...", isError: false);

                                  ApiService().register(
                                    name: name,
                                    username: username,
                                    email: email,
                                    password: password,
                                   ).then((result) async {
                                     if (!context.mounted) {
                                       _isLoading = false;
                                       return;
                                     }

                                     if (result.success) {
                                       final token = result.data?['token'];
                                       final userData = result.data?['user'];

                                       if (token != null && userData != null) {
                                         await AuthService().login(token, userData);
                                       }

                                       if (!context.mounted) return;

                                       setState(() {
                                         _isLoading = false;
                                       });

                                       _showCustomSnackBar(context, "Registration successful!", isError: false);
                                       
                                       final navigator = Navigator.of(context);
                                       Future.delayed(const Duration(milliseconds: 500), () {
                                         navigator.pushAndRemoveUntil(
                                           MaterialPageRoute(settings: const RouteSettings(name: "/main"), builder: (context) => const MainWrapper()),
                                           (route) => false,
                                         );
                                       });
                                     } else {
                                       if (!context.mounted) return;
                                       setState(() {
                                         _isLoading = false;
                                       });
                                       _showCustomSnackBar(context, result.message, isError: true);
                                     }
                                   });
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
                                _isLoading ? "Please wait..." : "Sign Up",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 30),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Already have an account? ",
                              style: TextStyle(
                                color: const Color(0xff1C0D5A).withOpacity(0.6),
                                fontSize: 15,
                              ),
                            ),
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: const Text(
                                "Sign In",
                                style: TextStyle(
                                  color: Color(0xff5D3EBC),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    bool isPassword = false,
    bool obscureText = false,
    VoidCallback? onSuffixTap,
    TextInputType keyboardType = TextInputType.text,
    int? maxLength,
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
        inputFormatters: maxLength != null ? [LengthLimitingTextInputFormatter(maxLength)] : null,
        style: const TextStyle(color: Color(0xff1C0D5A), fontSize: 16),
        decoration: InputDecoration(
          hintText: hintText,
          counterText: "",
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

  // Custom SnackBar Method
  void _showCustomSnackBar(BuildContext context, String message, {required bool isError}) {
    showHidelySnackBar(context, message, isError: isError);
  }
}
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hidely_new/services/api_service.dart';
import 'package:hidely_new/services/auth_service.dart';
import 'package:hidely_new/widgets/custom_snackbar.dart';

class ChangePasswordScreen extends StatefulWidget {
  final String? email;
  final String? otp;

  const ChangePasswordScreen({
    super.key,
    this.email,
    this.otp,
  });

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _currentPasswordController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _isCurrentPasswordObscured = true;
  bool _isPasswordObscured = true;
  bool _isConfirmPasswordObscured = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
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
              colors: [Color(0xffE0F2FE), Color(0xffFDF7FF)],
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),

                  // Top Custom Circular Back Icon element
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: Center(child: Image.asset('assets/images/back_icon.png', color: const Color(0xff1C0D5A), width: 18.0, height: 18.0)),
                    ),
                  ),
                  const SizedBox(height: 35),

                  // Main Headings block
                  const Text(
                    "Change Password",
                    style: TextStyle(
                      color: Color(0xff1C0D5A),
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Set a brand new security password to authorize access to your account.",
                    style: TextStyle(
                      color: const Color(0xff1C0D5A).withOpacity(0.65),
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 45),

                  // Inputs labels & fields
                  if (widget.email == null || widget.otp == null) ...[
                    const Text("Current Password", style: TextStyle(color: Color(0xff1C0D5A), fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 10),
                    _buildInputField(
                      controller: _currentPasswordController,
                      hintText: "••••••••",
                      icon: Icons.lock_open_outlined,
                      isPassword: true,
                      obscureText: _isCurrentPasswordObscured,
                      onSuffixTap: () {
                        setState(() {
                          _isCurrentPasswordObscured = !_isCurrentPasswordObscured;
                        });
                      },
                    ),
                    const SizedBox(height: 24),
                  ],

                  const Text("New Password", style: TextStyle(color: Color(0xff1C0D5A), fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  _buildInputField(
                    controller: _passwordController,
                    hintText: "••••••••",
                    icon: Icons.lock_outline,
                    isPassword: true,
                    obscureText: _isPasswordObscured,
                    onSuffixTap: () {
                      setState(() {
                        _isPasswordObscured = !_isPasswordObscured;
                      });
                    },
                  ),
                  const SizedBox(height: 24),

                  const Text("Confirm New Password", style: TextStyle(color: Color(0xff1C0D5A), fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  _buildInputField(
                    controller: _confirmPasswordController,
                    hintText: "••••••••",
                    icon: Icons.lock_clock_outlined,
                    isPassword: true,
                    obscureText: _isConfirmPasswordObscured,
                    onSuffixTap: () {
                      setState(() {
                        _isConfirmPasswordObscured = !_isConfirmPasswordObscured;
                      });
                    },
                  ),
                  const SizedBox(height: 45),

                  // CTA Core Password Update Button
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (_isLoading) return;
                        final currentPassword = _currentPasswordController.text;
                        final password = _passwordController.text;
                        final confirmPassword = _confirmPasswordController.text;

                        final isResetFlow = widget.email != null && widget.otp != null;

                        if (!isResetFlow && currentPassword.isEmpty) {
                          _showCustomSnackBar(context, "Please enter your current password.", isError: true);
                        } else if (password.isEmpty) {
                          _showCustomSnackBar(context, "Please enter your new password.", isError: true);
                        } else if (confirmPassword.isEmpty) {
                          _showCustomSnackBar(context, "Please confirm your new password.", isError: true);
                        } else if (password.length < 6) {
                          _showCustomSnackBar(context, "Password must be at least 6 characters long.", isError: true);
                        } else if (password != confirmPassword) {
                          _showCustomSnackBar(context, "Passwords do not match.", isError: true);
                        } else {
                          setState(() {
                            _isLoading = true;
                          });
                          _showCustomSnackBar(context, isResetFlow ? "Resetting password..." : "Changing password...", isError: false);

                          ApiResult result;
                          if (isResetFlow) {
                            result = await ApiService().resetPassword(
                              email: widget.email!,
                              otp: widget.otp!,
                              newPassword: password,
                            );
                          } else {
                            result = await ApiService().changePassword(
                              token: AuthService().token ?? '',
                              oldPassword: currentPassword,
                              newPassword: password,
                            );
                          }

                          if (!context.mounted) {
                            _isLoading = false;
                            return;
                          }

                          setState(() {
                            _isLoading = false;
                          });

                          if (result.success) {
                            if (isResetFlow) {
                              _showCustomSnackBar(context, "Password reset successful! Please login.", isError: false);
                              Future.delayed(const Duration(milliseconds: 1000), () {
                                if (context.mounted) {
                                  Navigator.of(context).popUntil((route) => route.isFirst);
                                }
                              });
                            } else {
                              _showCustomSnackBar(context, "Password changed successfully!", isError: false);
                              Future.delayed(const Duration(milliseconds: 1000), () {
                                if (context.mounted) {
                                  Navigator.of(context).pop(true);
                                }
                              });
                            }
                          } else {
                            _showCustomSnackBar(context, result.message, isError: true);
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xff2B1564),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                        elevation: 0,
                      ),
                      child: Text(
                        _isLoading ? "Please wait..." : (widget.email != null && widget.otp != null ? "Reset Password" : "Change Password"),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Pure generic matching matte element builder
  Widget _buildInputField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    bool isPassword = false,
    bool obscureText = false,
    VoidCallback? onSuffixTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.65),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.0),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        style: const TextStyle(color: Color(0xff1C0D5A), fontSize: 16),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(color: const Color(0xff1C0D5A).withOpacity(0.3)),
          prefixIcon: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Icon(icon, color: const Color(0xff1C0D5A).withOpacity(0.5), size: 24),
          ),
          suffixIcon: isPassword
              ? GestureDetector(
            onTap: onSuffixTap,
            child: Icon(
              obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: const Color(0xff1C0D5A).withOpacity(0.5),
            ),
          )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 18),
        ),
      ),
    );
  }

  // Premium Floating SnackBar Method matching Login/SignUp design
  void _showCustomSnackBar(BuildContext context, String message, {required bool isError}) {
    showHidelySnackBar(context, message, isError: isError);
  }
}
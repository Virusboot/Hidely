import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hidely_new/screens/otp_verification_screen.dart';
import 'package:hidely_new/services/api_service.dart';
import 'package:hidely_new/widgets/custom_snackbar.dart';

class ForgetPasswordScreen extends StatefulWidget {
  const ForgetPasswordScreen({super.key});

  @override
  State<ForgetPasswordScreen> createState() => _ForgetPasswordScreenState();
}

class _ForgetPasswordScreenState extends State<ForgetPasswordScreen> {
  final _emailController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
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
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Center(child: Image.asset('assets/images/back_icon.png', color: const Color(0xff1C0D5A), width: 20.0, height: 20.0)),
                    ),
                  ),
                  const SizedBox(height: 35),
                  const Text(
                    "Forget Password",
                    style: TextStyle(
                      color: Color(0xff1C0D5A),
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Enter your email address and we'll send you an OTP to reset your password.",
                    style: TextStyle(
                      color: const Color(0xff1C0D5A).withOpacity(0.65),
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 40),
                  const Text(
                    "Email Address",
                    style: TextStyle(
                      color: Color(0xff1C0D5A),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.65),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.5),
                        width: 1.0,
                      ),
                    ),
                    child: TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(color: Color(0xff1C0D5A), fontSize: 16),
                      decoration: InputDecoration(
                        hintText: "explorer@auralens.com",
                        hintStyle: TextStyle(color: const Color(0xff1C0D5A).withOpacity(0.3)),
                        prefixIcon: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Icon(Icons.mail_outline, color: const Color(0xff1C0D5A).withOpacity(0.5), size: 24),
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 18),
                      ),
                    ),
                  ),
                  const SizedBox(height: 35),
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (_isLoading) return;
                        final email = _emailController.text.trim();
                        final emailRegex = RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+");

                        if (email.isEmpty) {
                          _showCustomSnackBar(context, "Please enter your email address.", isError: true);
                        } else if (!emailRegex.hasMatch(email)) {
                          _showCustomSnackBar(context, "Please enter a valid email address.", isError: true);
                        } else {
                          setState(() {
                            _isLoading = true;
                          });
                          _showCustomSnackBar(context, "Sending OTP...", isError: false);

                          final result = await ApiService().forgotPassword(email: email);
                          if (!context.mounted) return;

                          setState(() {
                            _isLoading = false;
                          });

                          if (result.success) {
                            _showCustomSnackBar(context, result.message, isError: false);
                            
                            Future.delayed(const Duration(milliseconds: 500), () {
                              if (!context.mounted) return;
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => OtpVerificationScreen(
                                    email: email,
                                    isSignupFlow: false,
                                    devOtp: result.data?['dev_otp']?.toString(),
                                  ),
                                ),
                              );
                            });
                          } else {
                            _showCustomSnackBar(context, result.message, isError: true);
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xff2B1564),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                        elevation: 0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _isLoading ? "Please wait..." : "Send OTP",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (!_isLoading) ...[
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward, color: Colors.white, size: 18),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 25),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Remember your password? ",
                        style: TextStyle(
                          color: const Color(0xff1C0D5A).withOpacity(0.6),
                          fontSize: 15,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Text(
                          "Log in",
                          style: TextStyle(
                            color: Color(0xff2B1564),
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

  // Premium Floating SnackBar Method matching Login/SignUp design
  void _showCustomSnackBar(BuildContext context, String message, {required bool isError}) {
    showHidelySnackBar(context, message, isError: isError);
  }
}
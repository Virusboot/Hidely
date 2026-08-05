import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hidely_new/screens/change_password_screen.dart';
import 'package:hidely_new/screens/main_wrapper.dart';
import 'package:hidely_new/services/auth_service.dart';
import 'package:hidely_new/services/api_service.dart';
import 'package:hidely_new/widgets/custom_snackbar.dart';

class OtpVerificationScreen extends StatefulWidget {
  final bool isSignupFlow;
  final String email;
  final String? devOtp;

  const OtpVerificationScreen({
    super.key,
    required this.email,
    this.isSignupFlow = false,
    this.devOtp,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final List<TextEditingController> _controllers = List.generate(4, (_) => TextEditingController(text: " "));
  final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());

  // Countdown timer state
  Timer? _timer;
  int _secondsRemaining = 30;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _startTimer();

    if (widget.devOtp != null) {
      debugPrint('[DEV] OTP Code is: ${widget.devOtp}');
    }

    // Auto-focus the first box on startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNodes[0].requestFocus();
      }
    });
  }

  void _startTimer() {
    setState(() {
      _secondsRemaining = 30;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        _timer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
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
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),

                  // Back Button
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

                  // Headings
                  const Text(
                    "Verification Code",
                    style: TextStyle(
                      color: Color(0xff1C0D5A),
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "We have sent a 4-digit verification code to your registered email address.",
                    style: TextStyle(
                      color: const Color(0xff1C0D5A).withOpacity(0.65),
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 45),

                  // 4 DIGIT OTP BOXES
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(4, (index) => _buildOtpBox(index)),
                  ),
                  const SizedBox(height: 40),

                  // Verify Button
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                       onPressed: () {
                        if (_isLoading) return;
                        String otp = _controllers.map((c) => c.text.trim()).join();
                        debugPrint("Verifying Secure Token Key: $otp");

                        if (otp.length == 4) {
                          setState(() {
                            _isLoading = true;
                          });
                          _showCustomSnackBar(context, "Verifying code...", isError: false);
                          
                          ApiService().verifyOtp(
                            email: widget.email,
                            otp: otp,
                          ).then((result) async {
                            if (!mounted) {
                              _isLoading = false;
                              return;
                            }
                            
                            setState(() {
                              _isLoading = false;
                            });
                            
                            if (result.success) {
                              if (widget.isSignupFlow) {
                                _showCustomSnackBar(context, "Account verified successfully!", isError: false);
                                
                                final token = result.data?['token'];
                                final userData = result.data?['user'];
                                
                                if (token != null && userData != null) {
                                  await AuthService().login(token, userData);
                                }
                                
                                Future.delayed(const Duration(milliseconds: 500), () {
                                  if (mounted) {
                                    Navigator.pushAndRemoveUntil(
                                      context,
                                      MaterialPageRoute(settings: const RouteSettings(name: "/main"), builder: (context) => const MainWrapper()),
                                      (route) => false,
                                    );
                                  }
                                });
                              } else {
                                _showCustomSnackBar(context, "Verification successful!", isError: false);
                                
                                Future.delayed(const Duration(milliseconds: 500), () {
                                  if (mounted) {
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ChangePasswordScreen(
                                          email: widget.email,
                                          otp: otp,
                                        ),
                                      ),
                                    );
                                  }
                                });
                              }
                            } else {
                              _showCustomSnackBar(context, result.message, isError: true);
                            }
                          });
                        } else {
                          _showCustomSnackBar(context, "Please enter the complete 4-digit code.", isError: true);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xff2B1564),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                        elevation: 0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _isLoading ? "Please wait..." : "Verify ",
                            style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                          ),
                          if (!_isLoading) ...[
                            const Icon(Icons.arrow_forward, color: Colors.white, size: 18),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Resend section with countdown timer
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Didn't receive the code? ",
                        style: TextStyle(
                          color: const Color(0xff1C0D5A).withOpacity(0.6),
                          fontSize: 15,
                        ),
                      ),
                      _secondsRemaining > 0
                          ? Text(
                              "Resend in ${_secondsRemaining}s",
                              style: TextStyle(
                                color: const Color(0xff1C0D5A).withOpacity(0.4),
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            )
                          : GestureDetector(
                              onTap: () async {
                                _showCustomSnackBar(context, "Resending OTP...", isError: false);
                                final result = await ApiService().forgotPassword(email: widget.email);
                                if (!context.mounted) return;
                                if (result.success) {
                                  _showCustomSnackBar(context, "OTP has been resent successfully!", isError: false);
                                  _startTimer();
                                } else {
                                  _showCustomSnackBar(context, result.message, isError: true);
                                }
                              },
                              child: const Text(
                                "Resend",
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

  Widget _buildOtpBox(int index) {
    return Container(
      width: 65,
      height: 65,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.65),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.2),
      ),
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        textAlignVertical: TextAlignVertical.center, // Vertically center the digit input
        style: const TextStyle(color: Color(0xff1C0D5A), fontSize: 24, fontWeight: FontWeight.bold),
        decoration: const InputDecoration(
          border: InputBorder.none,
          counterText: "",
          contentPadding: EdgeInsets.zero, // Avoid top shifting padding
        ),
        onChanged: (value) {
          // Support pasting 4-digit OTP code
          final cleanDigits = value.replaceAll(RegExp(r'\D'), '');
          if (cleanDigits.length == 4) {
            for (int i = 0; i < 4; i++) {
              _controllers[i].text = cleanDigits[i];
            }
            _focusNodes[3].requestFocus();
            return;
          }

          if (value.length > 1) {
            final newChar = value.substring(value.length - 1);
            _controllers[index].text = newChar;
            _controllers[index].selection = TextSelection.fromPosition(
              const TextPosition(offset: 1),
            );
            if (index < 3) {
              _focusNodes[index + 1].requestFocus();
            }
          } else if (value.isEmpty) {
            _controllers[index].text = " ";
            if (index > 0) {
              _controllers[index - 1].text = " ";
              _focusNodes[index - 1].requestFocus();
            }
          }
        },
      ),
    );
  }

  // Premium Floating SnackBar Method matching Login/SignUp design
  void _showCustomSnackBar(BuildContext context, String message, {required bool isError}) {
    showHidelySnackBar(context, message, isError: isError);
  }
}
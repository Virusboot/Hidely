import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:hidely_new/services/auth_service.dart';
import 'package:hidely_new/services/api_service.dart';
import 'package:hidely_new/widgets/custom_snackbar.dart';
import 'package:hidely_new/screens/terms_of_service_screen.dart';
import 'package:hidely_new/screens/privacy_policy_screen.dart';
import 'package:hidely_new/screens/post_signup_onboarding_screen.dart';

class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;

  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // OTP Verification state & controllers
  final List<TextEditingController> _otpControllers =
      List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes =
      List.generate(4, (_) => FocusNode());

  Timer? _otpTimer;
  int _otpSecondsRemaining = 30;
  int _otpResendAttempts = 0;
  bool _isSendingOtp = false;
  bool _isVerifyingOtp = false;
  bool _isEmailVerified = false;
  String? _verifiedEmail;
  String? _devOtp;

  final FocusNode _nameFocusNode = FocusNode();
  final FocusNode _usernameFocusNode = FocusNode();
  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();
  final FocusNode _confirmPasswordFocusNode = FocusNode();

  bool _isPasswordObscured = true;
  bool _isConfirmPasswordObscured = true;
  bool _isLoading = false;
  bool _isCheckingUsername = false;
  String? _selectedGender;
  bool _isAdultAndConsentAgreed = false;

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

  late final TapGestureRecognizer _learnMoreRecognizer = TapGestureRecognizer()
    ..onTap = () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const PrivacyPolicyScreen(),
        ),
      );
    };

  late final TapGestureRecognizer _cookiesRecognizer = TapGestureRecognizer()
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
    for (int i = 0; i < 4; i++) {
      final index = i;
      _otpFocusNodes[index].addListener(() {
        if (mounted) setState(() {});
      });
      _otpFocusNodes[index].onKeyEvent = (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.backspace) {
          if (_otpControllers[index].text.isEmpty && index > 0) {
            _otpControllers[index - 1].clear();
            _otpFocusNodes[index - 1].requestFocus();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      };
    }
  }

  @override
  void dispose() {
    _otpTimer?.cancel();
    _pageController.dispose();
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();

    for (var c in _otpControllers) {
      c.dispose();
    }
    for (var n in _otpFocusNodes) {
      n.dispose();
    }

    _nameFocusNode.dispose();
    _usernameFocusNode.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();

    _termsRecognizer.dispose();
    _privacyRecognizer.dispose();
    _learnMoreRecognizer.dispose();
    _cookiesRecognizer.dispose();
    super.dispose();
  }

  void _handleBack() {
    if (_isLoading || _isSendingOtp || _isVerifyingOtp) return;
    if (_currentStep > 0) {
      FocusScope.of(context).unfocus();
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubic,
      );
    } else {
      Navigator.pop(context);
    }
  }

  void _goToNextStep() {
    FocusScope.of(context).unfocus();
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOutCubic,
    );
  }

  void _startOtpTimer() {
    setState(() {
      _otpSecondsRemaining = 30;
    });
    _otpTimer?.cancel();
    _otpTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_otpSecondsRemaining > 0) {
        setState(() {
          _otpSecondsRemaining--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  void _clearOtpFields() {
    for (var c in _otpControllers) {
      c.clear();
    }
  }

  // --- Step 1: Name Validation ---
  void _onNameNext() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showCustomSnackBar(context, "Please write your full name", isError: true);
      _nameFocusNode.requestFocus();
      return;
    }
    if (name.length > 30) {
      _showCustomSnackBar(context, "Name cannot exceed 30 characters", isError: true);
      _nameFocusNode.requestFocus();
      return;
    }
    _goToNextStep();
    Future.delayed(const Duration(milliseconds: 320), () {
      if (mounted) _usernameFocusNode.requestFocus();
    });
  }

  // --- Step 2: Username Validation ---
  Future<void> _onUsernameNext() async {
    if (_isCheckingUsername) return;

    final username = _usernameController.text.trim();
    final usernameRegex = RegExp(r'^(?!.*\.\.)(?!.*__)(?!.*_\.)(?!.*\._)[a-zA-Z0-9._]{3,30}$');
    final startEndCheck = RegExp(r'^[a-zA-Z0-9].*[a-zA-Z0-9]$');

    if (username.isEmpty) {
      _showCustomSnackBar(context, "Please create a username", isError: true);
      _usernameFocusNode.requestFocus();
      return;
    }
    if (username.length < 3) {
      _showCustomSnackBar(context, "Username must be at least 3 characters", isError: true);
      _usernameFocusNode.requestFocus();
      return;
    }
    if (username.length > 30) {
      _showCustomSnackBar(context, "Username cannot exceed 30 characters", isError: true);
      _usernameFocusNode.requestFocus();
      return;
    }
    if (!startEndCheck.hasMatch(username) || !usernameRegex.hasMatch(username)) {
      _showCustomSnackBar(
        context,
        "Username can only contain letters, numbers, underscores, and periods. It cannot start/end with or have consecutive dots or underscores.",
        isError: true,
      );
      _usernameFocusNode.requestFocus();
      return;
    }

    setState(() {
      _isCheckingUsername = true;
    });

    final checkResult = await ApiService().checkUsernameAvailable(username: username);

    if (!mounted) return;

    setState(() {
      _isCheckingUsername = false;
    });

    if (!checkResult.success) {
      _showCustomSnackBar(
        context,
        checkResult.message.isNotEmpty ? checkResult.message : "Username is already taken. Please choose another.",
        isError: true,
      );
      _usernameFocusNode.requestFocus();
      return;
    }

    _goToNextStep();
  }

  // --- Step 3: Gender Validation ---
  void _onGenderNext() {
    if (_selectedGender == null || _selectedGender!.isEmpty) {
      _showCustomSnackBar(context, "Please select your gender", isError: true);
      return;
    }
    _goToNextStep();
    Future.delayed(const Duration(milliseconds: 320), () {
      if (mounted) _emailFocusNode.requestFocus();
    });
  }

  // --- Step 4: Email Validation & OTP Dispatch ---
  Future<void> _onEmailNext() async {
    if (_isSendingOtp) return;

    final email = _emailController.text.trim();
    final emailRegex = RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+");

    if (email.isEmpty) {
      _showCustomSnackBar(context, "Please enter your email", isError: true);
      _emailFocusNode.requestFocus();
      return;
    }
    if (!emailRegex.hasMatch(email)) {
      _showCustomSnackBar(context, "Please enter a valid email", isError: true);
      _emailFocusNode.requestFocus();
      return;
    }

    // If this email was already verified, proceed directly to Password step
    if (_isEmailVerified && _verifiedEmail?.toLowerCase() == email.toLowerCase()) {
      FocusScope.of(context).unfocus();
      _pageController.animateToPage(
        5,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubic,
      );
      Future.delayed(const Duration(milliseconds: 320), () {
        if (mounted) _passwordFocusNode.requestFocus();
      });
      return;
    }

    // Email changed or unverified -> reset verification state and send code
    _isEmailVerified = false;
    _verifiedEmail = null;

    setState(() {
      _isSendingOtp = true;
    });

    // 1. Immediately check if an account already exists with this email!
    final checkResult = await ApiService().checkEmailAvailable(email: email);
    if (!checkResult.success) {
      if (!mounted) return;
      setState(() {
        _isSendingOtp = false;
      });
      _showCustomSnackBar(
        context,
        checkResult.message.isNotEmpty
            ? checkResult.message
            : "An account already exists with this email. Please sign in or use a different email.",
        isError: true,
      );
      _emailFocusNode.requestFocus();
      return;
    }

    final result = await ApiService().sendEmailOtp(email: email);

    if (!mounted) return;

    setState(() {
      _isSendingOtp = false;
    });

    if (result.success) {
      final rawDevOtp = result.data?['dev_otp']?.toString();
      _devOtp = kDebugMode ? rawDevOtp : null;
      _showCustomSnackBar(context, result.message, isError: false);
      _clearOtpFields();
      _startOtpTimer();
      _goToNextStep();
      Future.delayed(const Duration(milliseconds: 320), () {
        if (mounted) _otpFocusNodes[0].requestFocus();
      });
    } else {
      _showCustomSnackBar(context, result.message, isError: true);
      _emailFocusNode.requestFocus();
    }
  }

  // --- Resend OTP Logic ---
  Future<void> _resendOtp() async {
    if (_isSendingOtp || _otpSecondsRemaining > 0) return;

    if (_otpResendAttempts >= 3) {
      _showCustomSnackBar(context, "Maximum OTP resend attempts reached. Please try again later.", isError: true);
      return;
    }

    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showCustomSnackBar(context, "Email is missing. Please go back and enter email.", isError: true);
      return;
    }

    setState(() {
      _isSendingOtp = true;
    });

    _otpResendAttempts++;
    _showCustomSnackBar(context, "Resending code (Attempt $_otpResendAttempts of 3)...", isError: false);

    final result = await ApiService().sendEmailOtp(email: email);

    if (!mounted) return;

    setState(() {
      _isSendingOtp = false;
    });

    if (result.success) {
      final rawDevOtp = result.data?['dev_otp']?.toString();
      _devOtp = kDebugMode ? rawDevOtp : null;
      _showCustomSnackBar(context, result.message, isError: false);
      _clearOtpFields();
      _startOtpTimer();
      _otpFocusNodes[0].requestFocus();
    } else {
      _showCustomSnackBar(context, result.message, isError: true);
    }
  }

  // --- Step 5: OTP Verification ---
  Future<void> _onOtpNext() async {
    if (_isVerifyingOtp) return;

    final email = _emailController.text.trim();

    // If already verified for this email, proceed directly
    if (_isEmailVerified && _verifiedEmail?.toLowerCase() == email.toLowerCase()) {
      _goToNextStep();
      Future.delayed(const Duration(milliseconds: 320), () {
        if (mounted) _passwordFocusNode.requestFocus();
      });
      return;
    }

    final otp = _otpControllers.map((c) => c.text.trim()).join();

    if (otp.length < 4) {
      _showCustomSnackBar(context, "Please enter the complete 4-digit code.", isError: true);
      for (int i = 0; i < 4; i++) {
        if (_otpControllers[i].text.trim().isEmpty) {
          _otpFocusNodes[i].requestFocus();
          break;
        }
      }
      return;
    }

    setState(() {
      _isVerifyingOtp = true;
    });

    final result = await ApiService().verifyEmailOtp(email: email, otp: otp);

    if (!mounted) return;

    setState(() {
      _isVerifyingOtp = false;
    });

    if (result.success) {
      _isEmailVerified = true;
      _verifiedEmail = email;
      _showCustomSnackBar(context, "Email verified successfully!", isError: false);
      _goToNextStep();
      Future.delayed(const Duration(milliseconds: 320), () {
        if (mounted) _passwordFocusNode.requestFocus();
      });
    } else {
      _showCustomSnackBar(context, result.message, isError: true);
    }
  }

  // --- Step 6: Password Validation ---
  void _onPasswordNext() {
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (password.isEmpty) {
      _showCustomSnackBar(context, "Please enter your password", isError: true);
      _passwordFocusNode.requestFocus();
      return;
    }
    if (password.length < 8) {
      _showCustomSnackBar(context, "Password must be at least 8 characters", isError: true);
      _passwordFocusNode.requestFocus();
      return;
    }
    if (password.length > 30) {
      _showCustomSnackBar(context, "Password cannot exceed 30 characters", isError: true);
      _passwordFocusNode.requestFocus();
      return;
    }
    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=\\/\[\]~`]').hasMatch(password)) {
      _showCustomSnackBar(context, "Password must contain at least one special character (e.g. !@#\$%^&*)", isError: true);
      _passwordFocusNode.requestFocus();
      return;
    }
    if (confirmPassword.isEmpty) {
      _showCustomSnackBar(context, "Please confirm your password", isError: true);
      _confirmPasswordFocusNode.requestFocus();
      return;
    }
    if (password != confirmPassword) {
      _showCustomSnackBar(context, "Passwords do not match", isError: true);
      _confirmPasswordFocusNode.requestFocus();
      return;
    }
    _goToNextStep();
  }

  // --- Step 7: Registration Submission ---
  void _submitRegistration() {
    if (_isLoading) return;

    final email = _emailController.text.trim();

    if (!_isEmailVerified || _verifiedEmail?.toLowerCase() != email.toLowerCase()) {
      _showCustomSnackBar(context, "Please verify your email address first", isError: true);
      _pageController.animateToPage(
        3,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubic,
      );
      return;
    }

    if (!_isAdultAndConsentAgreed) {
      _showCustomSnackBar(
        context,
        "Please confirm you are 18+ years old and agree to Hidely's Terms & Privacy Policy.",
        isError: true,
      );
      return;
    }

    final name = _nameController.text.trim();
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    setState(() {
      _isLoading = true;
    });
    _showCustomSnackBar(context, "Creating account...", isError: false);

    ApiService()
        .register(
      name: name,
      username: username,
      email: email,
      password: password,
      gender: _selectedGender,
      ageConfirmed: _isAdultAndConsentAgreed,
      termsAccepted: _isAdultAndConsentAgreed,
    )
        .then((result) async {
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
            MaterialPageRoute(
              settings: const RouteSettings(name: "/post_signup_onboarding"),
              builder: (context) => const PostSignupOnboardingScreen(),
            ),
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

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: PopScope(
        canPop: _currentStep == 0 && !_isLoading && !_isSendingOtp && !_isVerifyingOtp,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          if (_currentStep > 0 && !_isLoading && !_isSendingOtp && !_isVerifyingOtp) {
            _handleBack();
          }
        },
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
                  // Instagram-style top navigation bar with step progress indicator
                  _buildTopBar(),

                  // Multi-step PageView
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      onPageChanged: (index) {
                        setState(() {
                          _currentStep = index;
                        });
                      },
                      children: [
                        _buildStepContainer(child: _buildNameStepContent()),
                        _buildStepContainer(child: _buildUsernameStepContent()),
                        _buildStepContainer(child: _buildGenderStepContent()),
                        _buildStepContainer(child: _buildEmailStepContent()),
                        _buildStepContainer(child: _buildOtpStepContent()),
                        _buildStepContainer(child: _buildPasswordStepContent()),
                        _buildStepContainer(child: _buildTermsStepContent()),
                      ],
                    ),
                  ),

                  // Bottom "Already have an account? Sign In" link
                  _buildBottomSignInLink(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- Top App Bar with Circular Back Button matching Login / Password Screens ---
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.only(left: 28.0, top: 12.0, bottom: 4.0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: GestureDetector(
          onTap: _handleBack,
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
      ),
    );
  }

  // --- Common wrapper ensuring scrollability on small screens or with keyboard ---
  Widget _buildStepContainer({required Widget child}) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 28.0),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 460),
        child: child,
      ),
    );
  }

  // ==========================================
  // STEP 1: Full Name
  // ==========================================
  Widget _buildNameStepContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        const Text(
          "What's your name?",
          style: TextStyle(
            color: Color(0xff1C0D5A),
            fontSize: 28,
            fontWeight: FontWeight.bold,
            height: 1.2,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          "Add your full name so your friends and travel squad can easily recognize you.",
          style: TextStyle(
            color: const Color(0xff1C0D5A).withOpacity(0.65),
            fontSize: 15,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 32),
        _buildInputField(
          controller: _nameController,
          focusNode: _nameFocusNode,
          hintText: "Full Name",
          icon: Icons.person_outline,
          maxLength: 30,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => _onNameNext(),
        ),
        const SizedBox(height: 28),
        _buildActionButton(
          text: "Next",
          onPressed: _onNameNext,
        ),
      ],
    );
  }

  // ==========================================
  // STEP 2: Username
  // ==========================================
  Widget _buildUsernameStepContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        const Text(
          "Create a username",
          style: TextStyle(
            color: Color(0xff1C0D5A),
            fontSize: 28,
            fontWeight: FontWeight.bold,
            height: 1.2,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          "Choose a unique handle for your new account. You can always change it later.",
          style: TextStyle(
            color: const Color(0xff1C0D5A).withOpacity(0.65),
            fontSize: 15,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 32),
        _buildInputField(
          controller: _usernameController,
          focusNode: _usernameFocusNode,
          hintText: "Username",
          icon: Icons.alternate_email_rounded,
          maxLength: 30,
          textCapitalization: TextCapitalization.none,
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => _onUsernameNext(),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Text(
            "Use 3-30 letters, numbers, underscores, and periods.",
            style: TextStyle(
              color: const Color(0xff1C0D5A).withOpacity(0.5),
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(height: 24),
        _buildActionButton(
          text: _isCheckingUsername ? "Checking..." : "Next",
          isLoading: _isCheckingUsername,
          onPressed: _onUsernameNext,
        ),
      ],
    );
  }

  // ==========================================
  // STEP 3: Gender
  // ==========================================
  Widget _buildGenderStepContent() {
    final genderOptions = [
      {"label": "Male", "icon": Icons.male_rounded},
      {"label": "Female", "icon": Icons.female_rounded},
      {"label": "Other", "icon": Icons.transgender_rounded},
      {"label": "Prefer not to say", "icon": Icons.person_outline_rounded},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        const Text(
          "What's your gender?",
          style: TextStyle(
            color: Color(0xff1C0D5A),
            fontSize: 28,
            fontWeight: FontWeight.bold,
            height: 1.2,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          "Select your gender to personalize your experience and community discovery.",
          style: TextStyle(
            color: const Color(0xff1C0D5A).withOpacity(0.65),
            fontSize: 15,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 28),

        // Instagram-style selectable gender cards
        ...genderOptions.map((opt) {
          final label = opt["label"] as String;
          final icon = opt["icon"] as IconData;
          final isSelected = _selectedGender == label;

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedGender = label;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : Colors.white.withOpacity(0.7),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? const Color(0xff2B1564) : Colors.white.withOpacity(0.6),
                  width: isSelected ? 1.8 : 1.2,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: const Color(0xff2B1564).withOpacity(0.08),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ]
                    : null,
              ),
              child: Row(
                children: [
                  Icon(
                    icon,
                    color: isSelected ? const Color(0xff2B1564) : const Color(0xff1C0D5A).withOpacity(0.6),
                    size: 22,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: const Color(0xff1C0D5A),
                        fontSize: 16,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? const Color(0xff2B1564) : const Color(0xff1C0D5A).withOpacity(0.3),
                        width: 2,
                      ),
                      color: isSelected ? const Color(0xff2B1564) : Colors.transparent,
                    ),
                    child: isSelected
                        ? const Icon(
                            Icons.check,
                            size: 14,
                            color: Colors.white,
                          )
                        : null,
                  ),
                ],
              ),
            ),
          );
        }),

        const SizedBox(height: 18),
        _buildActionButton(
          text: "Next",
          onPressed: _onGenderNext,
        ),
      ],
    );
  }

  // ==========================================
  // STEP 4: Email Address
  // ==========================================
  Widget _buildEmailStepContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        const Text(
          "What's your email?",
          style: TextStyle(
            color: Color(0xff1C0D5A),
            fontSize: 28,
            fontWeight: FontWeight.bold,
            height: 1.2,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          "Enter your email address. We'll send a 4-digit verification code to confirm it's yours.",
          style: TextStyle(
            color: const Color(0xff1C0D5A).withOpacity(0.65),
            fontSize: 15,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 32),
        _buildInputField(
          controller: _emailController,
          focusNode: _emailFocusNode,
          hintText: "Email Address",
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => _onEmailNext(),
        ),
        const SizedBox(height: 28),
        _buildActionButton(
          text: _isSendingOtp ? "Sending code..." : "Next",
          isLoading: _isSendingOtp,
          onPressed: _onEmailNext,
        ),
      ],
    );
  }

  // ==========================================
  // STEP 5: Email OTP Verification
  // ==========================================
  Widget _buildOtpStepContent() {
    final email = _emailController.text.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        const Text(
          "Enter confirmation code",
          style: TextStyle(
            color: Color(0xff1C0D5A),
            fontSize: 28,
            fontWeight: FontWeight.bold,
            height: 1.2,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 10),
        RichText(
          text: TextSpan(
            style: TextStyle(
              color: const Color(0xff1C0D5A).withOpacity(0.65),
              fontSize: 15,
              height: 1.4,
              fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
            ),
            children: [
              const TextSpan(text: "To confirm your account, enter the 4-digit code sent to "),
              TextSpan(
                text: email.isNotEmpty ? email : "your email",
                style: const TextStyle(
                  color: Color(0xff1C0D5A),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const TextSpan(text: "."),
            ],
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () {
            if (_isVerifyingOtp || _isSendingOtp) return;
            FocusScope.of(context).unfocus();
            _pageController.previousPage(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOutCubic,
            );
            Future.delayed(const Duration(milliseconds: 320), () {
              if (mounted) _emailFocusNode.requestFocus();
            });
          },
          child: const Text(
            "Change email",
            style: TextStyle(
              color: Color(0xff5D3EBC),
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        if (kDebugMode && _devOtp != null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xff5D3EBC).withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xff5D3EBC).withOpacity(0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.key_rounded, size: 16, color: Color(0xff5D3EBC)),
                const SizedBox(width: 8),
                Text(
                  "Verification code: $_devOtp",
                  style: const TextStyle(
                    color: Color(0xff5D3EBC),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 32),

        // 4 DIGIT OTP BOXES (Centered with clean spacing)
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(4, (index) => _buildOtpBox(index)),
            ),
          ),
        ),
        const SizedBox(height: 28),

        // Resend countdown
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Didn't receive code? ",
              style: TextStyle(
                color: const Color(0xff1C0D5A).withOpacity(0.6),
                fontSize: 14.5,
              ),
            ),
            _otpSecondsRemaining > 0
                ? Text(
                    "Resend in ${_otpSecondsRemaining}s",
                    style: TextStyle(
                      color: const Color(0xff1C0D5A).withOpacity(0.45),
                      fontWeight: FontWeight.bold,
                      fontSize: 14.5,
                    ),
                  )
                : GestureDetector(
                    onTap: _isSendingOtp ? null : _resendOtp,
                    child: Text(
                      _otpResendAttempts >= 3 ? "Limit Reached" : "Resend Code",
                      style: TextStyle(
                        color: _otpResendAttempts >= 3 ? Colors.grey : const Color(0xff2B1564),
                        fontWeight: FontWeight.bold,
                        fontSize: 14.5,
                        decoration: _otpResendAttempts >= 3 ? null : TextDecoration.underline,
                      ),
                    ),
                  ),
          ],
        ),
        const SizedBox(height: 28),

        _buildActionButton(
          text: _isVerifyingOtp ? "Verifying..." : "Next",
          isLoading: _isVerifyingOtp,
          onPressed: _onOtpNext,
        ),
      ],
    );
  }

  Widget _buildOtpBox(int index) {
    final isFocused = _otpFocusNodes[index].hasFocus;
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.75),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isFocused ? const Color(0xff2B1564) : Colors.white.withOpacity(0.7),
          width: isFocused ? 1.8 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xff1C0D5A).withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: TextField(
        controller: _otpControllers[index],
        focusNode: _otpFocusNodes[index],
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        textAlignVertical: TextAlignVertical.center,
        showCursor: false,
        style: const TextStyle(
          color: Color(0xff1C0D5A),
          fontSize: 24,
          fontWeight: FontWeight.bold,
          height: 1.0,
          leadingDistribution: TextLeadingDistribution.even,
        ),
        decoration: const InputDecoration(
          isDense: true,
          isCollapsed: true,
          border: InputBorder.none,
          counterText: "",
          contentPadding: EdgeInsets.zero,
        ),
        onChanged: (value) {
          // Support pasting 4-digit OTP code
          final cleanDigits = value.replaceAll(RegExp(r'\D'), '');
          if (cleanDigits.length >= 4) {
            for (int i = 0; i < 4; i++) {
              _otpControllers[i].text = cleanDigits[i];
            }
            _otpFocusNodes[3].unfocus();
            _onOtpNext();
            return;
          }

          if (cleanDigits.isNotEmpty) {
            final lastChar = cleanDigits.substring(cleanDigits.length - 1);
            _otpControllers[index].text = lastChar;
            _otpControllers[index].selection = TextSelection.fromPosition(
              const TextPosition(offset: 1),
            );
            if (index < 3) {
              _otpFocusNodes[index + 1].requestFocus();
            } else {
              _otpFocusNodes[index].unfocus();
              final fullOtp = _otpControllers.map((c) => c.text.trim()).join();
              if (fullOtp.length == 4) {
                _onOtpNext();
              }
            }
          } else {
            _otpControllers[index].clear();
            if (index > 0) {
              _otpFocusNodes[index - 1].requestFocus();
            }
          }
        },
      ),
    );
  }

  // ==========================================
  // STEP 6: Password
  // ==========================================
  Widget _buildPasswordStepContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        const Text(
          "Create a password",
          style: TextStyle(
            color: Color(0xff1C0D5A),
            fontSize: 28,
            fontWeight: FontWeight.bold,
            height: 1.2,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          "Create a secure password with at least 8 characters and at least one special character.",
          style: TextStyle(
            color: const Color(0xff1C0D5A).withOpacity(0.65),
            fontSize: 15,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 32),
        _buildInputField(
          controller: _passwordController,
          focusNode: _passwordFocusNode,
          hintText: "Password",
          icon: Icons.lock_outline,
          isPassword: true,
          obscureText: _isPasswordObscured,
          maxLength: 30,
          textInputAction: TextInputAction.next,
          onSuffixTap: () {
            setState(() {
              _isPasswordObscured = !_isPasswordObscured;
            });
          },
          onSubmitted: (_) => _confirmPasswordFocusNode.requestFocus(),
        ),
        const SizedBox(height: 16),
        _buildInputField(
          controller: _confirmPasswordController,
          focusNode: _confirmPasswordFocusNode,
          hintText: "Confirm Password",
          icon: Icons.lock_outline,
          isPassword: true,
          obscureText: _isConfirmPasswordObscured,
          maxLength: 30,
          textInputAction: TextInputAction.done,
          onSuffixTap: () {
            setState(() {
              _isConfirmPasswordObscured = !_isConfirmPasswordObscured;
            });
          },
          onSubmitted: (_) => _onPasswordNext(),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Row(
            children: [
              Icon(Icons.shield_outlined, size: 16, color: const Color(0xff1C0D5A).withOpacity(0.55)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  "Must be 8-30 characters with 1 special symbol (e.g. !@#\$%^&*)",
                  style: TextStyle(
                    color: const Color(0xff1C0D5A).withOpacity(0.55),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        _buildActionButton(
          text: "Next",
          onPressed: _onPasswordNext,
        ),
      ],
    );
  }

  // ==========================================
  // STEP 7: Review & Agree to Terms (Final Submit)
  // ==========================================
  Widget _buildTermsStepContent() {
    final bodyFontFamily = Theme.of(context).textTheme.bodyMedium?.fontFamily;
    const bodyTextStyle = TextStyle(
      fontSize: 14.5,
      height: 1.45,
      fontWeight: FontWeight.w400,
    );
    const linkTextStyle = TextStyle(
      color: Color(0xff5D3EBC),
      fontSize: 14.5,
      height: 1.45,
      fontWeight: FontWeight.w600,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        const Text(
          "Agree to Hidely's terms and\npolicies",
          style: TextStyle(
            color: Color(0xff1C0D5A),
            fontSize: 28,
            fontWeight: FontWeight.bold,
            height: 1.25,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 22),

        // Paragraph 1: Age & optional permissions disclosure
        RichText(
          text: TextSpan(
            style: bodyTextStyle.copyWith(
              color: const Color(0xff1C0D5A).withOpacity(0.75),
              fontFamily: bodyFontFamily,
            ),
            children: [
              const TextSpan(
                text: "You must be at least 18 years old to join Hidely. Location access is strictly optional and used only with your permission. ",
              ),
              TextSpan(
                text: "Learn more",
                style: linkTextStyle,
                recognizer: _learnMoreRecognizer,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Paragraph 2: By confirming & tapping I agree...
        RichText(
          text: TextSpan(
            style: bodyTextStyle.copyWith(
              color: const Color(0xff1C0D5A).withOpacity(0.75),
              fontFamily: bodyFontFamily,
            ),
            children: [
              const TextSpan(text: "By confirming below and tapping "),
              const TextSpan(
                text: "I agree",
                style: TextStyle(
                  color: Color(0xff1C0D5A),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const TextSpan(
                text: ", you agree to create an account and to Hidely's ",
              ),
              TextSpan(
                text: "Terms",
                style: linkTextStyle,
                recognizer: _termsRecognizer,
              ),
              const TextSpan(text: ", "),
              TextSpan(
                text: "Privacy Policy",
                style: linkTextStyle,
                recognizer: _privacyRecognizer,
              ),
              const TextSpan(text: " and "),
              TextSpan(
                text: "Child Safety Standards",
                style: linkTextStyle,
                recognizer: _cookiesRecognizer,
              ),
              const TextSpan(text: "."),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Paragraph 3: Privacy Policy description (truthful Data Safety disclosure)
        RichText(
          text: TextSpan(
            style: bodyTextStyle.copyWith(
              color: const Color(0xff1C0D5A).withOpacity(0.75),
              fontFamily: bodyFontFamily,
            ),
            children: [
              const TextSpan(text: "The "),
              TextSpan(
                text: "Privacy Policy",
                style: linkTextStyle,
                recognizer: _privacyRecognizer,
              ),
              const TextSpan(
                text:
                    " explains how we process your profile and location data to operate discovery, messaging, and moderation features. We do not sell your data or serve behavioral third-party ads.",
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Mandatory 18+ Age & DPDP Data Consent Confirmation
        Material(
          color: Colors.white.withOpacity(0.78),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: _isAdultAndConsentAgreed
                  ? const Color(0xff5D3EBC)
                  : Colors.white.withOpacity(0.9),
              width: 1.4,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: CheckboxListTile(
            value: _isAdultAndConsentAgreed,
            onChanged: (val) {
              setState(() {
                _isAdultAndConsentAgreed = val ?? false;
              });
            },
            activeColor: const Color(0xff2B1564),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text(
              "I confirm I am at least 18 years old and consent to Hidely processing my personal data per the Privacy Policy & Terms.",
              style: TextStyle(
                color: Color(0xff1C0D5A),
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Primary Action Button
        _buildActionButton(
          text: _isLoading ? "Please wait..." : "I agree",
          isLoading: _isLoading,
          borderRadius: BorderRadius.circular(28),
          onPressed: _submitRegistration,
        ),
      ],
    );
  }

  // --- Primary Action Button (Matches existing app theme) ---
  Widget _buildActionButton({
    required String text,
    required VoidCallback onPressed,
    bool isLoading = false,
    BorderRadius? borderRadius,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xff2B1564),
          disabledBackgroundColor: const Color(0xff2B1564).withOpacity(0.7),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: borderRadius ?? BorderRadius.circular(20),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.2,
                ),
              ),
      ),
    );
  }

  // --- Input Field Builder (Matches Login / App theme with perfect alignment) ---
  Widget _buildInputField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    FocusNode? focusNode,
    bool isPassword = false,
    bool obscureText = false,
    VoidCallback? onSuffixTap,
    TextInputType keyboardType = TextInputType.text,
    TextInputAction textInputAction = TextInputAction.next,
    ValueChanged<String>? onSubmitted,
    TextCapitalization textCapitalization = TextCapitalization.none,
    int? maxLength,
    bool isRequired = true,
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
        focusNode: focusNode,
        obscureText: obscureText,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        onSubmitted: onSubmitted,
        textCapitalization: textCapitalization,
        textAlignVertical: TextAlignVertical.center,
        inputFormatters: maxLength != null ? [LengthLimitingTextInputFormatter(maxLength)] : null,
        style: const TextStyle(
          color: Color(0xff1C0D5A),
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          isDense: true,
          hintText: isRequired ? "$hintText *" : hintText,
          counterText: "",
          hintStyle: TextStyle(
            color: const Color(0xff1C0D5A).withOpacity(0.4),
            fontSize: 16,
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 16.0, right: 12.0),
            child: Icon(icon, color: const Color(0xff1C0D5A).withOpacity(0.6), size: 22),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 50, minHeight: 0),
          suffixIcon: isPassword
              ? GestureDetector(
                  onTap: onSuffixTap,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 16.0),
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
          contentPadding: const EdgeInsets.symmetric(vertical: 18.0),
        ),
      ),
    );
  }

  // --- Bottom Sign In Navigation Link ---
  Widget _buildBottomSignInLink() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0, top: 10.0),
      child: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: _currentStep == 6
            ? const Text(
                "I already have an account",
                style: TextStyle(
                  color: Color(0xff5D3EBC),
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Already have an account? ",
                    style: TextStyle(
                      color: const Color(0xff1C0D5A).withOpacity(0.6),
                      fontSize: 15,
                    ),
                  ),
                  const Text(
                    "Sign In",
                    style: TextStyle(
                      color: Color(0xff5D3EBC),
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // Custom SnackBar Method
  void _showCustomSnackBar(BuildContext context, String message, {required bool isError}) {
    showHidelySnackBar(context, message, isError: isError);
  }
}

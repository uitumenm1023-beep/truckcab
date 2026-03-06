import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_roles.dart';
import '../../core/utils/validators.dart';
import '../../providers/auth_provider.dart';
import '../../routes/app_routes.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const Color _bgTop = Color(0xFF171A20);
  static const Color _bgBottom = Color(0xFF101216);
  static const Color _card = Color(0xFF1B1F26);
  static const Color _softCard = Color(0xFF252A33);
  static const Color _accent = Color(0xFFFF5A1F);
  static const Color _textPrimary = Color(0xFFF5F7FA);
  static const Color _textSecondary = Color(0xFF98A1AE);

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _obscurePassword = true;
  double _dragProgress = 0.0;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSliderComplete() async {
    if (_isSubmitting) return;

    if (!_formKey.currentState!.validate()) {
      _resetSlider();
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final success = await authProvider.login(
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
    );

    if (!mounted) return;

    if (!success) {
      setState(() {
        _isSubmitting = false;
      });

      _resetSlider();

      final message = authProvider.errorMessage ?? 'Login failed';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      return;
    }

    final userId = authProvider.currentUserId;

    if (userId == null || userId.isEmpty) {
      setState(() {
        _isSubmitting = false;
      });

      _resetSlider();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User session not found')),
      );
      return;
    }

    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();

      if (!mounted) return;

      if (!userDoc.exists) {
        setState(() {
          _isSubmitting = false;
        });

        _resetSlider();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User profile not found')),
        );
        return;
      }

      final data = userDoc.data();
      final role = (data?['role'] ?? '').toString().trim().toLowerCase();

      setState(() {
        _isSubmitting = false;
      });

      if (role == AppRoles.seller) {
        Navigator.pushReplacementNamed(context, AppRoutes.sellerHome);
      } else if (role == AppRoles.driver) {
        Navigator.pushReplacementNamed(context, AppRoutes.driverHome);
      } else {
        _resetSlider();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid user role')),
        );
      }
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isSubmitting = false;
      });

      _resetSlider();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load user profile')),
      );
    }
  }

  void _resetSlider() {
    if (!mounted) return;
    setState(() {
      _dragProgress = 0.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: _bgBottom,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _bgTop,
              _bgBottom,
            ],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: const BoxDecoration(
                      color: _accent,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.local_shipping_outlined,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: _card,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0x16FFFFFF)),
                    ),
                    child: IconButton(
                      onPressed: () {
                        Navigator.pushReplacementNamed(context, AppRoutes.signup);
                      },
                      icon: const Icon(
                        Icons.person_add_alt_1_outlined,
                        color: _textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 34),
              const Text(
                'Welcome\nBack',
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 42,
                  fontWeight: FontWeight.w300,
                  height: 1.02,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Sign in to continue managing deliveries and orders.',
                style: TextStyle(
                  color: _textSecondary,
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 26),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: _card,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: const Color(0x14FFFFFF)),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _DarkInputField(
                        controller: _emailController,
                        label: 'Email',
                        hint: 'Enter your email',
                        keyboardType: TextInputType.emailAddress,
                        validator: Validators.validateEmail,
                        prefixIcon: Icons.email_outlined,
                      ),
                      const SizedBox(height: 14),
                      _DarkInputField(
                        controller: _passwordController,
                        label: 'Password',
                        hint: 'Enter your password',
                        obscureText: _obscurePassword,
                        validator: Validators.validatePassword,
                        prefixIcon: Icons.lock_outline_rounded,
                        suffix: IconButton(
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: _textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      if (authProvider.errorMessage != null &&
                          authProvider.errorMessage!.isNotEmpty)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0x33FF5A1F),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            authProvider.errorMessage!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      _SlideActionButton(
                        text: _isSubmitting || authProvider.isLoading
                            ? 'Signing In...'
                            : 'Slide to Sign In',
                        progress: _dragProgress,
                        isLoading: _isSubmitting || authProvider.isLoading,
                        onProgressChanged: (value) {
                          if (_isSubmitting || authProvider.isLoading) return;
                          setState(() {
                            _dragProgress = value;
                          });
                        },
                        onCompleted: _handleSliderComplete,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: _softCard,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: _accent,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'New here? Create an account and choose seller or driver.',
                        style: TextStyle(
                          color: _textSecondary,
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pushReplacementNamed(context, AppRoutes.signup);
                      },
                      child: const Text(
                        'Sign Up',
                        style: TextStyle(
                          color: _textPrimary,
                          fontWeight: FontWeight.w600,
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

class _DarkInputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final bool obscureText;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final IconData prefixIcon;
  final Widget? suffix;

  const _DarkInputField({
    required this.controller,
    required this.label,
    required this.hint,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.validator,
    required this.prefixIcon,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(
        color: Color(0xFFF5F7FA),
        fontSize: 15,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: Color(0xFF98A1AE)),
        hintStyle: const TextStyle(color: Color(0xFF6F7784)),
        prefixIcon: Icon(prefixIcon, color: const Color(0xFF98A1AE)),
        suffixIcon: suffix,
        filled: true,
        fillColor: const Color(0xFF252A33),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Color(0x12FFFFFF)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Color(0x55FF5A1F)),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
      ),
    );
  }
}

class _SlideActionButton extends StatefulWidget {
  final String text;
  final double progress;
  final bool isLoading;
  final ValueChanged<double> onProgressChanged;
  final Future<void> Function() onCompleted;

  const _SlideActionButton({
    required this.text,
    required this.progress,
    required this.isLoading,
    required this.onProgressChanged,
    required this.onCompleted,
  });

  @override
  State<_SlideActionButton> createState() => _SlideActionButtonState();
}

class _SlideActionButtonState extends State<_SlideActionButton> {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const knobSize = 52.0;
        final maxDrag = constraints.maxWidth - knobSize - 8;
        final knobLeft = 4 + (maxDrag * widget.progress);

        return Container(
          height: 60,
          decoration: BoxDecoration(
            color: const Color(0xFF252A33),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: const Color(0x14FFFFFF)),
          ),
          child: Stack(
            children: [
              Center(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  opacity: widget.progress > 0.15 ? 0.2 : 1,
                  child: widget.isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          widget.text,
                          style: const TextStyle(
                            color: Color(0xFFF5F7FA),
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              AnimatedPositioned(
                duration: widget.isLoading
                    ? const Duration(milliseconds: 180)
                    : Duration.zero,
                left: knobLeft,
                top: 4,
                child: GestureDetector(
                  onHorizontalDragUpdate: widget.isLoading
                      ? null
                      : (details) {
                          final dx = details.localPosition.dx;
                          final relative =
                              ((knobLeft + dx) / (constraints.maxWidth)).clamp(0.0, 1.0);
                          final progress = ((relative * constraints.maxWidth) / maxDrag)
                              .clamp(0.0, 1.0);
                          widget.onProgressChanged(progress);
                        },
                  onHorizontalDragEnd: widget.isLoading
                      ? null
                      : (_) async {
                          if (widget.progress > 0.82) {
                            widget.onProgressChanged(1.0);
                            await widget.onCompleted();
                          } else {
                            widget.onProgressChanged(0.0);
                          }
                        },
                  child: Container(
                    width: knobSize,
                    height: knobSize,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF5A1F),
                      shape: BoxShape.circle,
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x66FF5A1F),
                          blurRadius: 16,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
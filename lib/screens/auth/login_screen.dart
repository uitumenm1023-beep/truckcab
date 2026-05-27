import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_roles.dart';
import '../../core/utils/validators.dart';
import '../../providers/auth_provider.dart';
import '../../routes/app_routes.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
/// Same grey as the welcome oval — seamless continuation after fill animation
const Color _bg      = Color(0xFF1E1E1E);
const Color _bgTop   = Color(0xFF1A1A1A);
const Color _card    = Color(0xFF2C2C2C);
const Color _soft    = Color(0xFF3A3A3A);
const Color _accent  = Color(0xFF89F336);
const Color _textPri = Color(0xFFF5F7FA);
const Color _textSec = Color(0xFF98A1AE);
const Color _border  = Color(0x14B5CDD0);

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  final _formKey   = GlobalKey<FormState>();

  bool _obscurePass  = true;
  bool _isSubmitting = false;

  final FirebaseFirestore _fs = FirebaseFirestore.instance;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  // ── Email login ────────────────────────────────────────────────────────────
  Future<void> _loginEmail() async {
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    final auth = context.read<AppAuthProvider>();
    final ok   = await auth.login(
      email: _emailCtrl.text.trim(),
      password: _passCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (ok) {
      await _navigate(auth.currentUserId);
    }
  }

  Future<void> _navigate(String? uid) async {
    if (uid == null || uid.isEmpty) { _snack('User session not found'); return; }
    try {
      final doc = await _fs.collection('users').doc(uid).get();
      if (!mounted) return;
      final data    = doc.data() ?? {};
      final role    = ((data['role'] ?? '') as String).trim().toLowerCase();
      final isAdmin = data['isAdmin'] == true;

      bool subscribed = isAdmin;
      if (!subscribed) {
        final expTs = data['subscriptionExpiry'];
        if (expTs is Timestamp) {
          subscribed = expTs.toDate().isAfter(DateTime.now());
        }
      }
      if (!subscribed) {
        Navigator.pushReplacementNamed(context, AppRoutes.subscription);
        return;
      }

      if (isAdmin) {
        Navigator.pushReplacementNamed(context, AppRoutes.admin);
      } else if (role == AppRoles.seller) {
        Navigator.pushReplacementNamed(context, AppRoutes.sellerHome);
      } else if (role == AppRoles.driver) {
        Navigator.pushReplacementNamed(context, AppRoutes.driverHome);
      } else {
        _snack('Account setup incomplete. Please contact support.');
      }
    } catch (_) {
      _snack('Failed to load user profile');
    }
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AppAuthProvider>();

    return Scaffold(
      backgroundColor: _bg,
      body: Stack(children: [
        // ── Main form content ────────────────────────────────────────────────
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_bgTop, _bg],
            ),
          ),
          child: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
              children: [
                // Top bar
                Row(children: [
                  GestureDetector(
                    onTap: () => Navigator.pushReplacementNamed(
                        context, AppRoutes.welcome),
                    child: Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: _card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _border),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: _textPri, size: 16),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    width: 44, height: 44,
                    decoration: const BoxDecoration(
                        color: _accent, shape: BoxShape.circle),
                    child: const Icon(Icons.local_shipping_rounded,
                        color: Color(0xFF1A1A1A), size: 22),
                  ),
                ]),
                const SizedBox(height: 34),
                const Text('Welcome\nBack',
                    style: TextStyle(
                        color: _textPri,
                        fontSize: 42,
                        fontWeight: FontWeight.w300,
                        height: 1.02)),
                const SizedBox(height: 10),
                const Text(
                    'Sign in to continue managing deliveries and orders.',
                    style: TextStyle(color: _textSec, fontSize: 14, height: 1.45)),
                const SizedBox(height: 26),

                // Form card
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: _card,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: _border),
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(children: [
                      _Field(
                        ctrl: _emailCtrl,
                        label: 'Email',
                        hint: 'Enter your email',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        validator: Validators.validateEmail,
                      ),
                      const SizedBox(height: 14),
                      _Field(
                        ctrl: _passCtrl,
                        label: 'Password',
                        hint: 'Enter your password',
                        icon: Icons.lock_outline_rounded,
                        obscure: _obscurePass,
                        validator: Validators.validatePassword,
                        suffix: IconButton(
                          onPressed: () =>
                              setState(() => _obscurePass = !_obscurePass),
                          icon: Icon(
                            _obscurePass
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: _textSec,
                          ),
                        ),
                      ),

                      // Error banner
                      if (auth.errorMessage != null &&
                          auth.errorMessage!.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0x2289F336),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: const Color(0x4489F336)),
                          ),
                          child: Row(children: [
                            const Icon(Icons.warning_amber_rounded,
                                color: _accent, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(auth.errorMessage!,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      height: 1.4)),
                            ),
                          ]),
                        ),
                      ],

                      const SizedBox(height: 18),

                      // ── Simple Sign In button (replaces swipe) ─────────────
                      GestureDetector(
                        onTap: _loginEmail,
                        child: Container(
                          height: 56,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _accent,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Text(
                            'Sign In',
                            style: TextStyle(
                              color: Color(0xFF1A1A1A),
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 18),

                // Sign up hint
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: _soft, borderRadius: BorderRadius.circular(24)),
                  child: Row(children: [
                    const Icon(Icons.info_outline, color: _accent, size: 20),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                          'New here? Create an account and choose seller or driver.',
                          style: TextStyle(
                              color: _textSec, fontSize: 13, height: 1.35)),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pushReplacementNamed(
                          context, AppRoutes.welcome),
                      child: const Text('Sign Up',
                          style: TextStyle(
                              color: _textPri,
                              fontWeight: FontWeight.w600)),
                    ),
                  ]),
                ),
              ],
            ),
          ),
        ),

        // ── 3-D spinning loading overlay ─────────────────────────────────────
        if (_isSubmitting) const _LoadingOverlay(),
      ]),
    );
  }
}

// ── Reusable text field ───────────────────────────────────────────────────────
class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String label, hint;
  final IconData icon;
  final bool obscure;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final Widget? suffix;
  const _Field({
    required this.ctrl,
    required this.label,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: ctrl,
        obscureText: obscure,
        keyboardType: keyboardType,
        validator: validator,
        style: const TextStyle(color: _textPri, fontSize: 15),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: const TextStyle(color: _textSec),
          hintStyle: const TextStyle(color: Color(0xFF6F7784)),
          prefixIcon: Icon(icon, color: _textSec),
          suffixIcon: suffix,
          filled: true,
          fillColor: _soft,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: const BorderSide(color: _border)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide:
                  const BorderSide(color: Color(0x5589F336))),
          errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide:
                  const BorderSide(color: Colors.redAccent)),
          focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide:
                  const BorderSide(color: Colors.redAccent)),
        ),
      );
}

// ── Full-screen 3D loading overlay ────────────────────────────────────────────
class _LoadingOverlay extends StatefulWidget {
  const _LoadingOverlay();

  @override
  State<_LoadingOverlay> createState() => _LoadingOverlayState();
}

class _LoadingOverlayState extends State<_LoadingOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _spin;

  @override
  void initState() {
    super.initState();
    // One full rotation every 1.4 s, repeats forever
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xE0080808), // near-black overlay, slightly transparent
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── 3-D spinning truck icon ────────────────────────────────────
            AnimatedBuilder(
              animation: _spin,
              builder: (_, __) {
                final angle  = _spin.value * 2 * math.pi;
                final cosA   = math.cos(angle);

                // Glow pulses from bright (facing camera) to dim (edge-on)
                final glow = ((1 + cosA) / 2 * 0.55).clamp(0.05, 0.55);

                return Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.0015) // perspective depth
                    ..rotateY(angle)
                    ..rotateX(math.sin(angle) * 0.18), // subtle wobble
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: _accent,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _accent.withOpacity(glow),
                          blurRadius: 40,
                          spreadRadius: 6,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.local_shipping_rounded,
                      color: Color(0xFF1A1A1A),
                      size: 46,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 28),
            // Pulsing dots
            _PulsingDots(),
            const SizedBox(height: 16),
            const Text(
              'Signing in…',
              style: TextStyle(
                color: _textSec,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Three pulsing dots ────────────────────────────────────────────────────────
class _PulsingDots extends StatefulWidget {
  @override
  State<_PulsingDots> createState() => _PulsingDotsState();
}

class _PulsingDotsState extends State<_PulsingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _ac;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ac,
      builder: (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            // Each dot is offset by 1/3 of the cycle
            final offset    = i / 3.0;
            final t         = (_ac.value + offset) % 1.0;
            // Scale: 1.0 → 1.6 → 1.0 with a sine curve
            final scale     = 1.0 + 0.6 * math.sin(t * math.pi);
            final opacity   = 0.35 + 0.65 * math.sin(t * math.pi);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Transform.scale(
                scale: scale,
                child: Opacity(
                  opacity: opacity.clamp(0.0, 1.0),
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: _accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

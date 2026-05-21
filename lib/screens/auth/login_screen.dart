import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_roles.dart';
import '../../core/utils/validators.dart';
import '../../providers/auth_provider.dart';
import '../../routes/app_routes.dart';

// ── Palette ──────────────────────────────────────────────────────────────────
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

  bool   _obscurePass  = true;
  bool   _isSubmitting = false;
  double _drag         = 0.0;

  final FirebaseFirestore _fs = FirebaseFirestore.instance;

  @override
  void dispose() {
    _emailCtrl.dispose(); _passCtrl.dispose();
    super.dispose();
  }

  // ── Email login ────────────────────────────────────────────────────────────
  Future<void> _loginEmail() async {
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) { _resetSlider(); return; }
    setState(() => _isSubmitting = true);

    final auth = context.read<AppAuthProvider>();
    final ok   = await auth.login(
      email: _emailCtrl.text.trim(), password: _passCtrl.text.trim());
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (ok) {
      await _navigate(auth.currentUserId);
    } else {
      _resetSlider();
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

      // Subscription gate — same check as SplashScreen
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
        _snack('Invalid user role');
      }
    } catch (_) {
      _snack('Failed to load user profile');
    }
  }

  void _resetSlider() => setState(() => _drag = 0.0);
  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AppAuthProvider>();

    return Scaffold(
      backgroundColor: _bg,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [_bgTop, _bg])),
        child: SafeArea(child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
          children: [
            // Top bar
            Row(children: [
              Container(width: 42, height: 42,
                decoration: const BoxDecoration(color: _accent, shape: BoxShape.circle),
                child: const Icon(Icons.local_shipping_outlined, color: Colors.white, size: 22)),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.pushReplacementNamed(context, AppRoutes.signup),
                child: Container(width: 46, height: 46,
                  decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: _border)),
                  child: const Icon(Icons.person_add_alt_1_outlined, color: _textPri)),
              ),
            ]),
            const SizedBox(height: 34),
            const Text('Welcome\nBack', style: TextStyle(
              color: _textPri, fontSize: 42, fontWeight: FontWeight.w300, height: 1.02)),
            const SizedBox(height: 10),
            const Text('Sign in to continue managing deliveries and orders.',
              style: TextStyle(color: _textSec, fontSize: 14, height: 1.45)),
            const SizedBox(height: 26),

            // Form card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: _card, borderRadius: BorderRadius.circular(28),
                border: Border.all(color: _border)),
              child: Form(key: _formKey, child: Column(children: [
                _Field(ctrl: _emailCtrl, label: 'Email', hint: 'Enter your email',
                  icon: Icons.email_outlined, keyboardType: TextInputType.emailAddress,
                  validator: Validators.validateEmail),
                const SizedBox(height: 14),
                _Field(ctrl: _passCtrl, label: 'Password', hint: 'Enter your password',
                  icon: Icons.lock_outline_rounded, obscure: _obscurePass,
                  validator: Validators.validatePassword,
                  suffix: IconButton(
                    onPressed: () => setState(() => _obscurePass = !_obscurePass),
                    icon: Icon(_obscurePass ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: _textSec))),

                // Error banner
                if (auth.errorMessage != null && auth.errorMessage!.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity, padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0x2289F336), borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0x4489F336))),
                    child: Row(children: [
                      const Icon(Icons.warning_amber_rounded, color: _accent, size: 16),
                      const SizedBox(width: 8),
                      Expanded(child: Text(auth.errorMessage!,
                        style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4))),
                    ]),
                  ),
                ],

                const SizedBox(height: 18),
                _SlideButton(
                  text: _isSubmitting || auth.isLoading ? 'Signing In…' : 'Slide to Sign In',
                  progress: _drag, isLoading: _isSubmitting || auth.isLoading,
                  onProgressChanged: (v) => setState(() => _drag = v),
                  onCompleted: _loginEmail,
                ),
              ])),
            ),
            const SizedBox(height: 18),

            // Sign up hint
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: _soft, borderRadius: BorderRadius.circular(24)),
              child: Row(children: [
                const Icon(Icons.info_outline, color: _accent, size: 20),
                const SizedBox(width: 12),
                const Expanded(child: Text('New here? Create an account and choose seller or driver.',
                  style: TextStyle(color: _textSec, fontSize: 13, height: 1.35))),
                TextButton(
                  onPressed: () => Navigator.pushReplacementNamed(context, AppRoutes.signup),
                  child: const Text('Sign Up',
                    style: TextStyle(color: _textPri, fontWeight: FontWeight.w600))),
              ]),
            ),
          ],
        )),
      ),
    );
  }
}

// ── Reusable field ────────────────────────────────────────────────────────────
class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String label, hint;
  final IconData icon;
  final bool obscure;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final Widget? suffix;
  const _Field({required this.ctrl, required this.label, required this.hint,
    required this.icon, this.obscure = false, this.keyboardType = TextInputType.text,
    this.validator, this.suffix});

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: ctrl, obscureText: obscure, keyboardType: keyboardType, validator: validator,
    style: const TextStyle(color: _textPri, fontSize: 15),
    decoration: InputDecoration(
      labelText: label, hintText: hint,
      labelStyle: const TextStyle(color: _textSec),
      hintStyle: const TextStyle(color: Color(0xFF6F7784)),
      prefixIcon: Icon(icon, color: _textSec), suffixIcon: suffix,
      filled: true, fillColor: _soft,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: _border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: Color(0x5589F336))),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: Colors.redAccent)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: Colors.redAccent)),
    ),
  );
}

// ── Slide button ──────────────────────────────────────────────────────────────
class _SlideButton extends StatelessWidget {
  final String text;
  final double progress;
  final bool isLoading;
  final ValueChanged<double> onProgressChanged;
  final Future<void> Function() onCompleted;
  const _SlideButton({required this.text, required this.progress, required this.isLoading,
    required this.onProgressChanged, required this.onCompleted});

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (ctx, c) {
    const ks = 52.0;
    final max = c.maxWidth - ks - 8;
    final left = 4 + (max * progress);
    return Container(height: 60,
      decoration: BoxDecoration(color: _soft, borderRadius: BorderRadius.circular(30),
        border: Border.all(color: _border)),
      child: Stack(children: [
        // Track fill
        Positioned(
          left: 4, top: 4, bottom: 4, right: 4,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: Align(
              alignment: Alignment.centerLeft,
              child: AnimatedContainer(
                duration: Duration.zero,
                width: (left + ks / 2).clamp(0.0, c.maxWidth - 8),
                color: _accent.withOpacity(0.08),
              ),
            ),
          ),
        ),
        Center(child: AnimatedOpacity(
          duration: const Duration(milliseconds: 180), opacity: progress > 0.15 ? 0.0 : 1,
          child: isLoading
            ? const SizedBox(width: 22, height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
            : Text(text, style: const TextStyle(color: _textPri, fontSize: 15, fontWeight: FontWeight.w600)))),
        Positioned(
          left: left, top: 4,
          child: GestureDetector(
            onHorizontalDragUpdate: isLoading ? null : (d) {
              // Use delta.dx for smooth, 1:1 touch tracking
              final newProgress = (progress + d.delta.dx / max).clamp(0.0, 1.0);
              onProgressChanged(newProgress);
            },
            onHorizontalDragEnd: isLoading ? null : (_) async {
              if (progress > 0.82) { onProgressChanged(1.0); await onCompleted(); }
              else { onProgressChanged(0.0); }
            },
            child: Container(width: ks, height: ks,
              decoration: const BoxDecoration(color: _accent, shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Color(0x6689F336), blurRadius: 16, offset: Offset(0, 6))]),
              child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 24)),
          )),
      ]));
  });
}
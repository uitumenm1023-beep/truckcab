import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../auth/login_screen.dart';
import '../auth/signup_screen.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
/// Near-black outer ring — the "black" part the user sees around the oval
const Color _screenBg = Color(0xFF080808);
/// Mid-dark grey oval — the "grey" stage behind the truck
const Color _ovalBg   = Color(0xFF1E1E1E);
const Color _accent   = Color(0xFF89F336);
const Color _textPri  = Color(0xFFF5F7FA);
const Color _textSec  = Color(0xFF98A1AE);

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});
  @override State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ac;

  /// Truck + oval slide DOWN together off screen
  late Animation<Offset> _truckSlide;
  /// Grey oval expands from its centre outward to fill the whole screen
  late Animation<double> _ovalScale;
  /// Buttons & title fade out quickly so they don't fight the fill
  late Animation<double> _contentFade;

  /// Which screen to push after the animation completes
  bool _goLogin = true;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 820),
    );

    // Truck slides down and off screen
    _truckSlide = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, 2.2),
    ).animate(CurvedAnimation(
      parent: _ac,
      curve: const Interval(0.0, 0.65, curve: Curves.easeInCubic),
    ));

    // Grey oval expands like a ripple to fill the whole screen
    _ovalScale = Tween<double>(begin: 1.0, end: 6.0).animate(
      CurvedAnimation(
        parent: _ac,
        curve: const Interval(0.15, 1.0, curve: Curves.easeOut),
      ),
    );

    // Bottom content fades out in the first quarter of the animation
    _contentFade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _ac,
        curve: const Interval(0.0, 0.25, curve: Curves.easeIn),
      ),
    );

    _ac.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        // Zero-duration push: the grey fill is already covering the screen,
        // so the next screen appears seamlessly (same grey background).
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
            pageBuilder: (_, __, ___) =>
                _goLogin ? const LoginScreen() : const SignupScreen(),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  void _goTo({required bool login}) {
    if (_ac.isAnimating || _ac.isCompleted) return;
    _goLogin = login;
    _ac.forward();
  }

  @override
  Widget build(BuildContext context) {
    final size   = MediaQuery.of(context).size;
    final bottom = MediaQuery.of(context).padding.bottom;
    final ovalH  = size.height * 0.58;

    return Scaffold(
      backgroundColor: _screenBg,          // near-black outer background
      body: Stack(children: [

        // ── Layer 1: Expanding grey oval (fills screen on tap) ─────────────
        AnimatedBuilder(
          animation: _ovalScale,
          builder: (_, __) => Positioned(
            top: 0, left: 0, right: 0,
            child: Transform.scale(
              scale: _ovalScale.value,
              alignment: const Alignment(0, -0.55),
              child: Container(
                width: size.width,
                height: ovalH,
                decoration: const BoxDecoration(
                  color: _ovalBg,                 // grey — fills the screen
                  borderRadius: BorderRadius.only(
                    bottomLeft:  Radius.elliptical(200, 60),
                    bottomRight: Radius.elliptical(200, 60),
                  ),
                ),
              ),
            ),
          ),
        ),

        // ── Layer 2: Truck slides down ─────────────────────────────────────
        SlideTransition(
          position: _truckSlide,
          child: SizedBox(
            height: ovalH,
            child: Center(
              child: SizedBox(
                width: 148,
                height: 230,
                child: CustomPaint(painter: _TruckTopPainter()),
              ),
            ),
          ),
        ),

        // ── Layer 3: Title + buttons fade out ──────────────────────────────
        FadeTransition(
          opacity: _contentFade,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.fromLTRB(28, 0, 28, 36 + bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Welcome to',
                      style: TextStyle(color: _textSec, fontSize: 17)),
                  const SizedBox(height: 2),
                  const Text('TruckCab',
                      style: TextStyle(
                          color: _textPri,
                          fontSize: 42,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -1.0)),
                  const SizedBox(height: 8),
                  const Text(
                    'Fast, reliable freight delivery —\nright at your fingertips.',
                    style: TextStyle(color: _textSec, fontSize: 14, height: 1.5),
                  ),
                  const SizedBox(height: 36),
                  _CTA(
                    label: 'Sign In',
                    filled: true,
                    onTap: () => _goTo(login: true),
                  ),
                  const SizedBox(height: 14),
                  _CTA(
                    label: 'Sign Up',
                    filled: false,
                    onTap: () => _goTo(login: false),
                  ),
                ],
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

// ── CTA button ────────────────────────────────────────────────────────────────
class _CTA extends StatelessWidget {
  final String label;
  final bool filled;
  final VoidCallback onTap;
  const _CTA({required this.label, required this.filled, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: filled ? _accent : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            border: filled
                ? null
                : Border.all(color: const Color(0xFF3A3A3A), width: 1.5),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: filled ? const Color(0xFF1A1A1A) : _textPri,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
}

// ── Top-down truck painter ────────────────────────────────────────────────────
class _TruckTopPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final bodyGreen  = Paint()..color = _accent..style = PaintingStyle.fill;
    final darkGreen  = Paint()..color = const Color(0xFF1A3A08)..style = PaintingStyle.fill;
    final midGreen   = Paint()..color = const Color(0xFF5DB020)..style = PaintingStyle.fill;
    final wheelPaint = Paint()..color = const Color(0xFF2A2A2A)..style = PaintingStyle.fill;
    final tyrePaint  = Paint()..color = const Color(0xFF1A1A1A)..style = PaintingStyle.fill;
    final linePaint  = Paint()
      ..color = const Color(0xFF4A9A10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Cargo bed
    final cargoTop  = h * 0.30;
    final cargoLeft = w * 0.03;
    final cargoW    = w * 0.94;
    final cargoH    = h * 0.66;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(cargoLeft, cargoTop, cargoW, cargoH),
          const Radius.circular(10)),
      bodyGreen);

    // Groove lines on cargo
    canvas.drawLine(Offset(cargoLeft + 6, cargoTop + cargoH * 0.33),
        Offset(cargoLeft + cargoW - 6, cargoTop + cargoH * 0.33), linePaint);
    canvas.drawLine(Offset(cargoLeft + 6, cargoTop + cargoH * 0.66),
        Offset(cargoLeft + cargoW - 6, cargoTop + cargoH * 0.66), linePaint);
    canvas.drawLine(Offset(cargoLeft + cargoW * 0.5, cargoTop + 6),
        Offset(cargoLeft + cargoW * 0.5, cargoTop + cargoH - 6), linePaint);

    // Cab
    final cabLeft = w * 0.10;
    final cabW    = w * 0.80;
    final cabH    = h * 0.30;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(cabLeft, 0, cabW, cabH), const Radius.circular(14)),
      bodyGreen);

    // Connector strip
    canvas.drawRect(Rect.fromLTWH(cargoLeft, cargoTop - 4, cargoW, 8), midGreen);

    // Windshield
    final wsLeft = cabLeft + cabW * 0.12;
    final wsW    = cabW * 0.76;
    final wsTop  = cabH * 0.12;
    final wsH    = cabH * 0.55;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(wsLeft, wsTop, wsW, wsH), const Radius.circular(8)),
      darkGreen);

    // Glass glare
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(wsLeft + 4, wsTop + 4, wsW * 0.38, wsH * 0.4),
          const Radius.circular(4)),
      Paint()..color = Colors.white.withOpacity(0.08));

    // Headlights
    final hlPaint = Paint()
      ..color = const Color(0xFFFFFF88).withOpacity(0.7);
    final hlW = cabW * 0.14;
    final hlH = cabH * 0.22;
    final hlY = wsTop + wsH * 0.1;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(cabLeft + 6, hlY, hlW, hlH), const Radius.circular(5)),
      hlPaint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(cabLeft + cabW - hlW - 6, hlY, hlW, hlH),
          const Radius.circular(5)),
      hlPaint);

    // Side mirrors
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(cabLeft - 12, hlY + 4, 10, 6), const Radius.circular(2)),
      bodyGreen);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(cabLeft + cabW + 2, hlY + 4, 10, 6),
          const Radius.circular(2)),
      bodyGreen);

    // Wheels helper
    void drawWheel(double x, double y) {
      const wW = 14.0, wH = 28.0;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(x - 1, y - 1, wW + 2, wH + 2),
            const Radius.circular(6)),
        tyrePaint);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(x, y, wW, wH), const Radius.circular(5)),
        wheelPaint);
      final lugPaint = Paint()
        ..color = const Color(0xFF4A4A4A)
        ..style = PaintingStyle.fill;
      final cx = x + wW / 2, cy = y + wH / 2;
      for (int i = 0; i < 4; i++) {
        final angle = i * math.pi / 2 + math.pi / 4;
        canvas.drawCircle(
            Offset(cx + math.cos(angle) * 4.5, cy + math.sin(angle) * 4.5),
            1.8, lugPaint);
      }
    }

    // Front axle
    drawWheel(-12, cabH * 0.08);
    drawWheel(w - 2, cabH * 0.08);
    // Rear axle 1
    drawWheel(-12, cargoTop + cargoH * 0.52);
    drawWheel(w - 2, cargoTop + cargoH * 0.52);
    // Rear axle 2 (tandem)
    drawWheel(-12, cargoTop + cargoH * 0.72);
    drawWheel(w - 2, cargoTop + cargoH * 0.72);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

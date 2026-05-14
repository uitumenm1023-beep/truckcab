import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_roles.dart';
import '../../routes/app_routes.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _ac;
  late final Animation<double>   _scale;
  late final Animation<double>   _fade;

  @override
  void initState() {
    super.initState();
    _ac    = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _scale = CurvedAnimation(parent: _ac, curve: Curves.elasticOut);
    _fade  = CurvedAnimation(parent: _ac, curve: Curves.easeIn);
    _ac.forward();
    _checkAuth();
  }

  @override
  void dispose() { _ac.dispose(); super.dispose(); }

  Future<void> _checkAuth() async {
    await Future.delayed(const Duration(milliseconds: 1800));
    if (!mounted) return;

    // Reload user to get fresh emailVerified status
    try {
      await FirebaseAuth.instance.currentUser?.reload();
    } catch (_) {}

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, AppRoutes.login);
      return;
    }

    // If email not verified, send back to login
    if (!user.emailVerified) {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, AppRoutes.login);
      return;
    }

    // Fetch role + subscription from Firestore
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (!mounted) return;
      if (!doc.exists) {
        Navigator.pushReplacementNamed(context, AppRoutes.login);
        return;
      }
      final data = doc.data() ?? {};
      final role    = ((data['role'] ?? '') as String).trim().toLowerCase();
      final isAdmin = data['isAdmin'] == true;

      // Subscription check
      bool subscribed = isAdmin; // admin always has access
      if (!subscribed) {
        final expTs = data['subscriptionExpiry'];
        if (expTs is Timestamp) {
          subscribed = expTs.toDate().isAfter(DateTime.now());
        }
      }

      if (!subscribed) {
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, AppRoutes.subscription);
        return;
      }

      if (role == AppRoles.seller) {
        Navigator.pushReplacementNamed(context, AppRoutes.sellerHome);
      } else if (role == AppRoles.driver) {
        Navigator.pushReplacementNamed(context, AppRoutes.driverHome);
      } else {
        Navigator.pushReplacementNamed(context, AppRoutes.login);
      }
    } catch (_) {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: dark ? const Color(0xFF1E1E1E) : const Color(0xFFF2F3F8),
      body: Center(
        child: FadeTransition(
          opacity: _fade,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ScaleTransition(
              scale: _scale,
              child: Container(
                width: 100, height: 100,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [Color(0xFF89F336), Color(0xFF5B4CD6)]),
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: const Color(0xFF89F336).withOpacity(0.4), blurRadius: 32, offset: const Offset(0, 12))]),
                child: const Icon(Icons.local_shipping_rounded, color: Colors.white, size: 46)),
            ),
            const SizedBox(height: 24),
            Text('TruckCab',
              style: TextStyle(
                color: dark ? const Color(0xFFF5F7FA) : const Color(0xFF4A4A4A),
                fontSize: 34, fontWeight: FontWeight.w300, letterSpacing: 1.5)),
            const SizedBox(height: 6),
            Text('Delivering On Time',
              style: TextStyle(color: dark ? const Color(0xFF98A1AE) : const Color(0xFF6B7280), fontSize: 14)),
            const SizedBox(height: 48),
            SizedBox(width: 28, height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: const Color(0xFF89F336).withOpacity(0.6))),
          ]),
        ),
      ),
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../routes/app_routes.dart';
import '../../core/constants/app_roles.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _checkAuthState();
  }

  Future<void> _checkAuthState() async {
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (!authProvider.isLoggedIn || authProvider.user == null) {
      Navigator.pushReplacementNamed(context, AppRoutes.login);
      return;
    }

    final userId = authProvider.user!.uid;

    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();

      if (!mounted) return;

      if (!userDoc.exists) {
        Navigator.pushReplacementNamed(context, AppRoutes.login);
        return;
      }

      final data = userDoc.data();
      final role = (data?['role'] ?? '').toString().trim().toLowerCase();

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
    return const Scaffold(
      body: Center(
        child: Text(
          'TruckCab',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../routes/app_routes.dart';

class SellerHomeScreen extends StatelessWidget {
  const SellerHomeScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    await authProvider.logout();

    if (!context.mounted) return;

    Navigator.pushReplacementNamed(context, AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Seller Dashboard"),
        actions: [
          IconButton(
            onPressed: () => _logout(context),
            icon: const Icon(Icons.logout),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.add_box),
                title: const Text("Create Delivery Order"),
                subtitle: const Text("Post a new delivery request"),
                onTap: () {
                  Navigator.pushNamed(context, AppRoutes.createOrder);
                },
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.list_alt),
                title: const Text("My Orders"),
                subtitle: const Text("View your delivery orders"),
                onTap: () {
                  Navigator.pushNamed(context, AppRoutes.sellerOrders);
                },
              ),
            ),
            const SizedBox(height: 30),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Icon(
                      Icons.local_shipping,
                      size: 60,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Logged in as: ${authProvider.currentUserEmail ?? ''}",
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
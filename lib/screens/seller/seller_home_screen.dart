import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/notification_provider.dart';
import '../../routes/app_routes.dart';

class SellerHomeScreen extends StatefulWidget {
  const SellerHomeScreen({super.key});

  @override
  State<SellerHomeScreen> createState() => _SellerHomeScreenState();
}

class _SellerHomeScreenState extends State<SellerHomeScreen> {
  String? _userId;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final authProvider = context.read<AuthProvider>();
      final notificationProvider = context.read<NotificationProvider>();
      final userId = authProvider.currentUserId;

      if (userId != null && userId.isNotEmpty) {
        _userId = userId;
        notificationProvider.startNotificationsListener(userId);
        // Start chat listener so seller's chat list populates automatically
        context.read<ChatProvider>().startChatsListener(userId);
      }
    });
  }

  @override
  void dispose() {
    try {
      context.read<NotificationProvider>().stopNotificationsListener(
        userId: _userId,
      );
      context.read<NotificationProvider>().clearNotifications();
    } catch (_) {}
    try {
      context.read<ChatProvider>().stopChatsListener();
    } catch (_) {}
    super.dispose();
  }

  Future<void> _logout(BuildContext context) async {
    final authProvider = context.read<AuthProvider>();
    final notificationProvider = context.read<NotificationProvider>();

    notificationProvider.stopNotificationsListener(userId: _userId);
    notificationProvider.clearNotifications();
    try {
      context.read<ChatProvider>().stopChatsListener();
    } catch (_) {}

    await authProvider.logout();

    if (!context.mounted) return;
    Navigator.pushReplacementNamed(context, AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final notificationProvider = context.watch<NotificationProvider>();

    final currentProfile = authProvider.currentUserProfile;
    final isOnline = currentProfile?.isOnline ?? false;
    final role = currentProfile?.role ?? 'seller';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Seller Dashboard'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  onPressed: () {
                    Navigator.pushNamed(context, AppRoutes.notifications);
                  },
                  icon: const Icon(Icons.notifications_none),
                ),
                if (notificationProvider.unreadCount > 0)
                  Positioned(
                    right: 10,
                    top: 10,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _logout(context),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.add_box),
                title: const Text('Create Delivery Order'),
                subtitle: const Text('Post a new delivery request'),
                onTap: () {
                  Navigator.pushNamed(context, AppRoutes.createOrder);
                },
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.list_alt),
                title: const Text('My Orders'),
                subtitle: const Text('View your delivery orders'),
                onTap: () {
                  Navigator.pushNamed(context, AppRoutes.sellerOrders);
                },
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.mark_chat_unread_outlined),
                title: const Text('Chat Requests'),
                subtitle: const Text('Accept or reject driver chat requests'),
                onTap: () {
                  Navigator.pushNamed(context, AppRoutes.chatRequests);
                },
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.chat_bubble_outline),
                title: const Text('Chats'),
                subtitle: const Text('Open accepted conversations'),
                onTap: () {
                  Navigator.pushNamed(context, AppRoutes.chatList);
                },
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.notifications_active_outlined),
                title: const Text('Notifications'),
                subtitle: Text(
                  notificationProvider.unreadCount > 0
                      ? '${notificationProvider.unreadCount} unread notification(s)'
                      : 'View order updates',
                ),
                trailing: notificationProvider.unreadCount > 0
                    ? Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      )
                    : null,
                onTap: () {
                  Navigator.pushNamed(context, AppRoutes.notifications);
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
                      'Logged in as: ${authProvider.currentUserEmail ?? ''}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF252A33),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: isOnline ? Colors.green : Colors.grey,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            isOnline ? 'Active now' : 'Offline',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '(${role.toUpperCase()})',
                            style: const TextStyle(
                              color: Color(0xFF98A1AE),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/notification_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
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
        // FIX: startNotificationsListener is idempotent now — if SellerHomeScreen
        // already started it for this user, this is a no-op. No duplicate
        // subscriptions are created.
        notificationProvider.startNotificationsListener(userId);
      }
    });
  }

  @override
  void dispose() {
    // FIX: DO NOT stop the listener here. NotificationScreen is a child screen
    // that navigates on top of SellerHomeScreen. Stopping the listener on
    // dispose was killing the subscription that SellerHomeScreen owns,
    // which caused notifications to stop updating after visiting this screen.
    //
    // The listener is owned by SellerHomeScreen and will be stopped when
    // SellerHomeScreen itself is disposed (on logout).
    super.dispose();
  }

  Future<void> _markAllAsRead(BuildContext context) async {
    final notificationProvider = context.read<NotificationProvider>();

    if (_userId == null || _userId!.isEmpty) return;

    await notificationProvider.markAllNotificationsAsRead(_userId!);
  }

  Future<void> _openNotification(
    BuildContext context,
    NotificationModel notification,
  ) async {
    final notificationProvider = context.read<NotificationProvider>();

    if (!notification.isRead) {
      await notificationProvider.markNotificationAsRead(notification.id);
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(notification.message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notificationProvider = context.watch<NotificationProvider>();
    final notifications = notificationProvider.notifications;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (notifications.isNotEmpty)
            TextButton(
              onPressed: () => _markAllAsRead(context),
              child: const Text('Read all'),
            ),
        ],
      ),
      body: notificationProvider.isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : notificationProvider.errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      notificationProvider.errorMessage!,
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : notifications.isEmpty
                  ? const Center(
                      child: Text('No notifications yet'),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: notifications.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final notification = notifications[index];

                        return Material(
                          color: notification.isRead
                              ? Colors.white
                              : Colors.red.shade50,
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () =>
                                _openNotification(context, notification),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: notification.isRead
                                      ? Colors.grey.shade300
                                      : Colors.red.shade200,
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Stack(
                                    children: [
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: notification.isRead
                                              ? Colors.grey.shade200
                                              : Colors.red.shade100,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          _iconForType(notification.type),
                                        ),
                                      ),
                                      if (!notification.isRead)
                                        Positioned(
                                          right: 2,
                                          top: 2,
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
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          notification.title,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: notification.isRead
                                                ? FontWeight.w600
                                                : FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          notification.message,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            height: 1.35,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          _formatDate(notification.createdAt),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
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
                      },
                    ),
    );
  }

  static IconData _iconForType(String type) {
    switch (type) {
      case 'chat_request':
        return Icons.mark_chat_unread_outlined;
      case 'chat_accepted':
        return Icons.chat_bubble_outline;
      case 'chat_message':
        return Icons.message_outlined;
      case 'delivery_approved':
        return Icons.check_circle_outline;
      case 'package_picked_up':
        return Icons.inventory_2_outlined;
      case 'driver_on_the_way':
        return Icons.local_shipping_outlined;
      case 'package_delivered':
        return Icons.done_all;
      default:
        return Icons.notifications_active_outlined;
    }
  }

  static String _formatDate(DateTime? dateTime) {
    if (dateTime == null) return 'Just now';

    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) return 'Just now';
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minute(s) ago';
    }
    if (difference.inHours < 24) return '${difference.inHours} hour(s) ago';
    if (difference.inDays < 7) return '${difference.inDays} day(s) ago';

    return '${dateTime.year}-${_two(dateTime.month)}-${_two(dateTime.day)} '
        '${_two(dateTime.hour)}:${_two(dateTime.minute)}';
  }

  static String _two(int value) => value.toString().padLeft(2, '0');
}
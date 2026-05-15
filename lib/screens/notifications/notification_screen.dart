import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/notification_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../../routes/app_routes.dart';

bool _isDark(BuildContext ctx) => Theme.of(ctx).brightness == Brightness.dark;
Color _accent(BuildContext ctx) => _isDark(ctx) ? const Color(0xFF89F336) : const Color(0xFF4F7C82);
Color _textPri(BuildContext ctx) =>
    _isDark(ctx) ? const Color(0xFFF5F7FA) : const Color(0xFF1A2B2D);
Color _textSec(BuildContext ctx) =>
    _isDark(ctx) ? const Color(0xFF98A1AE) : const Color(0xFF2A4A50);
Color _card(BuildContext ctx) =>
    _isDark(ctx) ? const Color(0xFF2C2C2C) : const Color(0xFFB5CDD0);
Color _unreadBg(BuildContext ctx) =>
    _isDark(ctx) ? const Color(0xFF252525) : const Color(0xFFF5F3FF);
Color _border(BuildContext ctx) =>
    _isDark(ctx) ? const Color(0x14B5CDD0) : const Color(0xFF5E8A8F);


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
      final userId = context.read<AppAuthProvider>().currentUserId;
      if (userId != null && userId.isNotEmpty) {
        _userId = userId;
        context.read<NotificationProvider>().startNotificationsListener(userId);
      }
    });
  }

  @override
  void dispose() {
    // Don't stop listener here — home screens own it.
    // Just cancel if we started an extra one.
    super.dispose();
  }

  Future<void> _markAllAsRead() async {
    if (_userId == null) return;
    await context.read<NotificationProvider>().markAllNotificationsAsRead(_userId!);
  }

  Future<void> _openNotification(NotificationModel n) async {
    if (!n.isRead) {
      await context.read<NotificationProvider>().markNotificationAsRead(n.id);
    }
    if (!mounted) return;

    // Navigate based on type
    switch (n.type) {
      case 'chat_request':
        // Seller goes to delivery requests screen (chat not yet open)
        Navigator.pushNamed(context, AppRoutes.chatRequests);
        break;
      case 'chat_message':
      case 'chat_accepted':
        if (n.chatId.isNotEmpty) {
          Navigator.pushNamed(
            context,
            AppRoutes.chatScreen,
            arguments: ChatScreenArgs(chatId: n.chatId, title: n.title),
          );
        }
        break;
      default:
        // For order updates just show the message, user can navigate from home
        break;
    }
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'package_delivered':
      case 'delivery_approved': return Icons.check_circle_rounded;
      case 'chat_request':     return Icons.local_shipping_outlined;
      case 'chat_accepted':    return Icons.mark_chat_unread_outlined;
      case 'chat_message':     return Icons.chat_bubble_rounded;
      case 'package_picked_up': return Icons.inventory_2_rounded;
      case 'driver_on_the_way': return Icons.local_shipping_rounded;
      default:                 return Icons.notifications_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifProvider = context.watch<NotificationProvider>();
    final notifications = notifProvider.notifications;
    final dark = _isDark(context);
    final accent = _accent(context);

    return Scaffold(
      backgroundColor: dark ? const Color(0xFF1E1E1E) : const Color(0xFF93B1B5),
      appBar: AppBar(
        title: Text('Notifications',
          style: TextStyle(color: _textPri(context), fontWeight: FontWeight.w700, fontSize: 22)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: _textPri(context)),
        actions: [
          if (notifications.any((n) => !n.isRead))
            TextButton(
              onPressed: _markAllAsRead,
              child: Text('Mark all read',
                style: TextStyle(color: accent, fontWeight: FontWeight.w600, fontSize: 13)),
            ),
        ],
      ),
      body: notifProvider.isLoading
          ? Center(child: CircularProgressIndicator(color: accent))
          : notifProvider.errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(notifProvider.errorMessage!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _textSec(context))),
                  ))
              : notifications.isEmpty
                  ? Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.notifications_none_rounded,
                          color: _textSec(context), size: 56),
                        const SizedBox(height: 12),
                        Text('No notifications yet',
                          style: TextStyle(color: _textSec(context), fontSize: 15)),
                      ]))
                  : ListView.separated(
                      padding: EdgeInsets.fromLTRB(
                        16, 8, 16, 16 + MediaQuery.of(context).padding.bottom),
                      itemCount: notifications.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (ctx, i) {
                        final n = notifications[i];
                        final c = _accent(ctx);
                        final isRequest = n.type == 'chat_request';
                        final isChat = n.type == 'chat_message' ||
                            n.type == 'chat_accepted';
                        final showLink = isRequest || (isChat && n.chatId.isNotEmpty);
                        return GestureDetector(
                          onTap: () => _openNotification(n),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: n.isRead ? _card(context) : _unreadBg(context),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: n.isRead
                                    ? _border(context)
                                    : c.withOpacity(0.35),
                                width: n.isRead ? 1 : 1.5,
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Icon badge
                                Stack(children: [
                                  Container(
                                    width: 46, height: 46,
                                    decoration: BoxDecoration(
                                      color: c.withOpacity(0.12),
                                      shape: BoxShape.circle),
                                    child: Icon(_iconFor(n.type), color: c, size: 20)),
                                  if (!n.isRead)
                                    Positioned(right: 2, top: 2,
                                      child: Container(width: 10, height: 10,
                                        decoration: BoxDecoration(
                                          color: c, shape: BoxShape.circle,
                                          border: Border.all(
                                            color: n.isRead ? _card(context) : _unreadBg(context),
                                            width: 2)))),
                                ]),
                                const SizedBox(width: 12),
                                Expanded(child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(children: [
                                      Expanded(child: Text(n.title,
                                        style: TextStyle(
                                          color: _textPri(context),
                                          fontSize: 14,
                                          fontWeight: n.isRead
                                              ? FontWeight.w600
                                              : FontWeight.w700),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis)),
                                      const SizedBox(width: 6),
                                      Text(_formatDate(n.createdAt),
                                        style: TextStyle(
                                          color: _textSec(context), fontSize: 11)),
                                    ]),
                                    const SizedBox(height: 4),
                                    Text(n.message,
                                      style: TextStyle(
                                        color: _textSec(context),
                                        fontSize: 13, height: 1.4),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis),
                                    if (showLink) ...[
                                      const SizedBox(height: 6),
                                      Row(children: [
                                        Icon(
                                          isRequest
                                              ? Icons.local_shipping_outlined
                                              : Icons.open_in_new_rounded,
                                          color: c, size: 12),
                                        const SizedBox(width: 4),
                                        Text(
                                          isRequest ? 'View Request' : 'Open chat',
                                          style: TextStyle(
                                            color: c, fontSize: 12,
                                            fontWeight: FontWeight.w600)),
                                      ]),
                                    ],
                                  ],
                                )),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }

  static String _formatDate(DateTime? dt) {
    if (dt == null) return 'Just now';
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

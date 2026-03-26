import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../routes/app_routes.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  // Track which chatIds are being deleted so we can hide them instantly
  // while Firestore propagates — prevents the Dismissible crash entirely
  // because we no longer use Dismissible at all.
  final Set<String> _deletingIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final authProvider = context.read<AuthProvider>();
      final chatProvider = context.read<ChatProvider>();
      final userId = authProvider.currentUserId;
      // startChatsListener is idempotent — if SellerHomeScreen or
      // DriverHomeScreen already started it for this user the call is
      // a no-op. It acts as a safe fallback when this screen is pushed
      // directly (e.g. from a notification tap).
      if (userId != null && userId.isNotEmpty) {
        chatProvider.startChatsListener(userId);
      }
    });
  }

  @override
  void dispose() {
    // Do NOT stop the chats listener here — DriverHomeScreen owns it.
    super.dispose();
  }

  Future<void> _confirmDeleteChat(
    BuildContext context,
    String chatId,
    String title,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Chat'),
        content: Text('Delete "$title"?\nAll messages will be permanently removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      // Hide immediately in UI before Firestore responds
      setState(() => _deletingIds.add(chatId));

      final chatProvider = context.read<ChatProvider>();
      final success = await chatProvider.deleteChat(chatId);

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Chat deleted')),
          );
        } else {
          // Delete failed — show item again
          setState(() => _deletingIds.remove(chatId));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to delete chat')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();
    final authProvider = context.watch<AuthProvider>();
    final currentUserId = authProvider.currentUserId ?? '';

    // Filter out any chats currently being deleted so they vanish instantly
    final visibleChats = chatProvider.chats
        .where((doc) => !_deletingIds.contains(doc.id))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
      ),
      body: chatProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : visibleChats.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat_bubble_outline, size: 60, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No chats yet', style: TextStyle(color: Colors.grey)),
                      SizedBox(height: 8),
                      Text(
                        'Long-press any chat to delete it.',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: visibleChats.length,
                  itemBuilder: (context, index) {
                    final doc = visibleChats[index];
                    final data = doc.data() as Map<String, dynamic>;

                    final sellerId = (data['sellerId'] ?? '').toString();
                    final driverId = (data['driverId'] ?? '').toString();
                    final otherUserId =
                        currentUserId == sellerId ? driverId : sellerId;

                    final orderDescription =
                        (data['orderDescription'] ?? 'Chat').toString();
                    final lastMessage = (data['lastMessage'] ?? '').toString();

                    return StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(otherUserId)
                          .snapshots(),
                      builder: (context, snapshot) {
                        final userData = snapshot.data?.data();
                        final userMap = userData is Map<String, dynamic>
                            ? userData
                            : <String, dynamic>{};

                        final otherEmail =
                            (userMap['email'] ?? 'Unknown user').toString();
                        final isOnline = userMap['isOnline'] == true;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            onTap: () {
                              Navigator.pushNamed(
                                context,
                                AppRoutes.chatScreen,
                                arguments: ChatScreenArgs(
                                  chatId: doc.id,
                                  title: orderDescription,
                                ),
                              );
                            },
                            // Long press to delete — no Dismissible needed.
                            // Dismissible + Firestore realtime streams causes
                            // a fatal crash because the stream re-emits the
                            // deleted item before Firestore confirms deletion.
                            onLongPress: () => _confirmDeleteChat(
                              context,
                              doc.id,
                              orderDescription,
                            ),
                            leading: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                const CircleAvatar(
                                  radius: 24,
                                  child: Icon(Icons.person),
                                ),
                                Positioned(
                                  right: -1,
                                  bottom: -1,
                                  child: Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: isOnline ? Colors.green : Colors.grey,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: const Color(0xFF101216),
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            title: Text(
                              orderDescription,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(
                                  otherEmail,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  lastMessage.isEmpty ? 'No messages yet' : lastMessage,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  isOnline ? Icons.circle : Icons.access_time_outlined,
                                  size: isOnline ? 12 : 18,
                                  color: isOnline ? Colors.green : Colors.grey,
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'hold to\ndelete',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 9, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
    );
  }
}
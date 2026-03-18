import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String title;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.title,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      final chatProvider = context.read<ChatProvider>();
      final authProvider = context.read<AuthProvider>();
      final currentUserId = authProvider.currentUserId;

      chatProvider.startMessagesListener(widget.chatId);

      if (currentUserId != null && currentUserId.isNotEmpty) {
        await chatProvider.markMessagesAsRead(
          chatId: widget.chatId,
          currentUserId: currentUserId,
        );
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    try {
      context.read<ChatProvider>().stopMessagesListener();
    } catch (_) {}
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    final authProvider = context.read<AuthProvider>();
    final chatProvider = context.read<ChatProvider>();
    final currentUserId = authProvider.currentUserId;

    if (currentUserId == null || currentUserId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not found')),
      );
      return;
    }

    setState(() {
      _isSending = true;
    });

    final success = await chatProvider.sendMessage(
      chatId: widget.chatId,
      senderId: currentUserId,
      text: text,
    );

    if (!mounted) return;

    setState(() {
      _isSending = false;
    });

    if (success) {
      _messageController.clear();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(chatProvider.errorMessage ?? 'Failed to send message'),
        ),
      );
    }
  }

  String _formatTime(DateTime? time) {
    if (time == null) return '';
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();
    final authProvider = context.watch<AuthProvider>();
    final currentUserId = authProvider.currentUserId ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(26),
          child: StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('chats')
                .doc(widget.chatId)
                .snapshots(),
            builder: (context, chatSnapshot) {
              final chatData = chatSnapshot.data?.data();
              final chatMap = chatData is Map<String, dynamic>
                  ? chatData
                  : <String, dynamic>{};

              final sellerId = (chatMap['sellerId'] ?? '').toString();
              final driverId = (chatMap['driverId'] ?? '').toString();
              final otherUserId =
                  currentUserId == sellerId ? driverId : sellerId;

              if (otherUserId.isEmpty) {
                return const SizedBox(height: 26);
              }

              return StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(otherUserId)
                    .snapshots(),
                builder: (context, userSnapshot) {
                  final userData = userSnapshot.data?.data();
                  final userMap = userData is Map<String, dynamic>
                      ? userData
                      : <String, dynamic>{};

                  final otherEmail =
                      (userMap['email'] ?? 'Unknown user').toString();
                  final isOnline = userMap['isOnline'] == true;
                  final lastSeenTs = userMap['lastSeen'] as Timestamp?;
                  final lastSeen = lastSeenTs?.toDate();

                  String subtitle = otherEmail;
                  if (isOnline) {
                    subtitle = '$otherEmail • Active now';
                  } else if (lastSeen != null) {
                    final hour = lastSeen.hour.toString().padLeft(2, '0');
                    final minute = lastSeen.minute.toString().padLeft(2, '0');
                    subtitle = '$otherEmail • Last seen $hour:$minute';
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: chatProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : chatProvider.messages.isEmpty
                    ? const Center(
                        child: Text('No messages yet'),
                      )
                    : ListView.builder(
                        reverse: true,
                        padding: const EdgeInsets.all(16),
                        itemCount: chatProvider.messages.length,
                        itemBuilder: (context, index) {
                          final doc = chatProvider.messages[index];
                          final data = doc.data() as Map<String, dynamic>;

                          final senderId = (data['senderId'] ?? '').toString();
                          final text = (data['text'] ?? '').toString();
                          final isMine = senderId == currentUserId;
                          final timestamp = data['createdAt'] as Timestamp?;
                          final createdAt = timestamp?.toDate();

                          return Align(
                            alignment: isMine
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.of(context).size.width * 0.75,
                              ),
                              decoration: BoxDecoration(
                                color: isMine
                                    ? const Color(0xFFFF5A1F)
                                    : const Color(0xFF252A33),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                crossAxisAlignment: isMine
                                    ? CrossAxisAlignment.end
                                    : CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    text,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatTime(createdAt),
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      minLines: 1,
                      maxLines: 5,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        filled: true,
                        fillColor: const Color(0xFF252A33),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 50,
                    width: 50,
                    child: ElevatedButton(
                      onPressed: _isSending ? null : _sendMessage,
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isSending
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send_rounded),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
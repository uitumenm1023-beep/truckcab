import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../routes/app_routes.dart';

bool _isDark(BuildContext ctx) => Theme.of(ctx).brightness == Brightness.dark;
Color _accent(BuildContext ctx) => _isDark(ctx) ? const Color(0xFF89F336) : const Color(0xFF4F7C82);
Color _textPri(BuildContext ctx) => _isDark(ctx) ? const Color(0xFFF5F7FA) : const Color(0xFF1A2B2D);
Color _textSec(BuildContext ctx) => _isDark(ctx) ? const Color(0xFF98A1AE) : const Color(0xFF2A4A50);
Color _soft(BuildContext ctx)    => _isDark(ctx) ? const Color(0xFF3A3A3A) : const Color(0xFF7FA3A7);
Color _card(BuildContext ctx)    => _isDark(ctx) ? const Color(0xFF2C2C2C) : const Color(0xFFB5CDD0);
Color _bg(BuildContext ctx)      => _isDark(ctx) ? const Color(0xFF1E1E1E) : const Color(0xFF93B1B5);
Color _border(BuildContext ctx)  => _isDark(ctx) ? const Color(0x14B5CDD0) : const Color(0xFF5E8A8F);


class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});
  @override State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final uid = context.read<AppAuthProvider>().currentUserId;
      if (uid != null && uid.isNotEmpty) context.read<ChatProvider>().startChatsListener(uid);
    });
  }

  @override
  void dispose() {
    try { context.read<ChatProvider>().stopChatsListener(); } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent  = _accent(context);
    final chat    = context.watch<ChatProvider>();
    final uid     = context.watch<AppAuthProvider>().currentUserId ?? '';

    return Scaffold(
      backgroundColor: _bg(context),
      appBar: AppBar(
        backgroundColor: _card(context),
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: _soft(context), borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.arrow_back_ios_new_rounded, color: _textPri(context), size: 16)),
        ),
        title: Text('Chats', style: TextStyle(color: _textPri(context), fontSize: 20, fontWeight: FontWeight.w700)),
      ),
      body: chat.isLoading
          ? Center(child: CircularProgressIndicator(color: accent))
          : chat.chats.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.chat_bubble_outline, color: _textSec(context), size: 48),
                  const SizedBox(height: 12),
                  Text('No chats yet', style: TextStyle(color: _textSec(context), fontSize: 15)),
                ]))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: chat.chats.length,
                  itemBuilder: (ctx, i) {
                    final doc    = chat.chats[i];
                    final data   = doc.data() as Map<String, dynamic>;
                    final seller = (data['sellerId'] ?? '').toString();
                    final driver = (data['driverId'] ?? '').toString();
                    final other  = uid == seller ? driver : seller;
                    final desc   = (data['orderDescription'] ?? 'Chat').toString();
                    final last   = (data['lastMessage'] ?? '').toString();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _ChatTile(chatId: doc.id, otherUserId: other, description: desc, lastMessage: last),
                    );
                  },
                ),
    );
  }
}

class _ChatTile extends StatelessWidget {
  final String chatId, otherUserId, description, lastMessage;
  const _ChatTile({required this.chatId, required this.otherUserId, required this.description, required this.lastMessage});

  @override
  Widget build(BuildContext context) {
    final accent = _accent(context);
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(otherUserId).snapshots(),
      builder: (ctx, snap) {
        final ud   = snap.data?.data();
        final um   = ud is Map<String, dynamic> ? ud : <String, dynamic>{};
        final name = (um['name'] ?? um['email'] ?? 'User').toString();
        final isOnline = um['isOnline'] == true;
        return GestureDetector(
          onTap: () => Navigator.pushNamed(context, AppRoutes.chatScreen,
            arguments: ChatScreenArgs(chatId: chatId, title: description)),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: _card(context), borderRadius: BorderRadius.circular(18), border: Border.all(color: _border(context))),
            child: Row(children: [
              Stack(clipBehavior: Clip.none, children: [
                Container(width: 50, height: 50, decoration: BoxDecoration(color: _soft(context), shape: BoxShape.circle),
                  child: Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'U',
                    style: TextStyle(color: _textPri(context), fontWeight: FontWeight.w700, fontSize: 20)))),
                Positioned(right: 0, bottom: 0,
                  child: Container(width: 13, height: 13,
                    decoration: BoxDecoration(color: isOnline ? accent : const Color(0xFF9CA3AF),
                      shape: BoxShape.circle, border: Border.all(color: _card(context), width: 2)))),
              ]),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(description, style: TextStyle(color: _textPri(context), fontWeight: FontWeight.w700, fontSize: 14),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Text(lastMessage.isEmpty ? 'No messages yet' : lastMessage,
                  style: TextStyle(color: _textSec(context), fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
              ])),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: accent, size: 20),
            ]),
          ),
        );
      },
    );
  }
}

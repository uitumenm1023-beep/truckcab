import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';

bool _isDark(BuildContext ctx) => Theme.of(ctx).brightness == Brightness.dark;
Color _textPri(BuildContext ctx) => _isDark(ctx) ? const Color(0xFFF5F7FA) : const Color(0xFF1A2B2D);
Color _textSec(BuildContext ctx) => _isDark(ctx) ? const Color(0xFF98A1AE) : const Color(0xFF2A4A50);
Color _soft(BuildContext ctx)    => _isDark(ctx) ? const Color(0xFF3A3A3A) : const Color(0xFF7FA3A7);
Color _card(BuildContext ctx)    => _isDark(ctx) ? const Color(0xFF2C2C2C) : const Color(0xFFB5CDD0);
Color _bg(BuildContext ctx)      => _isDark(ctx) ? const Color(0xFF1E1E1E) : const Color(0xFF93B1B5);
Color _border(BuildContext ctx)  => _isDark(ctx) ? const Color(0x14B5CDD0) : const Color(0xFF5E8A8F);

const Color _purple = Color(0xFF89F336);
const Color _orange = Color(0xFF89F336);
const Color _green  = Color(0xFF89F336);

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String title;

  const ChatScreen({super.key, required this.chatId, required this.title});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _ctrl = TextEditingController();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final chat = context.read<ChatProvider>();
      final auth = context.read<AppAuthProvider>();
      chat.startMessagesListener(widget.chatId);
      final uid = auth.currentUserId;
      if (uid != null && uid.isNotEmpty) {
        await chat.markMessagesAsRead(chatId: widget.chatId, currentUserId: uid);
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    try { context.read<ChatProvider>().stopMessagesListener(); } catch (_) {}
    super.dispose();
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _isSending) return;
    final uid = context.read<AppAuthProvider>().currentUserId;
    if (uid == null || uid.isEmpty) return;

    setState(() => _isSending = true);
    final ok = await context.read<ChatProvider>().sendMessage(
      chatId: widget.chatId, senderId: uid, text: text,
    );
    if (!mounted) return;
    setState(() => _isSending = false);
    if (ok) _ctrl.clear();
  }

  Future<void> _finalApprove(Map<String, dynamic> requestData) async {
    final chat = context.read<ChatProvider>();
    final ok = await chat.confirmDriverForDelivery(
      requestId: widget.chatId, requestData: requestData,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? 'Driver approved for delivery!' : (chat.errorMessage ?? 'Failed')),
      backgroundColor: ok ? _green : Colors.redAccent,
    ));
  }

  String _formatTime(DateTime? t) {
    if (t == null) return '';
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final chat   = context.watch<ChatProvider>();
    final auth   = context.watch<AppAuthProvider>();
    final uid    = auth.currentUserId ?? '';
    final dark   = _isDark(context);

    return Scaffold(
      backgroundColor: _bg(context),
      appBar: AppBar(
        backgroundColor: _card(context),
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: _soft(context), borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.arrow_back_ios_new_rounded, color: _textPri(context), size: 16),
          ),
        ),
        title: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('chats').doc(widget.chatId).snapshots(),
          builder: (ctx, chatSnap) {
            final chatData = chatSnap.data?.data();
            final chatMap  = chatData is Map<String, dynamic> ? chatData : <String, dynamic>{};
            final sellerId = (chatMap['sellerId'] ?? '').toString();
            final driverId = (chatMap['driverId'] ?? '').toString();
            final otherId  = uid == sellerId ? driverId : sellerId;
            if (otherId.isEmpty) return Text(widget.title, style: TextStyle(color: _textPri(context), fontSize: 16, fontWeight: FontWeight.w700));
            return StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('users').doc(otherId).snapshots(),
              builder: (ctx2, userSnap) {
                final ud = userSnap.data?.data();
                final um = ud is Map<String, dynamic> ? ud : <String, dynamic>{};
                final name = (um['name'] ?? um['email'] ?? 'User').toString();
                final isOnline = um['isOnline'] == true;
                return Row(children: [
                  Container(width: 36, height: 36, decoration: BoxDecoration(color: _purple.withOpacity(0.15), shape: BoxShape.circle),
                    child: Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'U',
                      style: const TextStyle(color: _purple, fontWeight: FontWeight.w700, fontSize: 14)))),
                  const SizedBox(width: 10),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(name, style: TextStyle(color: _textPri(context), fontSize: 14, fontWeight: FontWeight.w700)),
                    Text(isOnline ? 'Online' : 'Offline', style: TextStyle(color: isOnline ? _green : _textSec(context), fontSize: 11)),
                  ]),
                ]);
              },
            );
          },
        ),
      ),
      body: Column(children: [
        // Seller-only: accept delivery button
        StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('chats').doc(widget.chatId).snapshots(),
          builder: (ctx, cs) {
            final cd  = cs.data?.data();
            final cm  = cd is Map<String, dynamic> ? cd : <String, dynamic>{};
            final isSeller = uid == (cm['sellerId'] ?? '').toString();
            if (!isSeller) return const SizedBox.shrink();
            return StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('chat_requests').doc(widget.chatId).snapshots(),
              builder: (ctx2, rs) {
                final rd = rs.data?.data();
                final rm = rd is Map<String, dynamic> ? rd : <String, dynamic>{};
                final status = (rm['status'] ?? '').toString();
                if (status == 'approved' || status == 'rejected') return const SizedBox.shrink();
                return Container(
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: dark ? const Color(0xFF252525) : const Color(0xFFE5FFD0),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: _purple.withOpacity(0.25)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.verified_outlined, color: _purple, size: 20),
                    const SizedBox(width: 10),
                    Expanded(child: Text('Ready to approve this driver for delivery?',
                      style: TextStyle(color: _textPri(context), fontSize: 13))),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () => _finalApprove(rm),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(color: _purple, borderRadius: BorderRadius.circular(12)),
                        child: const Text('Approve', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12))),
                    ),
                  ]),
                );
              },
            );
          },
        ),
        // Messages
        Expanded(
          child: chat.isLoading
              ? const Center(child: CircularProgressIndicator(color: _purple))
              : chat.messages.isEmpty
                  ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.chat_bubble_outline, color: _textSec(context), size: 40),
                      const SizedBox(height: 10),
                      Text('No messages yet', style: TextStyle(color: _textSec(context), fontSize: 14)),
                    ]))
                  : ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      itemCount: chat.messages.length,
                      itemBuilder: (ctx, i) {
                        final doc    = chat.messages[i];
                        final data   = doc.data() as Map<String, dynamic>;
                        final sender = (data['senderId'] ?? '').toString();
                        final text   = (data['text'] ?? '').toString();
                        final isMine = sender == uid;
                        final ts     = data['createdAt'] as Timestamp?;
                        final time   = _formatTime(ts?.toDate());
                        return Align(
                          alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
                            decoration: BoxDecoration(
                              color: isMine ? _purple : _card(context),
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(18),
                                topRight: const Radius.circular(18),
                                bottomLeft: Radius.circular(isMine ? 18 : 4),
                                bottomRight: Radius.circular(isMine ? 4 : 18),
                              ),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(dark ? 0.2 : 0.06), blurRadius: 8, offset: const Offset(0, 2))],
                            ),
                            child: Column(
                              crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                              children: [
                                Text(text, style: TextStyle(color: isMine ? Colors.white : _textPri(context), fontSize: 14, height: 1.4)),
                                const SizedBox(height: 4),
                                Text(time, style: TextStyle(color: isMine ? Colors.white60 : _textSec(context), fontSize: 10)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
        // Input bar
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            decoration: BoxDecoration(
              color: _card(context),
              border: Border(top: BorderSide(color: _border(context))),
            ),
            child: Row(children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(color: _soft(context), borderRadius: BorderRadius.circular(20)),
                  child: TextField(
                    controller: _ctrl,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    style: TextStyle(color: _textPri(context), fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle: TextStyle(color: _textSec(context), fontSize: 14),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _isSending ? null : _send,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: _isSending ? _purple.withOpacity(0.5) : _purple,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: _purple.withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 4))],
                  ),
                  child: _isSending
                      ? const Padding(padding: EdgeInsets.all(14),
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

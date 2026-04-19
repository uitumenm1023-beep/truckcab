import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../routes/app_routes.dart';

bool _isDark(BuildContext ctx) => Theme.of(ctx).brightness == Brightness.dark;
Color _textPri(BuildContext ctx) => _isDark(ctx) ? const Color(0xFFF5F7FA) : const Color(0xFF1A1A2E);
Color _textSec(BuildContext ctx) => _isDark(ctx) ? const Color(0xFF98A1AE) : const Color(0xFF6B7280);
Color _soft(BuildContext ctx)    => _isDark(ctx) ? const Color(0xFF252A33) : const Color(0xFFF0F1F8);
Color _card(BuildContext ctx)    => _isDark(ctx) ? const Color(0xFF1B1F26) : const Color(0xFFFFFFFF);
Color _bg(BuildContext ctx)      => _isDark(ctx) ? const Color(0xFF101216) : const Color(0xFFF2F3F8);
Color _border(BuildContext ctx)  => _isDark(ctx) ? const Color(0x14FFFFFF) : const Color(0xFFE5E7EB);

const Color _purple = Color(0xFF7B6CF6);
const Color _orange = Color(0xFFFF5A1F);
const Color _green  = Color(0xFF22C55E);

class ChatRequestsScreen extends StatefulWidget {
  const ChatRequestsScreen({super.key});
  @override State<ChatRequestsScreen> createState() => _ChatRequestsScreenState();
}

class _ChatRequestsScreenState extends State<ChatRequestsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final uid = context.read<AppAuthProvider>().currentUserId;
      if (uid != null && uid.isNotEmpty) context.read<ChatProvider>().startSellerChatRequestsListener(uid);
    });
  }

  @override
  void dispose() {
    try { context.read<ChatProvider>().stopSellerChatRequestsListener(); } catch (_) {}
    super.dispose();
  }

  Future<void> _openChat(String requestId, Map<String, dynamic> data) async {
    final chat = context.read<ChatProvider>();
    final ok = await chat.acceptChatRequest(requestId: requestId, requestData: data);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chat opened! Talk before final approval.')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(chat.errorMessage ?? 'Failed to open chat')));
    }
  }

  Future<void> _finalApprove(String requestId, Map<String, dynamic> data) async {
    final chat = context.read<ChatProvider>();
    final ok = await chat.confirmDriverForDelivery(requestId: requestId, requestData: data);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? 'Driver approved for delivery!' : (chat.errorMessage ?? 'Failed')),
      backgroundColor: ok ? _green : Colors.redAccent,
    ));
  }

  Future<void> _reject(String requestId) async {
    final chat = context.read<ChatProvider>();
    final ok = await chat.rejectChatRequest(requestId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'Request rejected' : 'Failed to reject')));
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatProvider>();

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
        title: Text('Delivery Requests', style: TextStyle(color: _textPri(context), fontSize: 20, fontWeight: FontWeight.w700)),
      ),
      body: chat.isLoading
          ? const Center(child: CircularProgressIndicator(color: _purple))
          : chat.chatRequests.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.inbox_outlined, color: _textSec(context), size: 48),
                  const SizedBox(height: 12),
                  Text('No delivery requests', style: TextStyle(color: _textSec(context), fontSize: 15)),
                ]))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: chat.chatRequests.length,
                  itemBuilder: (ctx, i) {
                    final doc    = chat.chatRequests[i];
                    final data   = doc.data() as Map<String, dynamic>;
                    final desc   = (data['orderDescription'] ?? 'Delivery').toString();
                    final pickup = (data['pickupLocation'] ?? '').toString();
                    final drop   = (data['dropoffLocation'] ?? '').toString();
                    final status = (data['status'] ?? '').toString();

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(color: _card(context), borderRadius: BorderRadius.circular(22), border: Border.all(color: _border(context))),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Expanded(child: Text(desc,
                              style: TextStyle(color: _textPri(context), fontWeight: FontWeight.w700, fontSize: 15),
                              maxLines: 1, overflow: TextOverflow.ellipsis)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: status == 'pending' ? _orange.withOpacity(0.12) : _purple.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(10)),
                              child: Text(status == 'pending' ? 'Pending' : 'Chat Open',
                                style: TextStyle(color: status == 'pending' ? _orange : _purple,
                                  fontSize: 11, fontWeight: FontWeight.w700))),
                          ]),
                          const SizedBox(height: 12),
                          _InfoRow(Icons.my_location_outlined, pickup, context),
                          const SizedBox(height: 6),
                          _InfoRow(Icons.flag_outlined, drop, context),
                          const SizedBox(height: 6),
                          if (status == 'pending')
                            Text('Step 1: Accept to open chat with driver', style: TextStyle(color: _textSec(context), fontSize: 11))
                          else if (status == 'chat_open')
                            Text('Step 2: Chat, then approve for final delivery', style: TextStyle(color: _textSec(context), fontSize: 11)),
                          const SizedBox(height: 14),
                          if (status == 'pending') ...[
                            Row(children: [
                              Expanded(child: _Btn('Accept & Chat', _purple, () => _openChat(doc.id, data))),
                              const SizedBox(width: 10),
                              Expanded(child: _OutlineBtn('Reject', Colors.redAccent, () => _reject(doc.id))),
                            ]),
                          ] else if (status == 'chat_open') ...[
                            Row(children: [
                              Expanded(child: _Btn('Final Approve', _green, () => _finalApprove(doc.id, data))),
                              const SizedBox(width: 10),
                              Expanded(child: _OutlineBtn('Open Chat', _purple, () {
                                Navigator.pushNamed(context, AppRoutes.chatScreen,
                                  arguments: ChatScreenArgs(chatId: doc.id, title: desc));
                              })),
                            ]),
                          ],
                        ]),
                      ),
                    );
                  },
                ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final BuildContext context;
  const _InfoRow(this.icon, this.text, this.context);

  @override
  Widget build(BuildContext ctx) => Row(children: [
    Icon(icon, color: _textSec(context), size: 14),
    const SizedBox(width: 6),
    Expanded(child: Text(text, style: TextStyle(color: _textSec(context), fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis)),
  ]);
}

class _Btn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _Btn(this.label, this.color, this.onTap);

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(height: 44, alignment: Alignment.center,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))]),
      child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13))),
  );
}

class _OutlineBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _OutlineBtn(this.label, this.color, this.onTap);

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(height: 44, alignment: Alignment.center,
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.4))),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13))),
  );
}

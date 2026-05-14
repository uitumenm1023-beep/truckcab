import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_status.dart';
import '../../models/order_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/order_provider.dart';
import '../../routes/app_routes.dart';

bool _isDark(BuildContext ctx) => Theme.of(ctx).brightness == Brightness.dark;
Color _textPri(BuildContext ctx) => _isDark(ctx) ? const Color(0xFFF5F7FA) : const Color(0xFF4A4A4A);
Color _textSec(BuildContext ctx) => _isDark(ctx) ? const Color(0xFF98A1AE) : const Color(0xFF6B7280);
Color _soft(BuildContext ctx)    => _isDark(ctx) ? const Color(0xFF3A3A3A) : const Color(0xFFF0F1F8);
Color _card(BuildContext ctx)    => _isDark(ctx) ? const Color(0xFF2C2C2C) : const Color(0xFFFFFFFF);
Color _bg(BuildContext ctx)      => _isDark(ctx) ? const Color(0xFF1E1E1E) : const Color(0xFFF2F3F8);
Color _border(BuildContext ctx)  => _isDark(ctx) ? const Color(0x14FFFFFF) : const Color(0xFFE5E7EB);

const Color _purple = Color(0xFF89F336);
const Color _orange = Color(0xFF89F336);
const Color _green  = Color(0xFF89F336);

class SellerOrdersScreen extends StatefulWidget {
  const SellerOrdersScreen({super.key});
  @override State<SellerOrdersScreen> createState() => _SellerOrdersScreenState();
}

class _SellerOrdersScreenState extends State<SellerOrdersScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      final uid = context.read<AppAuthProvider>().currentUserId;
      if (uid != null && uid.isNotEmpty) context.read<OrderProvider>().startSellerOrdersListener(sellerId: uid);
    });
  }

  @override
  void dispose() {
    try { context.read<OrderProvider>().stopSellerOrdersListener(); } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final orders = context.watch<OrderProvider>();

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
        title: Text('My Orders', style: TextStyle(color: _textPri(context), fontSize: 20, fontWeight: FontWeight.w700)),
      ),
      body: orders.isLoading
          ? const Center(child: CircularProgressIndicator(color: _purple))
          : orders.sellerOrders.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.local_shipping_outlined, color: _textSec(context), size: 48),
                  const SizedBox(height: 12),
                  Text('No orders yet', style: TextStyle(color: _textSec(context), fontSize: 15)),
                ]))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: orders.sellerOrders.length,
                  itemBuilder: (ctx, i) {
                    final o = orders.sellerOrders[i];
                    return Padding(padding: const EdgeInsets.only(bottom: 14), child: _OrderCard(order: o));
                  },
                ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final OrderModel order;
  const _OrderCard({required this.order});

  Color _sc() {
    switch (order.status) {
      case AppStatus.open:      return const Color(0xFF6B7280);
      case AppStatus.accepted:  return _purple;
      case AppStatus.pickedUp:  return const Color(0xFF3B82F6);
      case AppStatus.onTheWay:  return _orange;
      case AppStatus.delivered: return _green;
      default: return const Color(0xFF6B7280);
    }
  }

  String _sl() {
    switch (order.status) {
      case AppStatus.open:      return 'Open';
      case AppStatus.accepted:  return 'Accepted';
      case AppStatus.pickedUp:  return 'Picked Up';
      case AppStatus.onTheWay:  return 'On The Way';
      case AppStatus.delivered: return 'Delivered ✓';
      default: return order.status;
    }
  }

  String get _chatId => '${order.id}_${order.sellerId}_${order.driverId ?? ''}';

  @override
  Widget build(BuildContext context) {
    final hasDriver = order.driverId != null && order.driverId!.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: _card(context), borderRadius: BorderRadius.circular(22), border: Border.all(color: _border(context))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(order.description,
            style: TextStyle(color: _textPri(context), fontWeight: FontWeight.w700, fontSize: 15),
            maxLines: 2, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 10),
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: _sc().withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
            child: Text(_sl(), style: TextStyle(color: _sc(), fontSize: 11, fontWeight: FontWeight.w700))),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Icon(Icons.my_location_outlined, color: _textSec(context), size: 14),
          const SizedBox(width: 6),
          Expanded(child: Text(order.pickupLocation, style: TextStyle(color: _textSec(context), fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis)),
        ]),
        const SizedBox(height: 4),
        Row(children: [
          Icon(Icons.flag_outlined, color: _textSec(context), size: 14),
          const SizedBox(width: 6),
          Expanded(child: Text(order.dropoffLocation, style: TextStyle(color: _textSec(context), fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Text('\$${order.price.toStringAsFixed(0)}',
            style: const TextStyle(color: _green, fontWeight: FontWeight.w800, fontSize: 16)),
          const Spacer(),
          Text(hasDriver ? 'Driver assigned' : 'Awaiting driver', style: TextStyle(color: _textSec(context), fontSize: 12)),
        ]),
        if (hasDriver) ...[
          const SizedBox(height: 14),
          _ChatSection(order: order, chatId: _chatId),
        ],
      ]),
    );
  }
}

class _ChatSection extends StatelessWidget {
  final OrderModel order;
  final String chatId;
  const _ChatSection({required this.order, required this.chatId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('chat_requests').doc(chatId).snapshots(),
      builder: (ctx, rs) {
        if (!rs.hasData || !rs.data!.exists) return Text('No chat request yet', style: TextStyle(color: _textSec(context), fontSize: 12));
        final rd = rs.data!.data();
        final rm = rd is Map<String, dynamic> ? rd : <String, dynamic>{};
        final status = (rm['status'] ?? '').toString();
        if (status == 'rejected') return Text('Request rejected', style: TextStyle(color: Colors.redAccent.withOpacity(0.8), fontSize: 12));
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('chats').doc(chatId).snapshots(),
          builder: (ctx2, cs) {
            if (!(cs.data?.exists ?? false)) return Text('Chat pending...', style: TextStyle(color: _textSec(context), fontSize: 12));
            return GestureDetector(
              onTap: () => Navigator.pushNamed(context, AppRoutes.chatScreen,
                arguments: ChatScreenArgs(chatId: chatId, title: order.description)),
              child: Container(height: 44, alignment: Alignment.center,
                decoration: BoxDecoration(color: _purple.withOpacity(0.1), borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _purple.withOpacity(0.3))),
                child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.chat_bubble_outline, color: _purple, size: 16),
                  SizedBox(width: 8),
                  Text('Open Chat', style: TextStyle(color: _purple, fontWeight: FontWeight.w700, fontSize: 13)),
                ])),
            );
          },
        );
      },
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_status.dart';
import '../../main.dart';
import '../../models/order_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/order_provider.dart';
import '../../routes/app_routes.dart';

bool _isDark(BuildContext ctx) => Theme.of(ctx).brightness == Brightness.dark;
Color _textPri(BuildContext ctx) => _isDark(ctx) ? const Color(0xFFF5F7FA) : const Color(0xFF1A2B2D);
Color _textSec(BuildContext ctx) => _isDark(ctx) ? const Color(0xFF98A1AE) : const Color(0xFF2A4A50);
Color _soft(BuildContext ctx)    => _isDark(ctx) ? const Color(0xFF3A3A3A) : const Color(0xFF7FA3A7);
Color _card(BuildContext ctx)    => _isDark(ctx) ? const Color(0xFF2C2C2C) : const Color(0xFFB5CDD0);
Color _border(BuildContext ctx)  => _isDark(ctx) ? const Color(0x14B5CDD0) : const Color(0xFF5E8A8F);
Color _bg(BuildContext ctx)      => _isDark(ctx) ? const Color(0xFF1E1E1E) : const Color(0xFF93B1B5);

const Color _purple     = Color(0xFF89F336);
const Color _purpleL    = Color(0xFFE5FFD0);
const Color _orange     = Color(0xFF89F336);
const Color _green      = Color(0xFF89F336);

class SellerHomeScreen extends StatefulWidget {
  const SellerHomeScreen({super.key});
  @override State<SellerHomeScreen> createState() => _SellerHomeScreenState();
}

class _SellerHomeScreenState extends State<SellerHomeScreen> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final uid = context.read<AppAuthProvider>().currentUserId;
      if (uid != null && uid.isNotEmpty) {
        context.read<NotificationProvider>().startNotificationsListener(uid);
        context.read<OrderProvider>().startSellerOrdersListener(sellerId: uid);
        context.read<ChatProvider>().startChatsListener(uid);
        context.read<ChatProvider>().startSellerChatRequestsListener(uid);
      }
    });
  }

  @override
  void dispose() {
    try {
      context.read<NotificationProvider>().stopNotificationsListener();
      context.read<OrderProvider>().stopSellerOrdersListener();
      context.read<ChatProvider>().stopChatsListener();
      context.read<ChatProvider>().stopSellerChatRequestsListener();
    } catch (_) {}
    super.dispose();
  }

  Future<void> _logout() async {
    context.read<NotificationProvider>().stopNotificationsListener();
    await context.read<AppAuthProvider>().logout();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _HomeTab(onTabChange: (i) => setState(() => _tab = i)),
      const _TrackTab(),
      const _ChatsTab(),
      _ProfileTab(onLogout: _logout),
    ];
    return Scaffold(
      backgroundColor: _bg(context),
      body: pages[_tab],
      bottomNavigationBar: _BottomNav(selected: _tab, onTap: (i) => setState(() => _tab = i)),
    );
  }
}

// ── Bottom Nav ────────────────────────────────────────────────────────────────
class _BottomNav extends StatelessWidget {
  final int selected;
  final void Function(int) onTap;
  const _BottomNav({required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dark = _isDark(context);
    final bottomPad = MediaQuery.of(context).padding.bottom;
    const items = [
      (Icons.home_rounded, Icons.home_outlined, 'Home'),
      (Icons.local_shipping_rounded, Icons.local_shipping_outlined, 'Track'),
      (Icons.chat_bubble_rounded, Icons.chat_bubble_outline, 'Chats'),
      (Icons.person_rounded, Icons.person_outline_rounded, 'Profile'),
    ];
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottomPad),
      decoration: BoxDecoration(
        color: _card(context),
        border: Border(top: BorderSide(color: _border(context))),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(dark ? 0.3 : 0.06), blurRadius: 20, offset: const Offset(0, -4))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(items.length, (i) {
          final sel = i == selected;
          final item = items[i];
          return GestureDetector(
            onTap: () => onTap(i),
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: sel ? _purple.withOpacity(0.12) : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(children: [
                Icon(sel ? item.$1 : item.$2, color: sel ? _purple : _textSec(context), size: 22),
                if (sel) ...[
                  const SizedBox(width: 6),
                  Text(item.$3, style: const TextStyle(color: _purple, fontWeight: FontWeight.w700, fontSize: 13)),
                ],
              ]),
            ),
          );
        }),
      ),
    );
  }
}

// ── Home Tab ──────────────────────────────────────────────────────────────────
class _HomeTab extends StatelessWidget {
  final void Function(int) onTabChange;
  const _HomeTab({required this.onTabChange});

  @override
  Widget build(BuildContext context) {
    final auth    = context.watch<AppAuthProvider>();
    final orders  = context.watch<OrderProvider>();
    final notifs  = context.watch<NotificationProvider>();
    final chat    = context.watch<ChatProvider>();
    final profile = auth.currentUserProfile;
    final name    = profile?.displayName ?? 'Seller';
    final dark    = _isDark(context);

    final activeOrders = orders.sellerOrders
        .where((o) => o.driverId != null && o.driverId!.isNotEmpty && o.status != AppStatus.delivered)
        .toList();

    final pendingRequests = chat.chatRequests.where((d) {
      final data = d.data() as Map<String, dynamic>;
      return (data['status'] ?? '') == 'pending';
    }).length;

    return CustomScrollView(slivers: [
      SliverToBoxAdapter(child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: dark
                ? [const Color(0xFF1A1A1A), const Color(0xFF1E1E1E)]
                : [const Color(0xFF93B1B5), const Color(0xFFE5FFD0)],
          ),
        ),
        padding: const EdgeInsets.fromLTRB(20, 58, 20, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Top row
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Welcome!', style: TextStyle(color: _textSec(context), fontSize: 13)),
              Text(name,
                style: TextStyle(color: _textPri(context), fontSize: 22, fontWeight: FontWeight.w700),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            ])),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () => context.toggleTheme(),
              child: _IconBtn(icon: dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined, context: context),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () => Navigator.pushNamed(context, AppRoutes.notifications),
              child: Stack(clipBehavior: Clip.none, children: [
                _IconBtn(icon: Icons.notifications_outlined, context: context),
                if (notifs.unreadCount > 0)
                  Positioned(right: 8, top: 8,
                    child: Container(width: 8, height: 8,
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle))),
              ]),
            ),
          ]),
          const SizedBox(height: 28),
          // Quick actions
          Row(children: [
            Expanded(child: _QuickCard(
              label: 'New Delivery', sublabel: 'Create order',
              color: _purple,
              bgColor: dark ? const Color(0xFF252525) : _purpleL,
              icon: Icons.add_box_rounded,
              onTap: () => Navigator.pushNamed(context, AppRoutes.createOrder),
            )),
            const SizedBox(width: 14),
            Expanded(child: _QuickCard(
              label: 'Track Package', sublabel: 'All orders',
              color: _orange,
              bgColor: dark ? const Color(0xFF1C1209) : const Color(0xFFFFF0EB),
              icon: Icons.local_shipping_outlined,
              onTap: () => Navigator.pushNamed(context, AppRoutes.sellerOrders),
            )),
          ]),
          const SizedBox(height: 28),
          // Current shipment header
          Row(children: [
            Text('Current Shipment', style: TextStyle(color: _textPri(context), fontSize: 18, fontWeight: FontWeight.w700)),
            const Spacer(),
            GestureDetector(
              onTap: () => Navigator.pushNamed(context, AppRoutes.sellerOrders),
              child: Text('See all', style: const TextStyle(color: _purple, fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ]),
        ]),
      )),
      // Pending requests banner
      if (pendingRequests > 0)
        SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: GestureDetector(
            onTap: () => Navigator.pushNamed(context, AppRoutes.chatRequests),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _orange.withOpacity(0.3)),
              ),
              child: Row(children: [
                Container(width: 38, height: 38,
                  decoration: BoxDecoration(color: _orange.withOpacity(0.15), shape: BoxShape.circle),
                  child: const Icon(Icons.mark_chat_unread_outlined, color: _orange, size: 18)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('$pendingRequests new delivery request${pendingRequests > 1 ? 's' : ''}',
                    style: const TextStyle(color: _orange, fontWeight: FontWeight.w700, fontSize: 13)),
                  Text('Tap to review', style: TextStyle(color: _orange.withOpacity(0.7), fontSize: 11)),
                ])),
                const Icon(Icons.chevron_right, color: _orange),
              ]),
            ),
          ),
        )),
      // Active shipments
      activeOrders.isEmpty
          ? SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: _card(context), borderRadius: BorderRadius.circular(24), border: Border.all(color: _border(context))),
                child: Column(children: [
                  Icon(Icons.inbox_outlined, color: _textSec(context), size: 40),
                  const SizedBox(height: 10),
                  Text('No active shipments', style: TextStyle(color: _textSec(context), fontSize: 14)),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => Navigator.pushNamed(context, AppRoutes.createOrder),
                    child: const Text('Create your first order →', style: TextStyle(color: _purple, fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                ]),
              ),
            ))
          : SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              sliver: SliverList(delegate: SliverChildBuilderDelegate((ctx, i) =>
                Padding(padding: const EdgeInsets.only(bottom: 14), child: _ShipmentCard(order: activeOrders[i])),
                childCount: activeOrders.length,
              )),
            ),
      const SliverToBoxAdapter(child: SizedBox(height: 32)),
    ]);
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final BuildContext context;
  const _IconBtn({required this.icon, required this.context});

  @override
  Widget build(BuildContext ctx) => Container(
    width: 44, height: 44,
    decoration: BoxDecoration(color: _card(context), borderRadius: BorderRadius.circular(14), border: Border.all(color: _border(context))),
    child: Icon(icon, color: _textSec(context), size: 20),
  );
}

class _QuickCard extends StatelessWidget {
  final String label, sublabel;
  final Color color, bgColor;
  final IconData icon;
  final VoidCallback onTap;
  const _QuickCard({required this.label, required this.sublabel, required this.color, required this.bgColor, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(22)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 15, height: 1.2)),
          const SizedBox(height: 4),
          Text(sublabel, style: TextStyle(color: color.withOpacity(0.65), fontSize: 11)),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            Container(width: 44, height: 44,
              decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: color, size: 22)),
          ]),
        ]),
      ),
    );
  }
}

class _ShipmentCard extends StatelessWidget {
  final OrderModel order;
  const _ShipmentCard({required this.order});

  Color get _sc {
    switch (order.status) {
      case AppStatus.accepted:  return _purple;
      case AppStatus.pickedUp:  return const Color(0xFF3B82F6);
      case AppStatus.onTheWay:  return _orange;
      case AppStatus.delivered: return _green;
      default: return const Color(0xFF2A4A50);
    }
  }
  String get _sl {
    switch (order.status) {
      case AppStatus.accepted:  return 'Accepted';
      case AppStatus.pickedUp:  return 'Picked Up';
      case AppStatus.onTheWay:  return 'On The Way';
      case AppStatus.delivered: return 'Delivered';
      default: return order.status;
    }
  }
  double get _progress {
    switch (order.status) {
      case AppStatus.accepted:  return 0.25;
      case AppStatus.pickedUp:  return 0.5;
      case AppStatus.onTheWay:  return 0.75;
      case AppStatus.delivered: return 1.0;
      default: return 0.0;
    }
  }
  String get _chatId => '${order.id}_${order.sellerId}_${order.driverId ?? ''}';

  @override
  Widget build(BuildContext context) {
    final dark = _isDark(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF252525) : _purpleL,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _purple.withOpacity(0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 42, height: 42,
            decoration: BoxDecoration(color: dark ? Colors.white.withOpacity(0.08) : Colors.white, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.inventory_2_outlined, color: _purple, size: 20)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(order.description,
              style: TextStyle(color: _textPri(context), fontWeight: FontWeight.w700, fontSize: 14),
              maxLines: 1, overflow: TextOverflow.ellipsis),
            Text('ID: ${order.id.substring(0, order.id.length.clamp(0, 8)).toUpperCase()}',
              style: TextStyle(color: _textSec(context), fontSize: 11)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: _sc.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
            child: Text(_sl, style: TextStyle(color: _sc, fontSize: 11, fontWeight: FontWeight.w700))),
        ]),
        const SizedBox(height: 14),
        ClipRRect(borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: _progress, minHeight: 4,
            backgroundColor: dark ? Colors.white.withOpacity(0.1) : Colors.white,
            valueColor: AlwaysStoppedAnimation<Color>(_sc))),
        const SizedBox(height: 14),
        Row(children: [
          Icon(Icons.location_on_outlined, color: _textSec(context), size: 13),
          const SizedBox(width: 4),
          Expanded(child: Text(order.pickupLocation,
            style: TextStyle(color: _textPri(context), fontWeight: FontWeight.w600, fontSize: 12),
            maxLines: 1, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 16),
          Icon(Icons.flag_outlined, color: _textSec(context), size: 13),
          const SizedBox(width: 4),
          Expanded(child: Text(order.dropoffLocation,
            style: TextStyle(color: _textPri(context), fontWeight: FontWeight.w600, fontSize: 12),
            maxLines: 1, overflow: TextOverflow.ellipsis)),
        ]),
        const SizedBox(height: 12),
        _SellerChatBtn(order: order, chatId: _chatId),
      ]),
    );
  }
}

class _SellerChatBtn extends StatelessWidget {
  final OrderModel order;
  final String chatId;
  const _SellerChatBtn({required this.order, required this.chatId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('chat_requests').doc(chatId).snapshots(),
      builder: (ctx, snap) {
        final data = snap.data?.data();
        final map  = data is Map<String, dynamic> ? data : <String, dynamic>{};
        final status = (map['status'] ?? '').toString();
        if (!snap.hasData || !snap.data!.exists) return const SizedBox.shrink();
        if (status == 'rejected') return Text('Request rejected', style: TextStyle(color: Colors.redAccent.withOpacity(0.8), fontSize: 12));
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('chats').doc(chatId).snapshots(),
          builder: (ctx2, cs) {
            if (!(cs.data?.exists ?? false)) return Text('Preparing chat...', style: TextStyle(color: _textSec(context), fontSize: 12));
            return GestureDetector(
              onTap: () => Navigator.pushNamed(ctx, AppRoutes.chatScreen,
                arguments: ChatScreenArgs(chatId: chatId, title: order.description)),
              child: Container(height: 40, alignment: Alignment.center,
                decoration: BoxDecoration(color: _purple.withOpacity(0.12), borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _purple.withOpacity(0.3))),
                child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.chat_bubble_outline, color: _purple, size: 15),
                  SizedBox(width: 6),
                  Text('Open Chat', style: TextStyle(color: _purple, fontWeight: FontWeight.w700, fontSize: 13)),
                ])),
            );
          },
        );
      },
    );
  }
}

// ── Track Tab ─────────────────────────────────────────────────────────────────
class _TrackTab extends StatelessWidget {
  const _TrackTab();

  @override
  Widget build(BuildContext context) {
    final orders = context.watch<OrderProvider>().sellerOrders;
    return CustomScrollView(slivers: [
      SliverToBoxAdapter(child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 58, 20, 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Track Package', style: TextStyle(color: _textPri(context), fontSize: 28, fontWeight: FontWeight.w700)),
          Text('${orders.length} total orders', style: TextStyle(color: _textSec(context), fontSize: 14)),
        ]),
      )),
      orders.isEmpty
          ? SliverFillRemaining(child: Center(child: Text('No orders yet', style: TextStyle(color: _textSec(context), fontSize: 15))))
          : SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              sliver: SliverList(delegate: SliverChildBuilderDelegate(
                (ctx, i) => Padding(padding: const EdgeInsets.only(bottom: 12), child: _TrackCard(order: orders[i])),
                childCount: orders.length,
              )),
            ),
    ]);
  }
}

class _TrackCard extends StatelessWidget {
  final OrderModel order;
  const _TrackCard({required this.order});

  Color get _sc {
    switch (order.status) {
      case AppStatus.open:      return const Color(0xFF2A4A50);
      case AppStatus.accepted:  return _purple;
      case AppStatus.pickedUp:  return const Color(0xFF3B82F6);
      case AppStatus.onTheWay:  return _orange;
      case AppStatus.delivered: return _green;
      default: return const Color(0xFF2A4A50);
    }
  }
  String get _sl {
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _card(context), borderRadius: BorderRadius.circular(22), border: Border.all(color: _border(context))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(order.description,
            style: TextStyle(color: _textPri(context), fontWeight: FontWeight.w700, fontSize: 14),
            maxLines: 1, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 10),
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: _sc.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
            child: Text(_sl, style: TextStyle(color: _sc, fontSize: 11, fontWeight: FontWeight.w700))),
        ]),
        const SizedBox(height: 8),
        Text('${order.pickupLocation} → ${order.dropoffLocation}',
          style: TextStyle(color: _textSec(context), fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 6),
        Row(children: [
          Text('\$${order.price.toStringAsFixed(0)}',
            style: const TextStyle(color: _green, fontWeight: FontWeight.w800, fontSize: 15)),
          const Spacer(),
          Text(hasDriver ? 'Driver assigned' : 'Awaiting driver',
            style: TextStyle(color: _textSec(context), fontSize: 11)),
        ]),
        if (hasDriver && order.status != AppStatus.delivered) ...[
          const SizedBox(height: 12),
          _SellerChatBtn(order: order, chatId: _chatId),
        ],
      ]),
    );
  }
}

// ── Chats Tab ─────────────────────────────────────────────────────────────────
class _ChatsTab extends StatelessWidget {
  const _ChatsTab();

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatProvider>();
    final currentUserId = context.watch<AppAuthProvider>().currentUserId ?? '';

    return CustomScrollView(slivers: [
      SliverToBoxAdapter(child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 58, 20, 20),
        child: Text('Chats', style: TextStyle(color: _textPri(context), fontSize: 28, fontWeight: FontWeight.w700)),
      )),
      chat.chats.isEmpty
          ? SliverFillRemaining(child: Center(child: Text('No active chats', style: TextStyle(color: _textSec(context), fontSize: 15))))
          : SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              sliver: SliverList(delegate: SliverChildBuilderDelegate(
                (ctx, i) {
                  final doc  = chat.chats[i];
                  final data = doc.data() as Map<String, dynamic>;
                  final sellerId = (data['sellerId'] ?? '').toString();
                  final driverId = (data['driverId'] ?? '').toString();
                  final otherId  = currentUserId == sellerId ? driverId : sellerId;
                  final desc     = (data['orderDescription'] ?? 'Chat').toString();
                  final last     = (data['lastMessage'] ?? '').toString();
                  return Padding(padding: const EdgeInsets.only(bottom: 10),
                    child: _ChatTile(chatId: doc.id, otherUserId: otherId, description: desc, lastMessage: last));
                },
                childCount: chat.chats.length,
              )),
            ),
    ]);
  }
}

class _ChatTile extends StatelessWidget {
  final String chatId, otherUserId, description, lastMessage;
  const _ChatTile({required this.chatId, required this.otherUserId, required this.description, required this.lastMessage});

  @override
  Widget build(BuildContext context) {
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
                Container(width: 48, height: 48, decoration: BoxDecoration(color: _soft(context), shape: BoxShape.circle),
                  child: Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'U',
                    style: TextStyle(color: _textPri(context), fontWeight: FontWeight.w700, fontSize: 18)))),
                Positioned(right: 0, bottom: 0,
                  child: Container(width: 12, height: 12,
                    decoration: BoxDecoration(color: isOnline ? _green : const Color(0xFF9CA3AF),
                      shape: BoxShape.circle, border: Border.all(color: _card(context), width: 2)))),
              ]),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(description, style: TextStyle(color: _textPri(context), fontWeight: FontWeight.w700, fontSize: 14),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(lastMessage.isEmpty ? 'No messages yet' : lastMessage,
                  style: TextStyle(color: _textSec(context), fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
              ])),
              const Icon(Icons.chevron_right, color: _purple, size: 20),
            ]),
          ),
        );
      },
    );
  }
}

// ── Profile Tab ───────────────────────────────────────────────────────────────
class _ProfileTab extends StatelessWidget {
  final Future<void> Function() onLogout;
  const _ProfileTab({required this.onLogout});

  @override
  Widget build(BuildContext context) {
    final auth    = context.watch<AppAuthProvider>();
    final profile = auth.currentUserProfile;
    final name    = profile?.displayName ?? 'Seller';
    final email   = auth.currentUserEmail ?? '';
    final online  = profile?.isOnline ?? false;
    final dark    = _isDark(context);
    final isAdmin = profile?.isAdmin ?? false;

    return CustomScrollView(slivers: [
      SliverToBoxAdapter(child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 58, 20, 32),
        child: Column(children: [
          Container(width: 88, height: 88,
            decoration: BoxDecoration(shape: BoxShape.circle, color: _purple.withOpacity(0.15),
              border: Border.all(color: _purple.withOpacity(0.4), width: 2)),
            child: Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'S',
              style: const TextStyle(color: _purple, fontSize: 36, fontWeight: FontWeight.w700)))),
          const SizedBox(height: 14),
          Text(name, style: TextStyle(color: _textPri(context), fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(email, style: TextStyle(color: _textSec(context), fontSize: 13)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(color: online ? _green.withOpacity(0.12) : _soft(context), borderRadius: BorderRadius.circular(20)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 7, height: 7, decoration: BoxDecoration(shape: BoxShape.circle, color: online ? _green : _textSec(context))),
              const SizedBox(width: 6),
              Text(online ? 'Online' : 'Offline',
                style: TextStyle(color: online ? _green : _textSec(context), fontSize: 12, fontWeight: FontWeight.w600)),
            ]),
          ),
          const SizedBox(height: 28),
          _tile(context, dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            dark ? 'Switch to Light Mode' : 'Switch to Dark Mode', () => context.toggleTheme()),
          const SizedBox(height: 10),
          _tile(context, Icons.notifications_outlined, 'Notifications',
            () => Navigator.pushNamed(context, AppRoutes.notifications)),
          if (isAdmin) ...[
            const SizedBox(height: 10),
            _tile(context, Icons.admin_panel_settings_outlined, 'Admin Panel',
              () => Navigator.pushNamed(context, AppRoutes.admin),
              valueColor: _orange),
          ],
          const SizedBox(height: 28),
          GestureDetector(
            onTap: onLogout,
            child: Container(height: 54, alignment: Alignment.center,
              decoration: BoxDecoration(color: _orange.withOpacity(0.1), borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _orange.withOpacity(0.35))),
              child: const Text('Logout', style: TextStyle(color: _orange, fontWeight: FontWeight.w700, fontSize: 15)))),
        ]),
      )),
    ]);
  }

  Widget _tile(BuildContext ctx, IconData icon, String label, VoidCallback onTap, {Color? valueColor}) {
    final iconColor = valueColor ?? _purple;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: _card(ctx), borderRadius: BorderRadius.circular(18), border: Border.all(color: _border(ctx))),
        child: Row(children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 14),
          Text(label, style: TextStyle(color: _textPri(ctx), fontWeight: FontWeight.w600, fontSize: 14)),
          const Spacer(),
          Icon(Icons.chevron_right, color: _textSec(ctx), size: 18),
        ]),
      ),
    );
  }
}
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_status.dart';
import '../../models/order_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/order_provider.dart';
import '../../routes/app_routes.dart';

bool _isDark(BuildContext ctx) => Theme.of(ctx).brightness == Brightness.dark;
Color _accent(BuildContext ctx) => _isDark(ctx) ? const Color(0xFF89F336) : const Color(0xFF4F7C82);
Color _textPri(BuildContext ctx) => _isDark(ctx) ? const Color(0xFFF5F7FA) : const Color(0xFF1A2B2D);
Color _textSec(BuildContext ctx) => _isDark(ctx) ? const Color(0xFF98A1AE) : const Color(0xFF2A4A50);
Color _soft(BuildContext ctx)    => _isDark(ctx) ? const Color(0xFF3A3A3A) : const Color(0xFF7FA3A7);
Color _card(BuildContext ctx)    => _isDark(ctx) ? const Color(0xFF2C2C2C) : const Color(0xFFB5CDD0);
Color _border(BuildContext ctx)  => _isDark(ctx) ? const Color(0x14B5CDD0) : const Color(0xFF5E8A8F);
Color _bg(BuildContext ctx)      => _isDark(ctx) ? const Color(0xFF1E1E1E) : const Color(0xFF93B1B5);

// ── Shared order helpers ───────────────────────────────────────────────────────
int _stepOf(String status) {
  switch (status) {
    case AppStatus.accepted:  return 1;
    case AppStatus.pickedUp:
    case AppStatus.onTheWay:  return 2;
    case AppStatus.delivered: return 3;
    default:                  return 0;
  }
}
String _statusLabel(String status) {
  switch (status) {
    case AppStatus.open:      return 'Open';
    case AppStatus.accepted:  return 'Accepted';
    case AppStatus.pickedUp:
    case AppStatus.onTheWay:  return 'In Transit';
    case AppStatus.delivered: return 'Delivered';
    default:                  return status;
  }
}
bool _isActive(String status) =>
    status == AppStatus.accepted ||
    status == AppStatus.pickedUp ||
    status == AppStatus.onTheWay;
String _ordId(String id) =>
    'ORD-${id.substring(0, id.length >= 9 ? 9 : id.length).toUpperCase()}';
String _shortDate(DateTime? dt) {
  if (dt == null) return '—';
  const months = ['Jan','Feb','Mar','Apr','May','Jun',
                  'Jul','Aug','Sep','Oct','Nov','Dec'];
  return '${dt.day} ${months[dt.month - 1]}, ${dt.year}';
}
String _cityOf(String addr) {
  final parts = addr.split(',');
  return parts.first.trim().isEmpty ? addr : parts.first.trim();
}

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
    final accent = _accent(context);
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
                color: sel ? accent.withOpacity(0.12) : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(children: [
                Icon(sel ? item.$1 : item.$2, color: sel ? accent : _textSec(context), size: 22),
                if (sel) ...[
                  const SizedBox(width: 6),
                  Text(item.$3, style: TextStyle(color: accent, fontWeight: FontWeight.w700, fontSize: 13)),
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
    final accent  = _accent(context);
    final auth    = context.watch<AppAuthProvider>();
    final orders  = context.watch<OrderProvider>();
    final notifs  = context.watch<NotificationProvider>();
    final chat    = context.watch<ChatProvider>();
    final profile = auth.currentUserProfile;
    final name    = profile?.displayName ?? 'Seller';
    final dark    = _isDark(context);

    final activeOrders = orders.sellerOrders
        .where((o) => o.status != AppStatus.delivered)
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
              color: accent,
              bgColor: dark ? const Color(0xFF252525) : accent.withOpacity(0.15),
              icon: Icons.add_box_rounded,
              onTap: () => Navigator.pushNamed(context, AppRoutes.createOrder),
            )),
            const SizedBox(width: 14),
            Expanded(child: _QuickCard(
              label: 'Track Package', sublabel: 'All orders',
              color: const Color(0xFF1A1A1A),
              bgColor: const Color(0xFF89F336),
              icon: Icons.local_shipping_outlined,
              onTap: () => Navigator.pushNamed(context, AppRoutes.sellerOrders),
            )),
          ]),
          const SizedBox(height: 28),
          // Current shipment header
          Row(children: [
            Text('My Orders', style: TextStyle(color: _textPri(context), fontSize: 18, fontWeight: FontWeight.w700)),
            const Spacer(),
            GestureDetector(
              onTap: () => Navigator.pushNamed(context, AppRoutes.sellerOrders),
              child: Text('See all', style: TextStyle(color: accent, fontSize: 13, fontWeight: FontWeight.w600)),
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
                color: accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: accent.withOpacity(0.3)),
              ),
              child: Row(children: [
                Container(width: 38, height: 38,
                  decoration: BoxDecoration(color: accent.withOpacity(0.15), shape: BoxShape.circle),
                  child: Icon(Icons.mark_chat_unread_outlined, color: accent, size: 18)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('$pendingRequests new delivery request${pendingRequests > 1 ? 's' : ''}',
                    style: TextStyle(color: accent, fontWeight: FontWeight.w700, fontSize: 13)),
                  Text('Tap to review', style: TextStyle(color: accent.withOpacity(0.7), fontSize: 11)),
                ])),
                Icon(Icons.chevron_right, color: accent),
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
                  Text('No orders yet', style: TextStyle(color: _textSec(context), fontSize: 14)),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => Navigator.pushNamed(context, AppRoutes.createOrder),
                    child: Text('Create your first order →', style: TextStyle(color: accent, fontWeight: FontWeight.w600, fontSize: 13)),
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

  Color _sc(Color accent) {
    switch (order.status) {
      case AppStatus.open:      return const Color(0xFF98A1AE);
      case AppStatus.accepted:  return accent;
      case AppStatus.pickedUp:  return const Color(0xFF3B82F6);
      case AppStatus.onTheWay:  return accent;
      case AppStatus.delivered: return accent;
      default:                  return const Color(0xFF98A1AE);
    }
  }
  String get _sl {
    switch (order.status) {
      case AppStatus.open:      return 'Open';
      case AppStatus.accepted:  return 'Accepted';
      case AppStatus.pickedUp:  return 'Picked Up';
      case AppStatus.onTheWay:  return 'On The Way';
      case AppStatus.delivered: return 'Delivered';
      default:                  return order.status;
    }
  }
  double get _progress {
    switch (order.status) {
      case AppStatus.open:      return 0.0;
      case AppStatus.accepted:  return 0.25;
      case AppStatus.pickedUp:  return 0.5;
      case AppStatus.onTheWay:  return 0.75;
      case AppStatus.delivered: return 1.0;
      default:                  return 0.0;
    }
  }
  bool get _isOpenOrder => order.status == AppStatus.open;
  String get _chatId => '${order.id}_${order.sellerId}_${order.driverId ?? ''}';

  @override
  Widget build(BuildContext context) {
    final accent = _accent(context);
    final dark = _isDark(context);
    final isActive = _isActive(order.status);
    final cardBg = _isOpenOrder
        ? (dark ? const Color(0xFF2C2C2C) : const Color(0xFFB5CDD0))
        : isActive
            ? const Color(0xFF2A5018)
            : (dark ? const Color(0xFF252525) : const Color(0xFFD8EDD0));
    final cardBorder = _isOpenOrder
        ? (dark ? const Color(0x14B5CDD0) : const Color(0xFF5E8A8F))
        : isActive
            ? const Color(0xFF89F336)
            : accent.withOpacity(0.2);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cardBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 42, height: 42,
            decoration: BoxDecoration(color: isActive ? const Color(0xFF3A6828) : (dark ? const Color(0xFF3A3A3A) : Colors.white), borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.inventory_2_outlined, color: isActive ? const Color(0xFF89F336) : accent, size: 20)),
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
            decoration: BoxDecoration(color: _sc(accent).withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
            child: Text(_sl, style: TextStyle(color: _sc(accent), fontSize: 11, fontWeight: FontWeight.w700))),
        ]),
        const SizedBox(height: 14),
        ClipRRect(borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: _progress, minHeight: 4,
            backgroundColor: dark ? Colors.white.withOpacity(0.1) : Colors.white,
            valueColor: AlwaysStoppedAnimation<Color>(_sc(accent)))),
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
        if (_isOpenOrder)
          Row(children: [
            Icon(Icons.hourglass_empty_rounded,
              color: _textSec(context), size: 14),
            const SizedBox(width: 6),
            Text('Waiting for a driver to accept',
              style: TextStyle(color: _textSec(context), fontSize: 12)),
          ])
        else
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
            final accent = _accent(ctx);
            return GestureDetector(
              onTap: () => Navigator.pushNamed(ctx, AppRoutes.chatScreen,
                arguments: ChatScreenArgs(chatId: chatId, title: order.description)),
              child: Container(height: 40, alignment: Alignment.center,
                decoration: BoxDecoration(color: accent.withOpacity(0.12), borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: accent.withOpacity(0.3))),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.chat_bubble_outline, color: accent, size: 15),
                  const SizedBox(width: 6),
                  Text('Open Chat', style: TextStyle(color: accent, fontWeight: FontWeight.w700, fontSize: 13)),
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

  void _showDetail(BuildContext context, OrderModel order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PackageDetailSheet(order: order),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accent(context);
    final orders = context.watch<OrderProvider>().sellerOrders;
    return CustomScrollView(slivers: [
      SliverToBoxAdapter(child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 58, 20, 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('My Shipments',
            style: TextStyle(color: _textPri(context),
              fontSize: 28, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Row(children: [
            Text('${orders.length} total orders',
              style: TextStyle(color: _textSec(context), fontSize: 14)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: accent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20)),
              child: Text(
                '${orders.where((o) => _isActive(o.status)).length} active',
                style: TextStyle(color: accent, fontSize: 11,
                  fontWeight: FontWeight.w700)),
            ),
          ]),
        ]),
      )),
      orders.isEmpty
          ? SliverFillRemaining(child: Center(child: Column(
              mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(Icons.local_shipping_outlined,
                  color: accent, size: 32)),
              const SizedBox(height: 14),
              Text('No shipments yet',
                style: TextStyle(color: _textPri(context),
                  fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('Create your first delivery order',
                style: TextStyle(color: _textSec(context), fontSize: 13)),
            ])))
          : SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              sliver: SliverList(delegate: SliverChildBuilderDelegate(
                (ctx, i) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _TrackCard(
                    order: orders[i],
                    onTap: () => _showDetail(context, orders[i]))),
                childCount: orders.length,
              )),
            ),
    ]);
  }
}

class _TrackCard extends StatelessWidget {
  final OrderModel order;
  final VoidCallback onTap;
  const _TrackCard({required this.order, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final accent    = _accent(context);
    final active    = _isActive(order.status);
    final delivered = order.status == AppStatus.delivered;
    final step      = _stepOf(order.status);

    final cardColor = active
        ? const Color(0xFF2A5018)
        : _card(context);
    final borderColor = active
        ? const Color(0xFF89F336)
        : delivered ? accent.withOpacity(0.2) : Colors.transparent;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor, width: 1.5)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(_ordId(order.id),
              style: TextStyle(
                color: _textPri(context),
                fontWeight: FontWeight.w800, fontSize: 15,
                letterSpacing: 0.5)),
            const Spacer(),
            _StatusBadge(status: order.status, accent: accent),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: _LocationCol(
              label: 'From', city: _cityOf(order.pickupLocation),
              textPri: _textPri(context), textSec: _textSec(context))),
            Icon(Icons.arrow_forward_rounded, color: accent, size: 18),
            Expanded(child: _LocationCol(
              label: 'To', city: _cityOf(order.dropoffLocation),
              textPri: _textPri(context), textSec: _textSec(context),
              align: CrossAxisAlignment.end)),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            Icon(Icons.calendar_today_outlined,
              color: _textSec(context), size: 11),
            const SizedBox(width: 4),
            Text(_shortDate(order.createdAt),
              style: TextStyle(color: _textSec(context), fontSize: 11)),
            const Spacer(),
            Text('₮${order.price.toStringAsFixed(0)}',
              style: TextStyle(
                color: accent, fontWeight: FontWeight.w800, fontSize: 14)),
          ]),
          const SizedBox(height: 14),
          _ProgressTracker(
            step: step, accent: accent,
            soft: _soft(context)),
        ]),
      ),
    );
  }
}

// ── Shared sub-widgets (used in TrackCard + PackageDetailSheet) ───────────────
class _StatusBadge extends StatelessWidget {
  final String status;
  final Color accent;
  const _StatusBadge({required this.status, required this.accent});
  Color get _color {
    switch (status) {
      case AppStatus.delivered: return accent;
      case AppStatus.onTheWay:
      case AppStatus.pickedUp:  return const Color(0xFF3B82F6);
      case AppStatus.accepted:  return accent;
      default:                  return const Color(0xFF98A1AE);
    }
  }
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: _color.withOpacity(0.15),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _color.withOpacity(0.4))),
    child: Text(_statusLabel(status),
      style: TextStyle(color: _color, fontSize: 11,
        fontWeight: FontWeight.w700)),
  );
}

class _LocationCol extends StatelessWidget {
  final String label, city;
  final Color textPri, textSec;
  final CrossAxisAlignment align;
  const _LocationCol({
    required this.label, required this.city,
    required this.textPri, required this.textSec,
    this.align = CrossAxisAlignment.start,
  });
  @override
  Widget build(BuildContext context) =>
    Column(crossAxisAlignment: align, children: [
      Text(label,
        style: TextStyle(color: textSec, fontSize: 10,
          fontWeight: FontWeight.w500)),
      const SizedBox(height: 2),
      Text(city,
        style: TextStyle(color: textPri, fontSize: 13,
          fontWeight: FontWeight.w700),
        maxLines: 1, overflow: TextOverflow.ellipsis),
    ]);
}

class _ProgressTracker extends StatelessWidget {
  final int step;
  final Color accent, soft;
  const _ProgressTracker(
      {required this.step, required this.accent, required this.soft});
  static const _labels = ['Posted', 'Accepted', 'In Transit', 'Delivered'];

  @override
  Widget build(BuildContext context) {
    // Each dot is paired with its label in a Column so they're always aligned.
    // Expanded lines fill the space between steps.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < 4; i++) ...[
          if (i > 0)
            Expanded(
              child: Padding(
                // Vertically center the 2px line with the 12px dot (top offset = (12-2)/2 = 5)
                padding: const EdgeInsets.only(top: 5.0),
                child: Container(
                  height: 2,
                  color: i <= step ? accent : soft.withOpacity(0.3),
                ),
              ),
            ),
          _buildStep(i),
        ],
      ],
    );
  }

  Widget _buildStep(int i) {
    final done    = i <= step;
    final current = i == step;
    final dotSize = current ? 16.0 : 12.0;
    final dotColor = done ? accent : soft;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: dotSize, height: dotSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: dotColor,
            boxShadow: current
                ? [BoxShadow(
                    color: accent.withOpacity(0.55),
                    blurRadius: 10, spreadRadius: 2)]
                : null,
            border: Border.all(
              color: done ? accent : soft.withOpacity(0.4),
              width: current ? 2.0 : 1.5),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _labels[i],
          style: TextStyle(
            color: current
                ? accent
                : done
                    ? accent.withOpacity(0.50)
                    : soft,
            fontSize: current ? 10.5 : 9.5,
            fontWeight: current ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ── Package Detail Sheet ───────────────────────────────────────────────────────
class _PackageDetailSheet extends StatelessWidget {
  final OrderModel order;
  const _PackageDetailSheet({required this.order});
  String get _chatId =>
      '${order.id}_${order.sellerId}_${order.driverId ?? ''}';

  @override
  Widget build(BuildContext context) {
    final accent    = _accent(context);
    final dark      = _isDark(context);
    final step      = _stepOf(order.status);
    final hasDriver = order.driverId != null && order.driverId!.isNotEmpty;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, ctrl) => Container(
        decoration: BoxDecoration(
          color: dark ? const Color(0xFF1E1E1E) : const Color(0xFF93B1B5),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
        child: Column(children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: dark ? const Color(0xFF3A3A3A) : const Color(0xFF7FA3A7),
              borderRadius: BorderRadius.circular(4))),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: dark ? const Color(0xFF2C2C2C) : const Color(0xFFB5CDD0),
                    borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.arrow_back_ios_new_rounded,
                    color: _textPri(context), size: 14))),
              const SizedBox(width: 12),
              Expanded(child: Text('Package Details',
                style: TextStyle(color: _textPri(context),
                  fontSize: 18, fontWeight: FontWeight.w700))),
            ]),
          ),
          const SizedBox(height: 16),
          Expanded(child: ListView(
            controller: ctrl,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            children: [
              // Big header card (green gradient)
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [accent, accent.withOpacity(0.7)]),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(
                    color: accent.withOpacity(0.3),
                    blurRadius: 24, offset: const Offset(0, 8))]),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  Row(children: [
                    Container(width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(14)),
                      child: const Icon(Icons.inventory_2_outlined,
                        color: Colors.white, size: 24)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(20)),
                      child: Text(_statusLabel(order.status),
                        style: const TextStyle(
                          color: Colors.white, fontSize: 12,
                          fontWeight: FontWeight.w700))),
                  ]),
                  const SizedBox(height: 14),
                  const Text('ID Number',
                    style: TextStyle(color: Colors.white70, fontSize: 11)),
                  const SizedBox(height: 2),
                  Text(_ordId(order.id),
                    style: const TextStyle(
                      color: Colors.white, fontSize: 20,
                      fontWeight: FontWeight.w800, letterSpacing: 1)),
                  const SizedBox(height: 16),
                  Container(height: 1,
                    color: Colors.white.withOpacity(0.2)),
                  const SizedBox(height: 16),
                  const Text('Details Package',
                    style: TextStyle(color: Colors.white70, fontSize: 11,
                      fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(flex: 2, child: _DetailItem(label: 'Description',
                      value: order.description)),
                    const SizedBox(width: 16),
                    Expanded(child: _DetailItem(label: 'Status',
                      value: _statusLabel(order.status))),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(flex: 2, child: _DetailItem(label: 'From',
                      value: _cityOf(order.pickupLocation))),
                    const SizedBox(width: 16),
                    Expanded(child: _DetailItem(label: 'To',
                      value: _cityOf(order.dropoffLocation))),
                  ]),
                  const SizedBox(height: 10),
                  _DetailItem(label: 'Price',
                    value: '₮${order.price.toStringAsFixed(0)}'),
                ]),
              ),
              const SizedBox(height: 20),
              // Details Status
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: dark ? const Color(0xFF2C2C2C) : const Color(0xFFB5CDD0),
                  borderRadius: BorderRadius.circular(20)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  Row(children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                      Text('Details Status',
                        style: TextStyle(color: _textPri(context),
                          fontSize: 16, fontWeight: FontWeight.w700)),
                      Text(_ordId(order.id),
                        style: TextStyle(
                          color: _textSec(context), fontSize: 11)),
                    ]),
                    const Spacer(),
                    Container(width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10)),
                      child: Icon(Icons.qr_code_rounded,
                        color: accent, size: 20)),
                  ]),
                  const SizedBox(height: 20),
                  _ProgressTracker(step: step, accent: accent,
                    soft: dark
                        ? const Color(0xFF3A3A3A)
                        : const Color(0xFF7FA3A7)),
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('From',
                          style: TextStyle(color: _textSec(context),
                            fontSize: 10)),
                        Text(_cityOf(order.pickupLocation),
                          style: TextStyle(color: _textPri(context),
                            fontWeight: FontWeight.w700, fontSize: 14),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      ])),
                    const SizedBox(width: 8),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('To',
                          style: TextStyle(color: _textSec(context),
                            fontSize: 10)),
                        Text(_cityOf(order.dropoffLocation),
                          style: TextStyle(color: _textPri(context),
                            fontWeight: FontWeight.w700, fontSize: 14),
                          textAlign: TextAlign.end,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      ])),
                  ]),
                ]),
              ),
              const SizedBox(height: 14),
              // Driver / chat
              if (hasDriver)
                _DriverSection(
                  order: order, chatId: _chatId, accent: accent)
              else
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: dark ? const Color(0xFF2C2C2C) : const Color(0xFFB5CDD0),
                    borderRadius: BorderRadius.circular(16)),
                  child: Row(children: [
                    Icon(Icons.hourglass_empty_rounded,
                      color: _textSec(context), size: 18),
                    const SizedBox(width: 10),
                    Text('Waiting for a driver to accept',
                      style: TextStyle(
                        color: _textSec(context), fontSize: 13)),
                  ])),
            ],
          )),
        ]),
      ),
    );
  }
}

class _DetailItem extends StatelessWidget {
  final String label, value;
  const _DetailItem({required this.label, required this.value});
  @override
  Widget build(BuildContext context) =>
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
        style: const TextStyle(color: Colors.white70, fontSize: 10)),
      const SizedBox(height: 2),
      Text(value,
        style: const TextStyle(color: Colors.white,
          fontSize: 13, fontWeight: FontWeight.w700),
        maxLines: 2, overflow: TextOverflow.ellipsis),
    ]);
}

class _DriverSection extends StatelessWidget {
  final OrderModel order;
  final String chatId;
  final Color accent;
  const _DriverSection(
      {required this.order, required this.chatId, required this.accent});
  @override
  Widget build(BuildContext context) {
    final dark = _isDark(context);
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users').doc(order.driverId).snapshots(),
      builder: (ctx, snap) {
        final data = snap.data?.data();
        final m = data is Map<String, dynamic> ? data : <String, dynamic>{};
        final driverName = (m['name'] ?? 'Driver').toString();
        final vehicle = (m['vehicleType'] ?? '').toString();
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: dark ? const Color(0xFF2C2C2C) : const Color(0xFFB5CDD0),
            borderRadius: BorderRadius.circular(20)),
          child: Row(children: [
            Container(width: 44, height: 44,
              decoration: BoxDecoration(
                color: accent.withOpacity(0.12),
                shape: BoxShape.circle),
              child: Center(child: Text(
                driverName.isNotEmpty
                    ? driverName[0].toUpperCase() : 'D',
                style: TextStyle(color: accent,
                  fontWeight: FontWeight.w700, fontSize: 16)))),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Delivery Partner',
                style: TextStyle(color: _textSec(context), fontSize: 10)),
              Text(driverName,
                style: TextStyle(color: _textPri(context),
                  fontWeight: FontWeight.w700, fontSize: 14)),
              if (vehicle.isNotEmpty)
                Text(vehicle.replaceAll('_', ' ').toUpperCase(),
                  style: TextStyle(color: _textSec(context), fontSize: 11)),
            ])),
            GestureDetector(
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, AppRoutes.chatScreen,
                  arguments: ChatScreenArgs(chatId: chatId,
                    title: order.description));
              },
              child: Container(width: 40, height: 40,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.chat_bubble_outline_rounded,
                  color: accent, size: 18))),
          ]),
        );
      },
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
        final accent = _accent(context);
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
                    decoration: BoxDecoration(color: isOnline ? accent : const Color(0xFF9CA3AF),
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
              Icon(Icons.chevron_right, color: accent, size: 20),
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
    final accent  = _accent(context);
    final auth    = context.watch<AppAuthProvider>();
    final profile = auth.currentUserProfile;
    final name    = profile?.displayName ?? 'Seller';
    final email   = auth.currentUserEmail ?? '';
    final online  = profile?.isOnline ?? false;
    final isAdmin = profile?.isAdmin ?? false;

    return CustomScrollView(slivers: [
      SliverToBoxAdapter(child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 58, 20, 32),
        child: Column(children: [
          Container(width: 88, height: 88,
            decoration: BoxDecoration(shape: BoxShape.circle, color: accent.withOpacity(0.15),
              border: Border.all(color: accent.withOpacity(0.4), width: 2)),
            child: Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'S',
              style: TextStyle(color: accent, fontSize: 36, fontWeight: FontWeight.w700)))),
          const SizedBox(height: 14),
          Text(name, style: TextStyle(color: _textPri(context), fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(email, style: TextStyle(color: _textSec(context), fontSize: 13)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(color: online ? accent.withOpacity(0.12) : _soft(context), borderRadius: BorderRadius.circular(20)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 7, height: 7, decoration: BoxDecoration(shape: BoxShape.circle, color: online ? accent : _textSec(context))),
              const SizedBox(width: 6),
              Text(online ? 'Online' : 'Offline',
                style: TextStyle(color: online ? accent : _textSec(context), fontSize: 12, fontWeight: FontWeight.w600)),
            ]),
          ),
          const SizedBox(height: 20),
          _SubscriptionCard(profile: profile),
          const SizedBox(height: 20),
          _tile(context, Icons.notifications_outlined, 'Notifications',
            () => Navigator.pushNamed(context, AppRoutes.notifications)),
          if (isAdmin) ...[
            const SizedBox(height: 10),
            _tile(context, Icons.admin_panel_settings_outlined, 'Admin Panel',
              () => Navigator.pushNamed(context, AppRoutes.admin),
              valueColor: accent),
          ],
          const SizedBox(height: 28),
          GestureDetector(
            onTap: onLogout,
            child: Container(height: 54, alignment: Alignment.center,
              decoration: BoxDecoration(color: accent.withOpacity(0.1), borderRadius: BorderRadius.circular(18),
                border: Border.all(color: accent.withOpacity(0.35))),
              child: Text('Logout', style: TextStyle(color: accent, fontWeight: FontWeight.w700, fontSize: 15)))),
        ]),
      )),
    ]);
  }

  Widget _tile(BuildContext ctx, IconData icon, String label, VoidCallback onTap, {Color? valueColor}) {
    final iconColor = valueColor ?? _accent(ctx);
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

// ── Subscription Card (shared by seller & driver profile) ─────────────────────
class _SubscriptionCard extends StatelessWidget {
  final dynamic profile;
  const _SubscriptionCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF89F336);
    final expiry = profile?.subscriptionExpiry as DateTime?;
    final isActive = profile?.isSubscriptionActive as bool? ?? false;
    final now = DateTime.now();
    final daysLeft = expiry != null ? expiry.difference(now).inDays : null;

    final statusText = isActive
        ? (daysLeft != null ? '$daysLeft day${daysLeft != 1 ? 's' : ''} remaining' : 'Active')
        : (expiry != null ? 'Subscription expired' : 'No active subscription');
    final statusColor = isActive ? accent : Colors.redAccent;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _card(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isActive ? accent.withOpacity(0.4) : Colors.redAccent.withOpacity(0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.verified_rounded, color: statusColor, size: 20),
          const SizedBox(width: 10),
          Text('Subscription', style: TextStyle(color: _textPri(context), fontWeight: FontWeight.w700, fontSize: 14)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12)),
            child: Text(isActive ? 'Active' : 'Inactive',
              style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        ]),
        const SizedBox(height: 8),
        Text(statusText, style: TextStyle(color: _textSec(context), fontSize: 13)),
        if (!isActive) ...[
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, AppRoutes.subscription),
            child: Container(
              height: 42, alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(12)),
              child: const Text('Retry Subscription',
                style: TextStyle(color: Color(0xFF1A1A1A), fontWeight: FontWeight.w700, fontSize: 13))),
          ),
        ],
      ]),
    );
  }
}
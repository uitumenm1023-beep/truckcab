import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_status.dart';
import '../../main.dart';
import '../../models/order_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/order_provider.dart';
import '../../routes/app_routes.dart';
import 'navigation_screen.dart';

bool _isDark(BuildContext ctx) => Theme.of(ctx).brightness == Brightness.dark;
Color _textPri(BuildContext ctx) => _isDark(ctx) ? const Color(0xFFF5F7FA) : const Color(0xFF1A1A2E);
Color _textSec(BuildContext ctx) => _isDark(ctx) ? const Color(0xFF98A1AE) : const Color(0xFF6B7280);
Color _soft(BuildContext ctx)    => _isDark(ctx) ? const Color(0xFF252A33) : const Color(0xFFF0F1F8);
Color _card(BuildContext ctx)    => _isDark(ctx) ? const Color(0xFF1B1F26) : const Color(0xFFFFFFFF);
Color _bg(BuildContext ctx)      => _isDark(ctx) ? const Color(0xFF101216) : const Color(0xFFF2F3F8);
Color _border(BuildContext ctx)  => _isDark(ctx) ? const Color(0x14FFFFFF) : const Color(0xFFE5E7EB);

const Color _purple  = Color(0xFF7B6CF6);
const Color _purpleL = Color(0xFFEDE9FE);
const Color _orange  = Color(0xFFFF5A1F);
const Color _green   = Color(0xFF22C55E);

// ── Open Google Maps navigation ───────────────────────────────────────────────
Future<void> _openDirections({
  double? lat,
  double? lng,
  required String address,
}) async {
  Uri uri;
  if (lat != null && lng != null) {
    uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving');
  } else {
    final encoded = Uri.encodeComponent(address);
    uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$encoded&travelmode=driving');
  }
  if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    // fallback to geo: scheme
    final fallback = lat != null && lng != null
        ? Uri.parse('geo:$lat,$lng?q=$lat,$lng')
        : Uri.parse('geo:0,0?q=${Uri.encodeComponent(address)}');
    await launchUrl(fallback);
  }
}

// ── Vehicle helpers ────────────────────────────────────────────────────────────
String _vehicleEmoji(String type) {
  switch (type) {
    case 'suv':          return '🚙';
    case 'small_truck':  return '🚚';
    case 'medium_truck': return '🚛';
    case 'big_truck':    return '🚜';
    default:             return '🚗';
  }
}

String _vehicleLabel(String type) {
  switch (type) {
    case 'suv':          return 'SUV';
    case 'small_truck':  return 'Small Truck';
    case 'medium_truck': return 'Medium Truck';
    case 'big_truck':    return 'Big Truck';
    default:             return 'Vehicle';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});
  @override State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final uid = context.read<AppAuthProvider>().currentUserId;
      context.read<OrderProvider>().startAvailableOrdersListener();
      if (uid != null && uid.isNotEmpty) {
        context.read<OrderProvider>().startDriverActiveOrderListener(driverId: uid);
        context.read<NotificationProvider>().startNotificationsListener(uid);
      }
    });
  }

  @override
  void dispose() {
    try {
      context.read<OrderProvider>().stopAvailableOrdersListener();
      context.read<OrderProvider>().stopDriverActiveOrderListener();
      context.read<NotificationProvider>().stopNotificationsListener();
    } catch (_) {}
    super.dispose();
  }

  Future<void> _logout() async {
    await context.read<AppAuthProvider>().logout();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, AppRoutes.login);
  }

  Future<void> _sendRequest(OrderModel order) async {
    final uid = context.read<AppAuthProvider>().currentUserId ?? '';
    if (uid.isEmpty) { _snack('Missing driver ID'); return; }
    final ok = await context.read<OrderProvider>().acceptOrder(orderId: order.id, driverId: uid);
    if (!mounted) return;
    if (ok) { _snack('Request sent — awaiting seller approval'); setState(() => _tab = 1); }
    else     { _snack(context.read<OrderProvider>().errorMessage ?? 'Failed'); }
  }

  Future<void> _updateStatus(OrderModel order, String status) async {
    final uid = context.read<AppAuthProvider>().currentUserId ?? '';
    if (uid.isEmpty) { _snack('Missing driver ID'); return; }
    final ok = await context.read<OrderProvider>().updateOrderStatus(orderId: order.id, driverId: uid, status: status);
    if (!mounted) return;
    if (ok) _snack('Status updated!');
    else    _snack(context.read<OrderProvider>().errorMessage ?? 'Update failed');
  }

  Future<void> _refresh() async {
    final uid = context.read<AppAuthProvider>().currentUserId;
    context.read<OrderProvider>().startAvailableOrdersListener();
    if (uid != null && uid.isNotEmpty) context.read<OrderProvider>().startDriverActiveOrderListener(driverId: uid);
    await Future.delayed(const Duration(milliseconds: 300));
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final auth    = context.watch<AppAuthProvider>();
    final profile = auth.currentUserProfile;

    final pages = [
      _HomeTab(profile: profile, onSendRequest: _sendRequest, onRefresh: _refresh),
      _ActiveTab(onUpdateStatus: _updateStatus, onRefresh: _refresh),
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
      (Icons.home_rounded,         Icons.home_outlined,          'Home'),
      (Icons.inventory_2_rounded,  Icons.inventory_2_outlined,   'Active'),
      (Icons.chat_bubble_rounded,  Icons.chat_bubble_outline,    'Chats'),
      (Icons.person_rounded,       Icons.person_outline_rounded, 'Profile'),
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
          final sel  = i == selected;
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
  final dynamic profile;
  final Future<void> Function(OrderModel) onSendRequest;
  final Future<void> Function() onRefresh;
  const _HomeTab({required this.profile, required this.onSendRequest, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final orders      = context.watch<OrderProvider>();
    final name        = profile?.displayName ?? 'Driver';
    final vehicle     = (profile?.vehicleType ?? '') as String;
    final isOnline    = profile?.isOnline ?? false;
    final activeOrders = orders.activeOrders;
    final dark        = _isDark(context);

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: _purple,
      backgroundColor: _card(context),
      child: CustomScrollView(slivers: [
        SliverToBoxAdapter(child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: dark
                  ? [const Color(0xFF171A20), const Color(0xFF101216)]
                  : [const Color(0xFFF2F3F8), const Color(0xFFEDE9FE)],
            ),
          ),
          padding: const EdgeInsets.fromLTRB(20, 58, 20, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Top row
            Row(children: [
              Container(width: 46, height: 46,
                decoration: BoxDecoration(
                  color: _purple.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: _purple.withOpacity(0.3))),
                child: Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'D',
                  style: const TextStyle(color: _purple, fontWeight: FontWeight.w700, fontSize: 20)))),
              const Spacer(),
              GestureDetector(
                onTap: () => context.toggleTheme(),
                child: _IconBtn(icon: dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined, context: context)),
              const SizedBox(width: 10),
              Builder(builder: (ctx) {
                final unread = ctx.watch<NotificationProvider>().unreadCount;
                return GestureDetector(
                  onTap: () => Navigator.pushNamed(context, AppRoutes.notifications),
                  child: Stack(clipBehavior: Clip.none, children: [
                    _IconBtn(icon: Icons.notifications_outlined, context: context),
                    if (unread > 0)
                      Positioned(right: 8, top: 8,
                        child: Container(width: 8, height: 8,
                          decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle))),
                  ]),
                );
              }),
            ]),
            const SizedBox(height: 24),
            // Greeting
            Text('Hello,', style: TextStyle(color: _textSec(context), fontSize: 16)),
            const SizedBox(height: 2),
            Text(name, style: TextStyle(color: _textPri(context), fontSize: 36, fontWeight: FontWeight.w300, height: 1.1)),
            const SizedBox(height: 16),
            // Online pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: isOnline ? _green.withOpacity(0.12) : _soft(context),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isOnline ? _green.withOpacity(0.35) : _border(context))),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: isOnline ? _green : _textSec(context))),
                const SizedBox(width: 8),
                Text(isOnline ? 'Online' : 'Offline',
                  style: TextStyle(color: isOnline ? _green : _textSec(context), fontSize: 13, fontWeight: FontWeight.w600)),
              ]),
            ),
            const SizedBox(height: 24),
            // Driver card with vehicle
            _DriverVehicleCard(name: name, vehicle: vehicle, isOnline: isOnline),
            const SizedBox(height: 16),
            // Active delivery preview
            if (activeOrders.isNotEmpty) ...[
              _ActiveDeliveryPreview(order: activeOrders.first),
              const SizedBox(height: 16),
            ],
            const SizedBox(height: 8),
            Text('Available Orders', style: TextStyle(color: _textPri(context), fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('${orders.availableOrders.length} open near you', style: TextStyle(color: _textSec(context), fontSize: 13)),
            const SizedBox(height: 16),
          ]),
        )),
        orders.isLoading
            ? const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: _purple)))
            : orders.availableOrders.isEmpty
                ? SliverFillRemaining(child: Center(child: Text('No available orders', style: TextStyle(color: _textSec(context)))))
                : SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                    sliver: SliverList(delegate: SliverChildBuilderDelegate(
                      (ctx, i) => Padding(padding: const EdgeInsets.only(bottom: 12),
                        child: _AvailableOrderCard(order: orders.availableOrders[i], onSendRequest: onSendRequest)),
                      childCount: orders.availableOrders.length,
                    )),
                  ),
      ]),
    );
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

// ── Driver Vehicle Card ───────────────────────────────────────────────────────
class _DriverVehicleCard extends StatelessWidget {
  final String name, vehicle;
  final bool isOnline;
  const _DriverVehicleCard({required this.name, required this.vehicle, required this.isOnline});

  @override
  Widget build(BuildContext context) {
    final emoji = _vehicleEmoji(vehicle);
    final label = _vehicleLabel(vehicle);
    final dark  = _isDark(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: dark
              ? [const Color(0xFF1C1630), const Color(0xFF141828)]
              : [const Color(0xFFEDE9FE), const Color(0xFFDDD6FE)],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _purple.withOpacity(0.25)),
      ),
      child: Row(children: [
        // Avatar with online indicator
        Stack(clipBehavior: Clip.none, children: [
          Container(width: 58, height: 58,
            decoration: BoxDecoration(shape: BoxShape.circle,
              color: _purple.withOpacity(0.15),
              border: Border.all(color: isOnline ? _green.withOpacity(0.5) : _purple.withOpacity(0.3), width: 2)),
            child: Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'D',
              style: const TextStyle(color: _purple, fontSize: 24, fontWeight: FontWeight.w700)))),
          Positioned(right: 0, bottom: 0,
            child: Container(width: 14, height: 14,
              decoration: BoxDecoration(color: isOnline ? _green : const Color(0xFF9CA3AF),
                shape: BoxShape.circle, border: Border.all(color: dark ? const Color(0xFF1C1630) : _purpleL, width: 2)))),
        ]),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: TextStyle(color: _textPri(context), fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 3),
          Text('Driver · $label', style: TextStyle(color: _textSec(context), fontSize: 13)),
        ])),
        const SizedBox(width: 12),
        // Vehicle emoji badge
        Container(width: 64, height: 64,
          decoration: BoxDecoration(
            color: dark ? Colors.white.withOpacity(0.08) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _purple.withOpacity(0.2))),
          child: Center(child: Text(emoji, style: const TextStyle(fontSize: 34)))),
      ]),
    );
  }
}

// ── Active Delivery Preview ───────────────────────────────────────────────────
class _ActiveDeliveryPreview extends StatelessWidget {
  final OrderModel order;
  const _ActiveDeliveryPreview({required this.order});

  String get _statusLabel {
    switch (order.status) {
      case AppStatus.accepted:  return 'Accepted';
      case AppStatus.pickedUp:  return 'Picked Up';
      case AppStatus.onTheWay:  return 'On The Way';
      case AppStatus.delivered: return 'Delivered';
      default: return order.status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = _isDark(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF0F1A12) : const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _green.withOpacity(0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 10, height: 10, decoration: const BoxDecoration(color: _green, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text('Active Delivery', style: TextStyle(color: _green, fontSize: 13, fontWeight: FontWeight.w700)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: _orange.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
            child: Text(_statusLabel, style: const TextStyle(color: _orange, fontSize: 11, fontWeight: FontWeight.w700))),
        ]),
        const SizedBox(height: 12),
        Text(order.description, style: TextStyle(color: _textPri(context), fontWeight: FontWeight.w700, fontSize: 15),
          maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 8),
        Row(children: [
          Icon(Icons.my_location_outlined, color: _green, size: 13),
          const SizedBox(width: 4),
          Expanded(child: Text(order.pickupLocation, style: TextStyle(color: _textSec(context), fontSize: 12),
            maxLines: 1, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 12),
          Icon(Icons.flag_outlined, color: _orange, size: 13),
          const SizedBox(width: 4),
          Expanded(child: Text(order.dropoffLocation, style: TextStyle(color: _textSec(context), fontSize: 12),
            maxLines: 1, overflow: TextOverflow.ellipsis)),
        ]),
      ]),
    );
  }
}

// ── Available Order Card ──────────────────────────────────────────────────────
class _AvailableOrderCard extends StatelessWidget {
  final OrderModel order;
  final Future<void> Function(OrderModel) onSendRequest;
  const _AvailableOrderCard({required this.order, required this.onSendRequest});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: _card(context), borderRadius: BorderRadius.circular(24), border: Border.all(color: _border(context))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(order.description,
            style: TextStyle(color: _textPri(context), fontSize: 15, fontWeight: FontWeight.w700),
            maxLines: 2, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 12),
          Text('\$${order.price.toStringAsFixed(0)}',
            style: const TextStyle(color: _green, fontSize: 18, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _Pill(Icons.my_location_outlined, order.pickupLocation, context)),
          const SizedBox(width: 8),
          Expanded(child: _Pill(Icons.flag_outlined, order.dropoffLocation, context)),
        ]),
        const SizedBox(height: 14),
        GestureDetector(
          onTap: () => onSendRequest(order),
          child: Container(height: 48, alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _orange,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: _orange.withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 4))]),
            child: const Text('Send Delivery Request',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)))),
        const SizedBox(height: 8),
        Text('Seller must approve before delivery starts',
          style: TextStyle(color: _textSec(context), fontSize: 11)),
      ]),
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String label;
  final BuildContext context;
  const _Pill(this.icon, this.label, this.context);

  @override
  Widget build(BuildContext ctx) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(color: _soft(context), borderRadius: BorderRadius.circular(10)),
    child: Row(children: [
      Icon(icon, color: _textSec(context), size: 13),
      const SizedBox(width: 5),
      Expanded(child: Text(label, style: TextStyle(color: _textSec(context), fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis)),
    ]),
  );
}

// ── Active Orders Tab ─────────────────────────────────────────────────────────
class _ActiveTab extends StatelessWidget {
  final Future<void> Function(OrderModel, String) onUpdateStatus;
  final Future<void> Function() onRefresh;
  const _ActiveTab({required this.onUpdateStatus, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final orders = context.watch<OrderProvider>();
    return RefreshIndicator(
      onRefresh: onRefresh, color: _purple, backgroundColor: _card(context),
      child: CustomScrollView(slivers: [
        SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 58, 20, 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Active Orders', style: TextStyle(color: _textPri(context), fontSize: 28, fontWeight: FontWeight.w700)),
            Text('${orders.activeOrders.length} in progress', style: TextStyle(color: _textSec(context), fontSize: 14)),
          ]),
        )),
        orders.isLoading
            ? const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: _purple)))
            : orders.activeOrders.isEmpty
                ? SliverFillRemaining(child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.inventory_2_outlined, color: _textSec(context), size: 48),
                    const SizedBox(height: 12),
                    Text('No active orders', style: TextStyle(color: _textSec(context), fontSize: 15)),
                  ])))
                : SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                    sliver: SliverList(delegate: SliverChildBuilderDelegate(
                      (ctx, i) => Padding(padding: const EdgeInsets.only(bottom: 14),
                        child: _ActiveOrderCard(order: orders.activeOrders[i], onUpdateStatus: onUpdateStatus)),
                      childCount: orders.activeOrders.length,
                    )),
                  ),
      ]),
    );
  }
}

class _ActiveOrderCard extends StatelessWidget {
  final OrderModel order;
  final Future<void> Function(OrderModel, String) onUpdateStatus;
  const _ActiveOrderCard({required this.order, required this.onUpdateStatus});

  String get _chatId => '${order.id}_${order.sellerId}_${order.driverId ?? ''}';

  Color _sc() {
    switch (order.status) {
      case AppStatus.accepted:  return _purple;
      case AppStatus.pickedUp:  return const Color(0xFF3B82F6);
      case AppStatus.onTheWay:  return _orange;
      default: return const Color(0xFF98A1AE);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: _card(context), borderRadius: BorderRadius.circular(24), border: Border.all(color: _border(context))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(order.description, style: TextStyle(color: _textPri(context), fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text('${order.pickupLocation} → ${order.dropoffLocation}',
          style: TextStyle(color: _textSec(context), fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 8),
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: _sc().withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
            child: Text(order.status, style: TextStyle(color: _sc(), fontSize: 12, fontWeight: FontWeight.w700))),
          const Spacer(),
          Text('\$${order.price.toStringAsFixed(0)}',
            style: const TextStyle(color: _green, fontSize: 16, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 14),
        // Directions button — pickup until picked up, then dropoff
        _DirectionsButton(order: order),
        const SizedBox(height: 10),
        // Chat button
        _DriverChatButton(order: order, chatId: _chatId),
        const SizedBox(height: 12),
        // Status buttons
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (order.status == AppStatus.accepted)
            _StatusBtn('Picked Up 📦', _green, () => onUpdateStatus(order, AppStatus.pickedUp)),
          if (order.status == AppStatus.pickedUp)
            _StatusBtn('On The Way 🚛', _purple, () => onUpdateStatus(order, AppStatus.onTheWay)),
          if (order.status == AppStatus.onTheWay)
            _StatusBtn('Delivered ✓', _orange, () => onUpdateStatus(order, AppStatus.delivered)),
        ]),
      ]),
    );
  }
}

class _StatusBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _StatusBtn(this.label, this.color, this.onTap);

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.35))),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13))),
  );
}

// ── Directions Button ─────────────────────────────────────────────────────────
class _DirectionsButton extends StatelessWidget {
  final OrderModel order;
  const _DirectionsButton({required this.order});

  bool get _goToPickup =>
      order.status == AppStatus.accepted;

  @override
  Widget build(BuildContext context) {
    final toPickup = _goToPickup;
    final label    = toPickup ? 'Navigate to Pickup' : 'Navigate to Dropoff';
    final icon     = toPickup ? Icons.my_location_rounded : Icons.flag_rounded;
    final color    = toPickup ? _green : _orange;
    final address  = toPickup ? order.pickupLocation : order.dropoffLocation;
    final lat      = toPickup ? order.pickupLat  : order.dropoffLat;
    final lng      = toPickup ? order.pickupLng  : order.dropoffLng;

    return GestureDetector(
      onTap: () {
        if (lat != null && lng != null) {
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => NavigationScreen(order: order, isPickup: toPickup)));
        } else {
          _openDirections(lat: lat, lng: lng, address: address);
        }
      },
      child: Container(
        height: 44, alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.35))),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Text(label,
            style: TextStyle(
              color: color, fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(width: 6),
          Icon(Icons.navigation_rounded, color: color, size: 14),
        ])),
    );
  }
}

class _DriverChatButton extends StatelessWidget {
  final OrderModel order;
  final String chatId;
  const _DriverChatButton({required this.order, required this.chatId});

  @override
  Widget build(BuildContext context) {
    final driverId = order.driverId ?? '';
    if (driverId.isEmpty) return const SizedBox.shrink();
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('chat_requests').doc(chatId).snapshots(),
      builder: (ctx, snap) {
        final data   = snap.data?.data();
        final map    = data is Map<String, dynamic> ? data : <String, dynamic>{};
        final status = (map['status'] ?? '').toString();
        if (!snap.hasData || !snap.data!.exists || status == 'pending') {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: _soft(context), borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              Icon(Icons.hourglass_empty_rounded, color: _textSec(context), size: 16),
              const SizedBox(width: 8),
              Text('Waiting for seller approval', style: TextStyle(color: _textSec(context), fontSize: 13)),
            ]));
        }
        if (status == 'rejected') {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
            child: const Row(children: [
              Icon(Icons.cancel_outlined, color: Colors.redAccent, size: 16),
              SizedBox(width: 8),
              Text('Seller rejected the request', style: TextStyle(color: Colors.redAccent, fontSize: 13)),
            ]));
        }
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('chats').doc(chatId).snapshots(),
          builder: (ctx2, cs) {
            if (!(cs.data?.exists ?? false)) {
              return Text('Preparing chat…', style: TextStyle(color: _textSec(context), fontSize: 13));
            }
            return GestureDetector(
              onTap: () => Navigator.pushNamed(ctx, AppRoutes.chatScreen,
                arguments: ChatScreenArgs(chatId: chatId, title: order.description)),
              child: Container(height: 44, alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
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

// ── Chats Tab ─────────────────────────────────────────────────────────────────
class _ChatsTab extends StatelessWidget {
  const _ChatsTab();

  @override
  Widget build(BuildContext context) => Center(
    child: GestureDetector(
      onTap: () => Navigator.pushNamed(context, AppRoutes.chatList),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: BoxDecoration(
          color: _card(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _purple.withOpacity(0.4))),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.chat_bubble_outline, color: _purple),
          SizedBox(width: 10),
          Text('Open Chats', style: TextStyle(color: _purple, fontWeight: FontWeight.w700, fontSize: 15)),
        ]))));
}

// ── Profile Tab ───────────────────────────────────────────────────────────────
class _ProfileTab extends StatelessWidget {
  final Future<void> Function() onLogout;
  const _ProfileTab({required this.onLogout});

  @override
  Widget build(BuildContext context) {
    final auth    = context.watch<AppAuthProvider>();
    final profile = auth.currentUserProfile;
    final name    = profile?.displayName ?? 'Driver';
    final email   = auth.currentUserEmail ?? '';
    final vehicle = (profile?.vehicleType ?? '') as String;
    final years   = profile?.yearsExperience ?? 0;
    final online  = profile?.isOnline ?? false;
    final dark    = _isDark(context);
    final isAdmin = profile?.isAdmin ?? false;

    return CustomScrollView(slivers: [
      SliverToBoxAdapter(child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 58, 20, 32),
        child: Column(children: [
          Container(width: 90, height: 90,
            decoration: BoxDecoration(shape: BoxShape.circle, color: _purple.withOpacity(0.15),
              border: Border.all(color: online ? _green.withOpacity(0.5) : _purple.withOpacity(0.3), width: 2)),
            child: Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'D',
              style: const TextStyle(color: _purple, fontSize: 36, fontWeight: FontWeight.w700)))),
          const SizedBox(height: 14),
          Text(name, style: TextStyle(color: _textPri(context), fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(email, style: TextStyle(color: _textSec(context), fontSize: 13)),
          const SizedBox(height: 28),
          _tile(context, '${_vehicleEmoji(vehicle)} Vehicle', _vehicleLabel(vehicle)),
          const SizedBox(height: 10),
          _tile(context, '🕐 Experience', '$years year${years != 1 ? 's' : ''}'),
          const SizedBox(height: 10),
          _tile(context, '⚡ Status', online ? 'Online' : 'Offline', valueColor: online ? _green : _textSec(context)),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => context.toggleTheme(),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: _card(context), borderRadius: BorderRadius.circular(18), border: Border.all(color: _border(context))),
              child: Row(children: [
                Icon(dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined, color: _purple, size: 20),
                const SizedBox(width: 14),
                Text(dark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
                  style: TextStyle(color: _textPri(context), fontWeight: FontWeight.w600, fontSize: 14)),
                const Spacer(),
                Icon(Icons.chevron_right, color: _textSec(context), size: 18),
              ]),
            ),
          ),
          if (isAdmin) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => Navigator.pushNamed(context, AppRoutes.admin),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: _card(context), borderRadius: BorderRadius.circular(18), border: Border.all(color: _border(context))),
                child: Row(children: [
                  const Icon(Icons.admin_panel_settings_outlined, color: _orange, size: 20),
                  const SizedBox(width: 14),
                  Text('Admin Panel', style: TextStyle(color: _textPri(context), fontWeight: FontWeight.w600, fontSize: 14)),
                  const Spacer(),
                  Icon(Icons.chevron_right, color: _textSec(context), size: 18),
                ]),
              ),
            ),
          ],
          // TEMPORARY — remove after tapping once
          if (!isAdmin) ...[
            const SizedBox(height: 10),
            Builder(builder: (ctx) {
              final uid = ctx.watch<AppAuthProvider>().currentUserId ?? '';
              return GestureDetector(
                onTap: () async {
                  if (uid.isEmpty) return;
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(uid)
                      .update({'isAdmin': true});
                  if (!ctx.mounted) return;
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Admin enabled — please restart the app')));
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _card(ctx),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: _purple.withOpacity(0.4))),
                  child: Row(children: [
                    Icon(Icons.lock_open_rounded, color: _purple, size: 20),
                    const SizedBox(width: 14),
                    Text('Become Admin (tap once)',
                      style: TextStyle(color: _textPri(ctx), fontWeight: FontWeight.w600, fontSize: 14)),
                    const Spacer(),
                    Icon(Icons.chevron_right, color: _textSec(ctx), size: 18),
                  ]),
                ),
              );
            }),
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

  Widget _tile(BuildContext ctx, String label, String value, {Color? valueColor}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _card(ctx), borderRadius: BorderRadius.circular(18), border: Border.all(color: _border(ctx))),
      child: Row(children: [
        Text(label, style: TextStyle(color: _textSec(ctx), fontSize: 14)),
        const Spacer(),
        Text(value, style: TextStyle(color: valueColor ?? _textPri(ctx), fontWeight: FontWeight.w700, fontSize: 14)),
      ]),
    );
  }
}
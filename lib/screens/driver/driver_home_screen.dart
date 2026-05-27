import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_status.dart';
import '../../models/order_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/order_provider.dart';
import '../../routes/app_routes.dart';
import 'navigation_screen.dart';

bool _isDark(BuildContext ctx) => Theme.of(ctx).brightness == Brightness.dark;
Color _accent(BuildContext ctx) => _isDark(ctx) ? const Color(0xFF89F336) : const Color(0xFF4F7C82);
Color _textPri(BuildContext ctx) => _isDark(ctx) ? const Color(0xFFF5F7FA) : const Color(0xFF1A2B2D);
Color _textSec(BuildContext ctx) => _isDark(ctx) ? const Color(0xFF98A1AE) : const Color(0xFF2A4A50);
Color _soft(BuildContext ctx)    => _isDark(ctx) ? const Color(0xFF3A3A3A) : const Color(0xFF7FA3A7);
Color _card(BuildContext ctx)    => _isDark(ctx) ? const Color(0xFF2C2C2C) : const Color(0xFFB5CDD0);
Color _bg(BuildContext ctx)      => _isDark(ctx) ? const Color(0xFF1E1E1E) : const Color(0xFF93B1B5);
Color _border(BuildContext ctx)  => _isDark(ctx) ? const Color(0x14B5CDD0) : const Color(0xFF5E8A8F);


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
  Position? _driverPosition;

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
        context.read<ChatProvider>().startChatsListener(uid);
      }
    });
    _fetchDriverLocation();
  }

  Future<void> _fetchDriverLocation() async {
    // Geolocator web support is unreliable on Chrome — skip to avoid freeze.
    if (kIsWeb) return;
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final requested = await Geolocator.requestPermission();
        if (requested == LocationPermission.denied || requested == LocationPermission.deniedForever) return;
      }
      if (permission == LocationPermission.deniedForever) return;
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      ).timeout(const Duration(seconds: 10), onTimeout: () => throw Exception('timeout'));
      if (mounted) setState(() => _driverPosition = pos);
    } catch (_) {}
  }

  @override
  void dispose() {
    try {
      context.read<OrderProvider>().stopAvailableOrdersListener();
      context.read<OrderProvider>().stopDriverActiveOrderListener();
      context.read<NotificationProvider>().stopNotificationsListener();
      context.read<ChatProvider>().stopChatsListener();
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
      _HomeTab(profile: profile, onSendRequest: _sendRequest, onRefresh: _refresh, driverPosition: _driverPosition),
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
    final accent = _accent(context);
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
  final dynamic profile;
  final Future<void> Function(OrderModel) onSendRequest;
  final Future<void> Function() onRefresh;
  final Position? driverPosition;
  const _HomeTab({required this.profile, required this.onSendRequest, required this.onRefresh, this.driverPosition});

  @override
  Widget build(BuildContext context) {
    final accent      = _accent(context);
    final orders      = context.watch<OrderProvider>();
    final name        = profile?.displayName ?? 'Driver';
    final vehicle     = (profile?.vehicleType ?? '') as String;
    final isOnline    = profile?.isOnline ?? false;
    final activeOrders = orders.activeOrders;
    final dark        = _isDark(context);

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: accent,
      backgroundColor: _card(context),
      child: CustomScrollView(slivers: [
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
              Container(width: 46, height: 46,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: accent.withOpacity(0.3))),
                child: Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'D',
                  style: TextStyle(color: accent, fontWeight: FontWeight.w700, fontSize: 20)))),
              const Spacer(),
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
                color: isOnline ? accent.withOpacity(0.12) : _soft(context),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isOnline ? accent.withOpacity(0.35) : _border(context))),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: isOnline ? accent : _textSec(context))),
                const SizedBox(width: 8),
                Text(isOnline ? 'Online' : 'Offline',
                  style: TextStyle(color: isOnline ? accent : _textSec(context), fontSize: 13, fontWeight: FontWeight.w600)),
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
            ? SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: accent)))
            : orders.availableOrders.isEmpty
                ? SliverFillRemaining(child: Center(child: Text('No available orders', style: TextStyle(color: _textSec(context)))))
                : SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                    sliver: SliverList(delegate: SliverChildBuilderDelegate(
                      (ctx, i) => Padding(padding: const EdgeInsets.only(bottom: 12),
                        child: _AvailableOrderCard(order: orders.availableOrders[i], onSendRequest: onSendRequest, driverPosition: driverPosition)),
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
    final accent = _accent(context);
    final emoji = _vehicleEmoji(vehicle);
    final label = _vehicleLabel(vehicle);
    final dark  = _isDark(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: dark
              ? [const Color(0xFF252525), const Color(0xFF1F1F1F)]
              : [const Color(0xFFE5FFD0), const Color(0xFFDDD6FE)],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: accent.withOpacity(0.25)),
      ),
      child: Row(children: [
        // Avatar with online indicator
        Stack(clipBehavior: Clip.none, children: [
          Container(width: 58, height: 58,
            decoration: BoxDecoration(shape: BoxShape.circle,
              color: accent.withOpacity(0.15),
              border: Border.all(color: isOnline ? accent.withOpacity(0.5) : accent.withOpacity(0.3), width: 2)),
            child: Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'D',
              style: TextStyle(color: accent, fontSize: 24, fontWeight: FontWeight.w700)))),
          Positioned(right: 0, bottom: 0,
            child: Container(width: 14, height: 14,
              decoration: BoxDecoration(color: isOnline ? accent : const Color(0xFF9CA3AF),
                shape: BoxShape.circle, border: Border.all(color: dark ? const Color(0xFF252525) : accent.withOpacity(0.15), width: 2)))),
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
            border: Border.all(color: accent.withOpacity(0.2))),
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
    const bg = Color(0xFF89F336);
    const dark = Color(0xFF1A1A1A);
    const darkMid = Color(0xFF2D2D2D);
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 10, height: 10, decoration: const BoxDecoration(color: dark, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          const Text('Active Delivery', style: TextStyle(color: dark, fontSize: 15, fontWeight: FontWeight.w800)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: Colors.black.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
            child: Text(_statusLabel, style: const TextStyle(color: dark, fontSize: 12, fontWeight: FontWeight.w700))),
        ]),
        const SizedBox(height: 14),
        Text(order.description, style: const TextStyle(color: dark, fontWeight: FontWeight.w800, fontSize: 17),
          maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 10),
        Row(children: [
          const Icon(Icons.my_location_outlined, color: darkMid, size: 14),
          const SizedBox(width: 4),
          Expanded(child: Text(order.pickupLocation, style: const TextStyle(color: darkMid, fontSize: 12),
            maxLines: 1, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 12),
          const Icon(Icons.flag_outlined, color: darkMid, size: 14),
          const SizedBox(width: 4),
          Expanded(child: Text(order.dropoffLocation, style: const TextStyle(color: darkMid, fontSize: 12),
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
  final Position? driverPosition;
  const _AvailableOrderCard({required this.order, required this.onSendRequest, this.driverPosition});

  String? _distanceLabel() {
    final pos = driverPosition;
    final lat = order.pickupLat;
    final lng = order.pickupLng;
    if (pos == null || lat == null || lng == null) return null;
    final meters = Geolocator.distanceBetween(pos.latitude, pos.longitude, lat, lng);
    if (meters < 1000) return '${meters.round()} m to pickup';
    return '${(meters / 1000).toStringAsFixed(1)} km to pickup';
  }

  void _showDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _OrderDetailSheet(order: order, onSendRequest: onSendRequest),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accent(context);
    final hasPhotos = order.imageUrls.isNotEmpty;
    return GestureDetector(
      onTap: () => _showDetails(context),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _card(context),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _border(context)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Photo thumbnails strip
          if (hasPhotos) ...[
            SizedBox(
              height: 110,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const ClampingScrollPhysics(),
                itemCount: order.imageUrls.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.network(
                    order.imageUrls[i],
                    width: 110, height: 110, fit: BoxFit.cover,
                    loadingBuilder: (_, child, progress) => progress == null
                        ? child
                        : Container(width: 110, height: 110, color: _soft(context),
                            child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: accent))),
                    errorBuilder: (_, __, ___) => Container(width: 110, height: 110, color: _soft(context),
                      child: Icon(Icons.broken_image_outlined, color: _textSec(context))),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          // Description + price
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Text(order.description,
              style: TextStyle(color: _textPri(context), fontSize: 15, fontWeight: FontWeight.w700),
              maxLines: 3, overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 12),
            Text('₮${order.price.toStringAsFixed(0)}',
              style: TextStyle(color: accent, fontSize: 18, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 12),
          // Pickup
          _LocationRow(
            icon: Icons.my_location_outlined, label: 'Pickup',
            address: order.pickupLocation, color: accent, context: context),
          const SizedBox(height: 8),
          // Dropoff
          _LocationRow(
            icon: Icons.flag_outlined, label: 'Dropoff',
            address: order.dropoffLocation, color: accent, context: context),
          const SizedBox(height: 8),
          // Distance badge + tap hint
          Row(children: [
            Builder(builder: (_) {
              final dist = _distanceLabel();
              if (dist == null) return const SizedBox.shrink();
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: accent.withOpacity(0.25))),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.near_me_rounded, color: accent, size: 12),
                  const SizedBox(width: 4),
                  Text(dist, style: TextStyle(color: accent, fontSize: 11, fontWeight: FontWeight.w700)),
                ]));
            }),
            const Spacer(),
            Text('Tap for full details',
              style: TextStyle(color: accent.withOpacity(0.65), fontSize: 11)),
            const SizedBox(width: 4),
            Icon(Icons.open_in_new_rounded, color: accent.withOpacity(0.65), size: 12),
          ]),
          const SizedBox(height: 12),
          // Request button — its own tap, won't trigger card tap
          GestureDetector(
            onTap: () => onSendRequest(order),
            child: Container(
              height: 48, alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: accent.withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 4))]),
              child: const Text('Send Delivery Request',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)))),
          const SizedBox(height: 8),
          Text('Seller must approve before delivery starts',
            style: TextStyle(color: _textSec(context), fontSize: 11)),
        ]),
      ),
    );
  }
}

// Shared location row used in card and detail sheet
class _LocationRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String address;
  final Color color;
  final BuildContext context;
  const _LocationRow({
    required this.icon, required this.label,
    required this.address, required this.color, required this.context,
  });

  @override
  Widget build(BuildContext ctx) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Container(
      width: 32, height: 32,
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
      child: Icon(icon, color: color, size: 16)),
    const SizedBox(width: 10),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(color: _textSec(context), fontSize: 11, fontWeight: FontWeight.w600)),
      const SizedBox(height: 1),
      Text(address, style: TextStyle(color: _textPri(context), fontSize: 13, fontWeight: FontWeight.w600)),
    ])),
  ]);
}

// ── Order Detail Bottom Sheet ─────────────────────────────────────────────────
class _OrderDetailSheet extends StatelessWidget {
  final OrderModel order;
  final Future<void> Function(OrderModel) onSendRequest;
  const _OrderDetailSheet({required this.order, required this.onSendRequest});

  Future<Map<String, String>> _fetchSellerInfo() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(order.sellerId).get();
      final data = doc.data() ?? {};
      final name  = (data['name'] ?? '').toString().trim();
      final email = (data['email'] ?? '').toString().trim();
      final phone = (data['phoneNumber'] ?? '').toString().trim();
      return {
        'name':  name.isNotEmpty ? name : (order.sellerName.isNotEmpty ? order.sellerName : email),
        'phone': phone,
      };
    } catch (_) {
      return {'name': order.sellerName, 'phone': ''};
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accent(context);
    final dark = _isDark(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      maxChildSize: 0.95,
      minChildSize: 0.45,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: _card(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4,
            decoration: BoxDecoration(
              color: _textSec(context).withOpacity(0.3),
              borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 4),
          Expanded(
            child: ListView(
              controller: controller,
              padding: EdgeInsets.fromLTRB(20, 12, 20, 24 + MediaQuery.of(context).padding.bottom),
              children: [
                // Header
                Row(children: [
                  Expanded(child: Text('Order Details',
                    style: TextStyle(color: _textPri(context), fontSize: 22, fontWeight: FontWeight.w700))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: accent.withOpacity(0.3))),
                    child: Text('₮${order.price.toStringAsFixed(0)}',
                      style: TextStyle(color: accent, fontSize: 20, fontWeight: FontWeight.w800))),
                ]),
                const SizedBox(height: 16),

                // Seller info
                FutureBuilder<Map<String, String>>(
                  future: _fetchSellerInfo(),
                  builder: (ctx, snap) {
                    final name  = snap.data?['name'] ?? order.sellerName;
                    final phone = snap.data?['phone'] ?? '';
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: dark ? const Color(0xFF3A3A3A) : const Color(0xFF7FA3A7),
                        borderRadius: BorderRadius.circular(16)),
                      child: Row(children: [
                        Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(color: accent.withOpacity(0.12), shape: BoxShape.circle),
                          child: Center(child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : 'S',
                            style: TextStyle(color: accent, fontWeight: FontWeight.w700, fontSize: 18)))),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(name.isNotEmpty ? name : 'Seller',
                            style: TextStyle(color: _textPri(context), fontWeight: FontWeight.w700, fontSize: 14)),
                          if (phone.isNotEmpty)
                            Text(phone,
                              style: TextStyle(color: _textSec(context), fontSize: 12)),
                        ])),
                        if (phone.isNotEmpty)
                          GestureDetector(
                            onTap: () => launchUrl(Uri.parse('tel:$phone')),
                            child: Container(
                              width: 38, height: 38,
                              decoration: BoxDecoration(color: accent.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                              child: Icon(Icons.phone_rounded, color: accent, size: 18))),
                      ]),
                    );
                  },
                ),
                const SizedBox(height: 16),

                // Photos
                if (order.imageUrls.isNotEmpty) ...[
                  Text('Photos (${order.imageUrls.length})',
                    style: TextStyle(color: _textSec(context), fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.4)),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 200,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: order.imageUrls.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (_, i) => ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(
                          order.imageUrls[i],
                          width: 220, height: 200, fit: BoxFit.cover,
                          loadingBuilder: (_, child, progress) => progress == null
                              ? child
                              : Container(width: 220, height: 200, color: _soft(context),
                                  child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: accent))),
                          errorBuilder: (_, __, ___) => Container(width: 220, height: 200, color: _soft(context),
                            child: Icon(Icons.broken_image_outlined, color: _textSec(context), size: 36)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Description
                Text('Package Description',
                  style: TextStyle(color: _textSec(context), fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.4)),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: dark ? const Color(0xFF3A3A3A) : const Color(0xFF7FA3A7),
                    borderRadius: BorderRadius.circular(16)),
                  child: Text(order.description,
                    style: TextStyle(color: _textPri(context), fontSize: 14, height: 1.55)),
                ),
                const SizedBox(height: 20),

                // Locations
                Text('Locations',
                  style: TextStyle(color: _textSec(context), fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.4)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: dark ? const Color(0xFF3A3A3A) : const Color(0xFF7FA3A7),
                    borderRadius: BorderRadius.circular(16)),
                  child: Column(children: [
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(width: 38, height: 38,
                        decoration: BoxDecoration(color: accent.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                        child: Icon(Icons.my_location_rounded, color: accent, size: 20)),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Pickup Location',
                          style: TextStyle(color: _textSec(context), fontSize: 11, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 3),
                        Text(order.pickupLocation,
                          style: TextStyle(color: _textPri(context), fontSize: 14, fontWeight: FontWeight.w600, height: 1.4)),
                      ])),
                    ]),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 8, 0, 8),
                      child: Row(children: [
                        Container(width: 2, height: 28,
                          decoration: BoxDecoration(
                            color: _textSec(context).withOpacity(0.25),
                            borderRadius: BorderRadius.circular(1))),
                      ]),
                    ),
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(width: 38, height: 38,
                        decoration: BoxDecoration(color: accent.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                        child: Icon(Icons.flag_rounded, color: accent, size: 20)),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Dropoff Location',
                          style: TextStyle(color: _textSec(context), fontSize: 11, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 3),
                        Text(order.dropoffLocation,
                          style: TextStyle(color: _textPri(context), fontSize: 14, fontWeight: FontWeight.w600, height: 1.4)),
                      ])),
                    ]),
                  ]),
                ),
                const SizedBox(height: 28),

                // Send request button
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    onSendRequest(order);
                  },
                  child: Container(
                    height: 56, alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [BoxShadow(color: accent.withOpacity(0.35), blurRadius: 16, offset: const Offset(0, 6))]),
                    child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.local_shipping_rounded, color: Colors.white, size: 20),
                      SizedBox(width: 10),
                      Text('Send Delivery Request',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                    ]))),
                const SizedBox(height: 10),
                Center(child: Text('Seller must approve before delivery starts',
                  style: TextStyle(color: _textSec(context), fontSize: 12))),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Active Orders Tab ─────────────────────────────────────────────────────────
class _ActiveTab extends StatelessWidget {
  final Future<void> Function(OrderModel, String) onUpdateStatus;
  final Future<void> Function() onRefresh;
  const _ActiveTab({required this.onUpdateStatus, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final accent = _accent(context);
    final orders = context.watch<OrderProvider>();
    return RefreshIndicator(
      onRefresh: onRefresh, color: accent, backgroundColor: _card(context),
      child: CustomScrollView(slivers: [
        SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 58, 20, 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Active Orders', style: TextStyle(color: _textPri(context), fontSize: 28, fontWeight: FontWeight.w700)),
            Text('${orders.activeOrders.length} in progress', style: TextStyle(color: _textSec(context), fontSize: 14)),
          ]),
        )),
        orders.isLoading
            ? SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: accent)))
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

  Color _sc(Color accent) {
    switch (order.status) {
      case AppStatus.accepted:  return accent;
      case AppStatus.pickedUp:  return const Color(0xFF3B82F6);
      case AppStatus.onTheWay:  return accent;
      default: return const Color(0xFF98A1AE);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accent(context);
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
            decoration: BoxDecoration(color: _sc(accent).withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
            child: Text(order.status, style: TextStyle(color: _sc(accent), fontSize: 12, fontWeight: FontWeight.w700))),
          const Spacer(),
          Text('\$${order.price.toStringAsFixed(0)}',
            style: TextStyle(color: accent, fontSize: 16, fontWeight: FontWeight.w800)),
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
            _StatusBtn('Picked Up 📦', accent, () => onUpdateStatus(order, AppStatus.pickedUp)),
          if (order.status == AppStatus.pickedUp)
            _StatusBtn('On The Way 🚛', accent, () => onUpdateStatus(order, AppStatus.onTheWay)),
          if (order.status == AppStatus.onTheWay)
            _StatusBtn('Delivered ✓', accent, () => onUpdateStatus(order, AppStatus.delivered)),
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
        color: color,
        borderRadius: BorderRadius.circular(14)),
      child: Text(label, style: const TextStyle(color: Color(0xFF1A1A1A), fontWeight: FontWeight.w700, fontSize: 13))),
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
    final accent   = _accent(context);
    final toPickup = _goToPickup;
    final label    = toPickup ? 'Navigate to Pickup' : 'Navigate to Dropoff';
    final icon     = toPickup ? Icons.my_location_rounded : Icons.flag_rounded;
    final color    = accent;
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
          color: color,
          borderRadius: BorderRadius.circular(14)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: const Color(0xFF1A1A1A), size: 16),
          const SizedBox(width: 8),
          Text(label,
            style: const TextStyle(
              color: Color(0xFF1A1A1A), fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(width: 6),
          const Icon(Icons.navigation_rounded, color: Color(0xFF1A1A1A), size: 14),
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
            final accent = _accent(ctx);
            return GestureDetector(
              onTap: () => Navigator.pushNamed(ctx, AppRoutes.chatScreen,
                arguments: ChatScreenArgs(chatId: chatId, title: order.description)),
              child: Container(height: 44, alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(14)),
                child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.chat_bubble_outline, color: Color(0xFF1A1A1A), size: 16),
                  SizedBox(width: 8),
                  Text('Open Chat', style: TextStyle(color: Color(0xFF1A1A1A), fontWeight: FontWeight.w700, fontSize: 13)),
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
  Widget build(BuildContext context) {
    final chat = context.watch<ChatProvider>();
    final uid  = context.watch<AppAuthProvider>().currentUserId ?? '';

    return CustomScrollView(slivers: [
      SliverToBoxAdapter(child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 58, 20, 20),
        child: Text('Chats', style: TextStyle(color: _textPri(context), fontSize: 28, fontWeight: FontWeight.w700)),
      )),
      chat.chats.isEmpty
          ? SliverFillRemaining(child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.chat_bubble_outline, color: _textSec(context), size: 48),
              const SizedBox(height: 12),
              Text('No active chats', style: TextStyle(color: _textSec(context), fontSize: 15)),
            ])))
          : SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              sliver: SliverList(delegate: SliverChildBuilderDelegate(
                (ctx, i) {
                  final doc      = chat.chats[i];
                  final data     = doc.data() as Map<String, dynamic>;
                  final sellerId = (data['sellerId'] ?? '').toString();
                  final driverId = (data['driverId'] ?? '').toString();
                  final otherId  = uid == sellerId ? driverId : sellerId;
                  final desc     = (data['orderDescription'] ?? 'Chat').toString();
                  final last     = (data['lastMessage'] ?? '').toString();
                  return Padding(padding: const EdgeInsets.only(bottom: 10),
                    child: _DriverChatTile(chatId: doc.id, otherUserId: otherId, description: desc, lastMessage: last));
                },
                childCount: chat.chats.length,
              )),
            ),
    ]);
  }
}

class _DriverChatTile extends StatelessWidget {
  final String chatId, otherUserId, description, lastMessage;
  const _DriverChatTile({required this.chatId, required this.otherUserId, required this.description, required this.lastMessage});

  @override
  Widget build(BuildContext context) {
    final accent = _accent(context);
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(otherUserId).snapshots(),
      builder: (ctx, snap) {
        final ud = snap.data?.data();
        final um = ud is Map<String, dynamic> ? ud : <String, dynamic>{};
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
    final name    = profile?.displayName ?? 'Driver';
    final email   = auth.currentUserEmail ?? '';
    final vehicle = profile?.vehicleType ?? '';
    final years   = profile?.yearsExperience ?? 0;
    final online  = profile?.isOnline ?? false;
    final isAdmin = profile?.isAdmin ?? false;

    return CustomScrollView(slivers: [
      SliverToBoxAdapter(child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 58, 20, 32),
        child: Column(children: [
          Container(width: 90, height: 90,
            decoration: BoxDecoration(shape: BoxShape.circle, color: accent.withOpacity(0.15),
              border: Border.all(color: online ? accent.withOpacity(0.5) : accent.withOpacity(0.3), width: 2)),
            child: Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'D',
              style: TextStyle(color: accent, fontSize: 36, fontWeight: FontWeight.w700)))),
          const SizedBox(height: 14),
          Text(name, style: TextStyle(color: _textPri(context), fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(email, style: TextStyle(color: _textSec(context), fontSize: 13)),
          const SizedBox(height: 28),
          _tile(context, '${_vehicleEmoji(vehicle)} Vehicle', _vehicleLabel(vehicle)),
          const SizedBox(height: 10),
          _tile(context, '🕐 Experience', '$years year${years != 1 ? 's' : ''}'),
          const SizedBox(height: 10),
          _tile(context, '⚡ Status', online ? 'Online' : 'Offline', valueColor: online ? accent : _textSec(context)),
          const SizedBox(height: 16),
          _DriverSubscriptionCard(profile: profile),
          if (isAdmin) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => Navigator.pushNamed(context, AppRoutes.admin),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: _card(context), borderRadius: BorderRadius.circular(18), border: Border.all(color: _border(context))),
                child: Row(children: [
                  Icon(Icons.admin_panel_settings_outlined, color: accent, size: 20),
                  const SizedBox(width: 14),
                  Text('Admin Panel', style: TextStyle(color: _textPri(context), fontWeight: FontWeight.w600, fontSize: 14)),
                  const Spacer(),
                  Icon(Icons.chevron_right, color: _textSec(context), size: 18),
                ]),
              ),
            ),
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

// ── Driver Subscription Card ──────────────────────────────────────────────────
class _DriverSubscriptionCard extends StatelessWidget {
  final dynamic profile;
  const _DriverSubscriptionCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF89F336);
    final expiry   = profile?.subscriptionExpiry as DateTime?;
    final isActive = profile?.isSubscriptionActive as bool? ?? false;
    final now      = DateTime.now();
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
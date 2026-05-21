import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_status.dart';
import '../../models/order_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/order_provider.dart';
import '../../routes/app_routes.dart';

bool _isDark(BuildContext ctx) => Theme.of(ctx).brightness == Brightness.dark;
Color _accent(BuildContext ctx) =>
    _isDark(ctx) ? const Color(0xFF89F336) : const Color(0xFF4F7C82);
Color _textPri(BuildContext ctx) =>
    _isDark(ctx) ? const Color(0xFFF5F7FA) : const Color(0xFF1A2B2D);
Color _textSec(BuildContext ctx) =>
    _isDark(ctx) ? const Color(0xFF98A1AE) : const Color(0xFF2A4A50);
Color _card(BuildContext ctx) =>
    _isDark(ctx) ? const Color(0xFF2C2C2C) : const Color(0xFFB5CDD0);
Color _bg(BuildContext ctx) =>
    _isDark(ctx) ? const Color(0xFF1E1E1E) : const Color(0xFF93B1B5);
Color _soft(BuildContext ctx) =>
    _isDark(ctx) ? const Color(0xFF3A3A3A) : const Color(0xFF7FA3A7);

// ── Status helpers ─────────────────────────────────────────────────────────────
int _stepOf(String status) {
  switch (status) {
    case AppStatus.open:      return 0;
    case AppStatus.accepted:  return 1;
    case AppStatus.pickedUp:  return 2;
    case AppStatus.onTheWay:  return 2;
    case AppStatus.delivered: return 3;
    default:                  return 0;
  }
}

String _statusLabel(String status) {
  switch (status) {
    case AppStatus.open:      return 'Open';
    case AppStatus.accepted:  return 'Accepted';
    case AppStatus.pickedUp:  return 'In Transit';
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
  // Return first meaningful segment (before comma or full string if short)
  final parts = addr.split(',');
  return parts.first.trim().isEmpty ? addr : parts.first.trim();
}

// ── Screen ─────────────────────────────────────────────────────────────────────
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
      if (uid != null && uid.isNotEmpty) {
        context.read<OrderProvider>().startSellerOrdersListener(sellerId: uid);
      }
    });
  }

  @override
  void dispose() {
    try { context.read<OrderProvider>().stopSellerOrdersListener(); } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accent(context);
    final orders = context.watch<OrderProvider>().sellerOrders;
    final loading = context.watch<OrderProvider>().isLoading;

    return Scaffold(
      backgroundColor: _bg(context),
      appBar: AppBar(
        backgroundColor: _card(context),
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _soft(context),
              borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.arrow_back_ios_new_rounded,
              color: _textPri(context), size: 16)),
        ),
        title: Text('My Shipments',
          style: TextStyle(
            color: _textPri(context),
            fontSize: 20, fontWeight: FontWeight.w700)),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20)),
            child: Text('${orders.length} orders',
              style: TextStyle(color: accent, fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: loading
          ? Center(child: CircularProgressIndicator(color: accent))
          : orders.isEmpty
              ? _EmptyState(accent: accent)
              : ListView.builder(
                  padding: EdgeInsets.fromLTRB(
                    16, 16, 16, 24 + MediaQuery.of(context).padding.bottom),
                  itemCount: orders.length,
                  itemBuilder: (ctx, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _OrderCard(
                      order: orders[i],
                      onTap: () => _showDetail(context, orders[i]),
                    ),
                  ),
                ),
    );
  }

  void _showDetail(BuildContext context, OrderModel order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PackageDetailSheet(order: order),
    );
  }
}

// ── Empty State ────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final Color accent;
  const _EmptyState({required this.accent});
  @override
  Widget build(BuildContext context) {
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 80, height: 80,
        decoration: BoxDecoration(
          color: accent.withOpacity(0.1),
          shape: BoxShape.circle),
        child: Icon(Icons.local_shipping_outlined, color: accent, size: 36)),
      const SizedBox(height: 16),
      Text('No shipments yet',
        style: TextStyle(color: _textPri(context),
          fontSize: 18, fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      Text('Create your first delivery order',
        style: TextStyle(color: _textSec(context), fontSize: 14)),
    ]));
  }
}

// ── Order Card ─────────────────────────────────────────────────────────────────
class _OrderCard extends StatelessWidget {
  final OrderModel order;
  final VoidCallback onTap;
  const _OrderCard({required this.order, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final accent  = _accent(context);
    final active  = _isActive(order.status);
    final delivered = order.status == AppStatus.delivered;
    final step    = _stepOf(order.status);

    // Active orders get a green-tinted card, delivered get a subtle look
    final cardColor = active
        ? (Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1E3520)
            : const Color(0xFFD4EDD6))
        : _card(context);
    final borderColor = active
        ? accent.withOpacity(0.6)
        : delivered
            ? accent.withOpacity(0.2)
            : Colors.transparent;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor, width: 1.5),
          boxShadow: active
              ? [BoxShadow(
                  color: accent.withOpacity(0.15),
                  blurRadius: 20, offset: const Offset(0, 6))]
              : null,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Top row: ORD id + status badge ───────────────────────────────
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

          // ── From / To ─────────────────────────────────────────────────────
          Row(children: [
            Expanded(child: _LocationCol(
              label: 'From',
              city: _cityOf(order.pickupLocation),
              textPri: _textPri(context),
              textSec: _textSec(context),
            )),
            Icon(Icons.arrow_forward_rounded,
              color: accent, size: 18),
            Expanded(child: _LocationCol(
              label: 'To',
              city: _cityOf(order.dropoffLocation),
              textPri: _textPri(context),
              textSec: _textSec(context),
              align: CrossAxisAlignment.end,
            )),
          ]),
          const SizedBox(height: 6),

          // ── Date + price ──────────────────────────────────────────────────
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

          // ── Progress tracker ──────────────────────────────────────────────
          _ProgressTracker(step: step, accent: accent, soft: _soft(context)),
        ]),
      ),
    );
  }
}

// ── Status badge ───────────────────────────────────────────────────────────────
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
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color.withOpacity(0.4))),
      child: Text(_statusLabel(status),
        style: TextStyle(
          color: _color,
          fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

// ── Location column ────────────────────────────────────────────────────────────
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
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: align, children: [
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
}

// ── Progress tracker ───────────────────────────────────────────────────────────
class _ProgressTracker extends StatelessWidget {
  final int step;   // 0–3
  final Color accent, soft;
  const _ProgressTracker({
    required this.step, required this.accent, required this.soft});

  static const _labels = ['Posted', 'Accepted', 'In Transit', 'Delivered'];

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Dots + lines
      Row(children: List.generate(4, (i) {
        final done = i <= step;
        final isLast = i == 3;
        return Expanded(child: Row(children: [
          // Dot
          Container(
            width: 12, height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done ? accent : soft,
              border: Border.all(
                color: done ? accent : soft.withOpacity(0.4),
                width: 1.5))),
          // Line
          if (!isLast)
            Expanded(child: Container(
              height: 2,
              color: i < step ? accent : soft.withOpacity(0.3))),
        ]));
      })),
      const SizedBox(height: 6),
      // Labels
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(4, (i) => Text(
          _labels[i],
          style: TextStyle(
            color: i <= step ? accent : soft,
            fontSize: 9.5, fontWeight: FontWeight.w600),
        ))),
    ]);
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
    final accent  = _accent(context);
    final dark    = _isDark(context);
    final step    = _stepOf(order.status);
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

          // Title bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: dark ? const Color(0xFF2C2C2C) : const Color(0xFFB5CDD0),
                    borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.arrow_back_ios_new_rounded,
                    color: _textPri(context), size: 14)),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text('Package Details',
                style: TextStyle(
                  color: _textPri(context),
                  fontSize: 18, fontWeight: FontWeight.w700))),
            ]),
          ),
          const SizedBox(height: 16),

          Expanded(child: ListView(
            controller: ctrl,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            children: [
              // ── Big header card ─────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      accent,
                      accent.withOpacity(0.7),
                    ]),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withOpacity(0.3),
                      blurRadius: 24, offset: const Offset(0, 8))
                  ]),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  // Icon + status
                  Row(children: [
                    Container(
                      width: 44, height: 44,
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
                          color: Colors.white,
                          fontSize: 12, fontWeight: FontWeight.w700))),
                  ]),
                  const SizedBox(height: 14),
                  const Text('ID Number',
                    style: TextStyle(
                      color: Colors.white70, fontSize: 11)),
                  const SizedBox(height: 2),
                  Text(_ordId(order.id),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20, fontWeight: FontWeight.w800,
                      letterSpacing: 1)),
                  const SizedBox(height: 16),
                  Container(
                    height: 1,
                    color: Colors.white.withOpacity(0.2)),
                  const SizedBox(height: 16),
                  const Text('Details Package',
                    style: TextStyle(
                      color: Colors.white70, fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5)),
                  const SizedBox(height: 10),
                  Row(children: [
                    _DetailItem(
                      label: 'Description',
                      value: order.description,
                      flex: 2),
                    const SizedBox(width: 16),
                    _DetailItem(
                      label: 'Status',
                      value: _statusLabel(order.status)),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    _DetailItem(
                      label: 'From',
                      value: _cityOf(order.pickupLocation),
                      flex: 2),
                    const SizedBox(width: 16),
                    _DetailItem(
                      label: 'To',
                      value: _cityOf(order.dropoffLocation)),
                  ]),
                  const SizedBox(height: 10),
                  _DetailItem(
                    label: 'Price',
                    value: '₮${order.price.toStringAsFixed(0)}'),
                ]),
              ),
              const SizedBox(height: 20),

              // ── Details Status section ──────────────────────────────────
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: dark ? const Color(0xFF2C2C2C) : const Color(0xFFB5CDD0),
                  borderRadius: BorderRadius.circular(20)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  Row(children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                      Text('Details Status',
                        style: TextStyle(
                          color: _textPri(context),
                          fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(_ordId(order.id),
                        style: TextStyle(
                          color: _textSec(context), fontSize: 11)),
                    ]),
                    const Spacer(),
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10)),
                      child: Icon(Icons.qr_code_rounded,
                        color: accent, size: 20)),
                  ]),
                  const SizedBox(height: 20),
                  _ProgressTracker(
                    step: step,
                    accent: accent,
                    soft: dark
                        ? const Color(0xFF3A3A3A)
                        : const Color(0xFF7FA3A7)),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                      Text('From',
                        style: TextStyle(
                          color: _textSec(context), fontSize: 10)),
                      Text(_cityOf(order.pickupLocation),
                        style: TextStyle(
                          color: _textPri(context),
                          fontWeight: FontWeight.w700, fontSize: 14)),
                    ]),
                    Column(crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                      Text('To',
                        style: TextStyle(
                          color: _textSec(context), fontSize: 10)),
                      Text(_cityOf(order.dropoffLocation),
                        style: TextStyle(
                          color: _textPri(context),
                          fontWeight: FontWeight.w700, fontSize: 14)),
                    ]),
                  ]),
                ]),
              ),
              const SizedBox(height: 14),

              // ── Driver / Chat section ────────────────────────────────────
              if (hasDriver)
                _DriverSection(order: order, chatId: _chatId, accent: accent)
              else
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: dark
                        ? const Color(0xFF2C2C2C)
                        : const Color(0xFFB5CDD0),
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
  final int flex;
  const _DetailItem({
    required this.label, required this.value, this.flex = 1});
  @override
  Widget build(BuildContext context) {
    return Expanded(flex: flex, child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
        style: const TextStyle(color: Colors.white70, fontSize: 10)),
      const SizedBox(height: 2),
      Text(value,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13, fontWeight: FontWeight.w700),
        maxLines: 2, overflow: TextOverflow.ellipsis),
    ]));
  }
}

// ── Driver section inside detail sheet ────────────────────────────────────────
class _DriverSection extends StatelessWidget {
  final OrderModel order;
  final String chatId;
  final Color accent;
  const _DriverSection({
    required this.order, required this.chatId, required this.accent});

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
          child: Column(children: [
            // Driver info
            Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.12),
                  shape: BoxShape.circle),
                child: Center(child: Text(
                  driverName.isNotEmpty ? driverName[0].toUpperCase() : 'D',
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.w700, fontSize: 16)))),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Delivery Partner',
                  style: TextStyle(color: _textSec(context), fontSize: 10)),
                Text(driverName,
                  style: TextStyle(
                    color: _textPri(context),
                    fontWeight: FontWeight.w700, fontSize: 14)),
                if (vehicle.isNotEmpty)
                  Text(vehicle.replaceAll('_', ' ').toUpperCase(),
                    style: TextStyle(
                      color: _textSec(context), fontSize: 11)),
              ])),
              // Chat + call buttons
              _IconBtn(
                icon: Icons.chat_bubble_outline_rounded,
                color: accent,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, AppRoutes.chatScreen,
                    arguments: ChatScreenArgs(
                      chatId: chatId,
                      title: order.description));
                }),
            ]),
          ]),
        );
      },
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: color, size: 18)),
    );
  }
}

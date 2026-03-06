import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_status.dart';
import '../../models/order_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/order_provider.dart';
import '../../routes/app_routes.dart';

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  int _selectedIndex = 0;

  static const Color _pageBackground = Color(0xFF111317);
  static const Color _pageBackgroundTop = Color(0xFF15181D);

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final authProvider = context.read<AuthProvider>();
      final orderProvider = context.read<OrderProvider>();
      final driverId = authProvider.currentUserId;

      orderProvider.startAvailableOrdersListener();

      if (driverId != null && driverId.isNotEmpty) {
        orderProvider.startDriverActiveOrderListener(driverId: driverId);
      }
    });
  }

  @override
  void dispose() {
    try {
      final orderProvider = context.read<OrderProvider>();
      orderProvider.stopAvailableOrdersListener();
      orderProvider.stopDriverActiveOrderListener();
    } catch (_) {}
    super.dispose();
  }

  void _goToTab(int index) {
    if (!mounted) return;
    if (_selectedIndex == index) return;

    FocusManager.instance.primaryFocus?.unfocus();

    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _logout() async {
    final authProvider = context.read<AuthProvider>();

    await authProvider.logout();

    if (!mounted) return;
    Navigator.pushReplacementNamed(context, AppRoutes.login);
  }

  Future<void> _acceptOrder(OrderModel order) async {
    final orderProvider = context.read<OrderProvider>();
    final authProvider = context.read<AuthProvider>();
    final driverId = authProvider.currentUserId;

    if (driverId == null || driverId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Driver account is missing an ID')),
      );
      return;
    }

    final success = await orderProvider.acceptOrder(
      orderId: _orderId(order),
      driverId: driverId,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order accepted')),
      );
      _goToTab(1);
    } else {
      final message = orderProvider.errorMessage ?? 'Failed to accept order';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<void> _updateStatus(OrderModel order, String status) async {
    final orderProvider = context.read<OrderProvider>();
    final authProvider = context.read<AuthProvider>();
    final driverId = authProvider.currentUserId;

    if (driverId == null || driverId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Driver account is missing an ID')),
      );
      return;
    }

    final success = await orderProvider.updateOrderStatus(
      orderId: _orderId(order),
      driverId: driverId,
      status: status,
    );

    if (!mounted) return;

    if (success) {
      String message = 'Order status updated';

      if (status == AppStatus.pickedUp) {
        message = 'Seller notified: package picked up';
      } else if (status == AppStatus.onTheWay) {
        message = 'Seller notified: driver is on the way';
      } else if (status == AppStatus.delivered) {
        message = 'Seller notified: package delivered';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } else {
      final message = orderProvider.errorMessage ?? 'Update failed';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<void> _refreshData() async {
    final authProvider = context.read<AuthProvider>();
    final orderProvider = context.read<OrderProvider>();
    final driverId = authProvider.currentUserId;

    orderProvider.startAvailableOrdersListener();

    if (driverId != null && driverId.isNotEmpty) {
      orderProvider.startDriverActiveOrderListener(driverId: driverId);
    }

    await Future.delayed(const Duration(milliseconds: 350));
  }

  Widget _buildBody() {
    return IndexedStack(
      index: _selectedIndex,
      children: [
        _DriverHomeTab(
          key: const PageStorageKey('driver_home_tab'),
          onOpenActiveOrders: () => _goToTab(1),
          onOpenAvailableOrders: () => _goToTab(2),
          onRefresh: _refreshData,
        ),
        _DriverActiveOrdersTab(
          key: const PageStorageKey('driver_active_orders_tab'),
          onUpdateStatus: _updateStatus,
          onRefresh: _refreshData,
        ),
        _DriverAvailableOrdersTab(
          key: const PageStorageKey('driver_available_orders_tab'),
          onAcceptOrder: _acceptOrder,
          onRefresh: _refreshData,
        ),
        _DriverProfileTab(
          key: const PageStorageKey('driver_profile_tab'),
          onLogout: _logout,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBackground,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _pageBackgroundTop,
              _pageBackground,
              Color(0xFF101216),
            ],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: _buildBody(),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: _AnimatedBottomNavigation(
          selectedIndex: _selectedIndex,
          onChanged: _goToTab,
        ),
      ),
    );
  }
}

/* ----------------------------- HOME TAB ----------------------------- */

class _DriverHomeTab extends StatelessWidget {
  final VoidCallback onOpenActiveOrders;
  final VoidCallback onOpenAvailableOrders;
  final Future<void> Function() onRefresh;

  const _DriverHomeTab({
    super.key,
    required this.onOpenActiveOrders,
    required this.onOpenAvailableOrders,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final orderProvider = context.watch<OrderProvider>();

    final activeOrders = _extractActiveOrders(orderProvider);
    final availableOrders = _extractAvailableOrders(orderProvider);

    final previewActive = activeOrders.isNotEmpty ? activeOrders.first : null;
    final previewAvailable =
        availableOrders.isNotEmpty ? availableOrders.first : null;

    return RefreshIndicator(
      color: const Color(0xFFFF5A1F),
      backgroundColor: const Color(0xFF1B1F26),
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
        children: [
          const _DriverTopHeader(),
          const SizedBox(height: 26),
          const Text(
            'We Deliver On\nTime',
            style: TextStyle(
              fontSize: 38,
              fontWeight: FontWeight.w300,
              height: 1.03,
              color: Color(0xFFF5F7FA),
            ),
          ),
          const SizedBox(height: 24),
          _PreviewCard(
            onTap: onOpenActiveOrders,
            title: 'Active Orders',
            tagText: previewActive == null
                ? 'Waiting'
                : _statusTagText(_orderStatus(previewActive)),
            child: previewActive == null
                ? const _EmptyPreviewContent(
                    title: 'No accepted order yet',
                    subtitle:
                        'Tap here to see accepted orders and update them to picked up, on the way, and delivered.',
                  )
                : Column(
                    children: [
                      _PreviewOrderRow(order: previewActive),
                      if (activeOrders.length > 1) ...[
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '+${activeOrders.length - 1} more active order(s)',
                            style: const TextStyle(
                              color: Color(0xFF98A1AE),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
          const SizedBox(height: 18),
          _PreviewCard(
            onTap: onOpenAvailableOrders,
            title: 'Available Orders',
            tagText: previewAvailable == null ? 'Empty' : 'Open',
            child: previewAvailable == null
                ? const _EmptyPreviewContent(
                    title: 'No available orders',
                    subtitle:
                        'Tap here to open the available orders section when new jobs arrive.',
                  )
                : Column(
                    children: [
                      _PreviewOrderRow(order: previewAvailable),
                      if (availableOrders.length > 1) ...[
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '+${availableOrders.length - 1} more available order(s)',
                            style: const TextStyle(
                              color: Color(0xFF98A1AE),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  static String _statusTagText(String status) {
    switch (status) {
      case AppStatus.accepted:
        return 'Accepted';
      case AppStatus.pickedUp:
        return 'Picked Up';
      case AppStatus.onTheWay:
        return 'On The Way';
      case AppStatus.delivered:
        return 'Delivered';
      default:
        return 'Open';
    }
  }
}

/* -------------------------- ACTIVE ORDERS TAB -------------------------- */

class _DriverActiveOrdersTab extends StatelessWidget {
  final Future<void> Function(OrderModel order, String status) onUpdateStatus;
  final Future<void> Function() onRefresh;

  const _DriverActiveOrdersTab({
    super.key,
    required this.onUpdateStatus,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final orderProvider = context.watch<OrderProvider>();
    final activeOrders = _extractActiveOrders(orderProvider);

    return RefreshIndicator(
      color: const Color(0xFFFF5A1F),
      backgroundColor: const Color(0xFF1B1F26),
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
        children: [
          const _SimpleHeader(title: 'Active Orders'),
          const SizedBox(height: 10),
          Text(
            '${activeOrders.length} active order(s)',
            style: const TextStyle(
              color: Color(0xFF98A1AE),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 24),
          if (activeOrders.isEmpty)
            const _DarkEmptySection(
              title: 'No accepted order',
              subtitle:
                  'Accepted deliveries show here. Drivers can update each order to picked up, on the way, and delivered.',
              icon: Icons.inventory_2_outlined,
            )
          else
            ...activeOrders.map(
              (order) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  children: [
                    _DetailedOrderCard(
                      title: _orderTitle(order),
                      order: order,
                      accentText: _statusText(_orderStatus(order)),
                    ),
                    const SizedBox(height: 14),
                    _StatusTimeline(order: order),
                    const SizedBox(height: 14),
                    _StatusActionSection(
                      order: order,
                      onUpdateStatus: onUpdateStatus,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  static String _statusText(String status) {
    switch (status) {
      case AppStatus.accepted:
        return 'Accepted';
      case AppStatus.pickedUp:
        return 'Picked Up';
      case AppStatus.onTheWay:
        return 'On The Way';
      case AppStatus.delivered:
        return 'Delivered';
      default:
        return 'Active';
    }
  }
}

/* ------------------------- AVAILABLE ORDERS TAB ------------------------- */

class _DriverAvailableOrdersTab extends StatelessWidget {
  final Future<void> Function(OrderModel order) onAcceptOrder;
  final Future<void> Function() onRefresh;

  const _DriverAvailableOrdersTab({
    super.key,
    required this.onAcceptOrder,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final orderProvider = context.watch<OrderProvider>();
    final availableOrders = _extractAvailableOrders(orderProvider);

    return RefreshIndicator(
      color: const Color(0xFFFF5A1F),
      backgroundColor: const Color(0xFF1B1F26),
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
        children: [
          const _SimpleHeader(title: 'Available Orders'),
          const SizedBox(height: 10),
          Text(
            '${availableOrders.length} available order(s)',
            style: const TextStyle(
              color: Color(0xFF98A1AE),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 24),
          if (availableOrders.isEmpty)
            const _DarkEmptySection(
              title: 'No available orders',
              subtitle:
                  'All available orders that drivers can accept will appear here.',
              icon: Icons.local_shipping_outlined,
            )
          else
            ...availableOrders.map(
              (order) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _DetailedOrderCard(
                  title: _orderTitle(order),
                  order: order,
                  accentText: 'Open',
                  showAcceptButton: true,
                  onAccept: () => onAcceptOrder(order),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/* ----------------------------- PROFILE TAB ----------------------------- */

class _DriverProfileTab extends StatelessWidget {
  final Future<void> Function() onLogout;

  const _DriverProfileTab({
    super.key,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final email = authProvider.currentUserEmail ?? 'driver@truckcab.com';

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
      children: [
        const _SimpleHeader(title: 'Profile'),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: const Color(0xFF1B1F26),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0x14FFFFFF)),
          ),
          child: Column(
            children: [
              Container(
                width: 82,
                height: 82,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF2A2F37),
                ),
                child: const Icon(
                  Icons.person,
                  size: 42,
                  color: Color(0xFFF5F7FA),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Driver Account',
                style: TextStyle(
                  color: Color(0xFFF5F7FA),
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                email,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF98A1AE),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 22),
              const _ProfileTile(
                icon: Icons.badge_outlined,
                title: 'Role',
                value: 'Driver',
              ),
              const SizedBox(height: 12),
              const _ProfileTile(
                icon: Icons.local_shipping_outlined,
                title: 'Service',
                value: 'TruckCab',
              ),
              const SizedBox(height: 12),
              const _ProfileTile(
                icon: Icons.circle_notifications_outlined,
                title: 'Status',
                value: 'Online',
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onLogout,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF5A1F),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: const Text(
                    'Logout',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/* ------------------------ BOTTOM NAVIGATION ------------------------ */

class _AnimatedBottomNavigation extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const _AnimatedBottomNavigation({
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        height: 76,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF1B1F26),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0x12FFFFFF)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x4D000000),
              blurRadius: 24,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final fullWidth = constraints.maxWidth;
            final itemWidth = fullWidth / 4;
            final bubbleLeft = itemWidth * selectedIndex;

            return Stack(
              fit: StackFit.expand,
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  left: bubbleLeft,
                  top: 0,
                  bottom: 0,
                  width: itemWidth,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF5A1F),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x66FF5A1F),
                            blurRadius: 18,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Row(
                  children: [
                    _NavItem(
                      icon: Icons.home_filled,
                      isSelected: selectedIndex == 0,
                      onTap: () => onChanged(0),
                    ),
                    _NavItem(
                      icon: Icons.inventory_2_outlined,
                      isSelected: selectedIndex == 1,
                      onTap: () => onChanged(1),
                    ),
                    _NavItem(
                      icon: Icons.local_shipping_outlined,
                      isSelected: selectedIndex == 2,
                      onTap: () => onChanged(2),
                    ),
                    _NavItem(
                      icon: Icons.person_outline,
                      isSelected: selectedIndex == 3,
                      onTap: () => onChanged(3),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? Colors.white : const Color(0xFF98A1AE);

    return Expanded(
      child: SizedBox.expand(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            hoverColor: Colors.transparent,
            child: Center(
              child: AnimatedScale(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutBack,
                scale: isSelected ? 1.06 : 1.0,
                child: Icon(
                  icon,
                  color: color,
                  size: 23,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/* ----------------------------- UI PIECES ----------------------------- */

class _DriverTopHeader extends StatelessWidget {
  const _DriverTopHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF2A2F37),
            border: Border.all(color: const Color(0x18FFFFFF)),
          ),
          child: const Icon(
            Icons.person,
            color: Color(0xFFF5F7FA),
            size: 22,
          ),
        ),
        const Spacer(),
        const _HeaderCircleButton(icon: Icons.settings_outlined),
        const SizedBox(width: 10),
        const _HeaderCircleButton(icon: Icons.notifications_none_rounded),
      ],
    );
  }
}

class _HeaderCircleButton extends StatelessWidget {
  final IconData icon;

  const _HeaderCircleButton({
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: const Color(0xFF1B1F26),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0x16FFFFFF)),
      ),
      child: Icon(
        icon,
        color: const Color(0xFFF5F7FA),
        size: 20,
      ),
    );
  }
}

class _SimpleHeader extends StatelessWidget {
  final String title;

  const _SimpleHeader({
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: Color(0xFFF5F7FA),
        fontSize: 30,
        fontWeight: FontWeight.w400,
        height: 1,
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  final VoidCallback onTap;
  final String title;
  final String tagText;
  final Widget child;

  const _PreviewCard({
    required this.onTap,
    required this.title,
    required this.tagText,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1B1F26),
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF1B1F26),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0x14FFFFFF)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionHeader(
                title: title,
                chipText: tagText,
              ),
              const SizedBox(height: 18),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String chipText;

  const _SectionHeader({
    required this.title,
    required this.chipText,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Color(0xFFF5F7FA),
              fontSize: 26,
              fontWeight: FontWeight.w400,
              height: 1,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0x33FF5A1F),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            chipText,
            style: const TextStyle(
              color: Color(0xFFFF6A2B),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _PreviewOrderRow extends StatelessWidget {
  final OrderModel order;

  const _PreviewOrderRow({
    required this.order,
  });

  @override
  Widget build(BuildContext context) {
    final description =
        _safeOrderText(order, 'description', fallback: 'Untitled order');
    final pickup = _safeOrderText(order, 'pickupLocation');
    final dropoff = _safeOrderText(order, 'dropoffLocation');
    final price = _safeOrderPrice(order);
    final status = _orderStatus(order);

    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFF2A2F37),
          ),
          child: const Icon(
            Icons.local_shipping_outlined,
            color: Colors.white,
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFFF5F7FA),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '$pickup → $dropoff',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF98A1AE),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '\$${price.toStringAsFixed(0)}',
              style: const TextStyle(
                color: Color(0xFFF5F7FA),
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _etaText(status),
              style: const TextStyle(
                color: Color(0xFF98A1AE),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ],
    );
  }

  static String _etaText(String status) {
    switch (status) {
      case AppStatus.accepted:
        return 'Accepted';
      case AppStatus.pickedUp:
        return 'Picked Up';
      case AppStatus.onTheWay:
        return 'Transit';
      case AppStatus.delivered:
        return 'Done';
      default:
        return 'Open';
    }
  }
}

class _EmptyPreviewContent extends StatelessWidget {
  final String title;
  final String subtitle;

  const _EmptyPreviewContent({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFF2A2F37),
          ),
          child: const Icon(
            Icons.inventory_2_outlined,
            color: Color(0xFFF5F7FA),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFFF5F7FA),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Color(0xFF98A1AE),
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DetailedOrderCard extends StatelessWidget {
  final String title;
  final String accentText;
  final OrderModel order;
  final bool showAcceptButton;
  final VoidCallback? onAccept;

  const _DetailedOrderCard({
    required this.title,
    required this.order,
    required this.accentText,
    this.showAcceptButton = false,
    this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    final pickup = _safeOrderText(order, 'pickupLocation');
    final dropoff = _safeOrderText(order, 'dropoffLocation');
    final description =
        _safeOrderText(order, 'description', fallback: 'Untitled order');
    final price = _safeOrderPrice(order);
    final status = _statusDisplayText(_orderStatus(order));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1F26),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0x14FFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFFF5F7FA),
                    fontSize: 28,
                    fontWeight: FontWeight.w400,
                    height: 1,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0x33FF5A1F),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  accentText,
                  style: const TextStyle(
                    color: Color(0xFFFF6A2B),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _InfoRow(label: 'Pickup', value: pickup),
          const SizedBox(height: 10),
          _InfoRow(label: 'Dropoff', value: dropoff),
          const SizedBox(height: 10),
          _InfoRow(label: 'Description', value: description),
          const SizedBox(height: 10),
          _InfoRow(label: 'Price', value: '\$${price.toStringAsFixed(2)}'),
          const SizedBox(height: 10),
          _InfoRow(label: 'Status', value: status),
          if (showAcceptButton) ...[
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onAccept,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF5A1F),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: const Text(
                  'Accept Order',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _statusDisplayText(String status) {
    switch (status) {
      case AppStatus.accepted:
        return 'Accepted';
      case AppStatus.pickedUp:
        return 'Picked Up';
      case AppStatus.onTheWay:
        return 'On The Way';
      case AppStatus.delivered:
        return 'Delivered';
      default:
        return status;
    }
  }
}

class _StatusTimeline extends StatelessWidget {
  final OrderModel order;

  const _StatusTimeline({
    required this.order,
  });

  bool _isStepDone(String stepStatus) {
    const statuses = [
      AppStatus.accepted,
      AppStatus.pickedUp,
      AppStatus.onTheWay,
      AppStatus.delivered,
    ];

    final currentStatus = _normalizedOrderStatus(order);
    final currentIndex = statuses.indexOf(currentStatus);
    final stepIndex = statuses.indexOf(stepStatus);

    if (currentIndex == -1 || stepIndex == -1) return false;
    return currentIndex >= stepIndex;
  }

  bool _isCurrentStep(String stepStatus) {
    return _normalizedOrderStatus(order) == stepStatus;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1F26),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x14FFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Delivery Progress',
            style: TextStyle(
              color: Color(0xFFF5F7FA),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          _TimelineStep(
            title: 'Accepted',
            isDone: _isStepDone(AppStatus.accepted),
            isCurrent: _isCurrentStep(AppStatus.accepted),
          ),
          _TimelineStep(
            title: 'Picked Up',
            isDone: _isStepDone(AppStatus.pickedUp),
            isCurrent: _isCurrentStep(AppStatus.pickedUp),
          ),
          _TimelineStep(
            title: 'On The Way',
            isDone: _isStepDone(AppStatus.onTheWay),
            isCurrent: _isCurrentStep(AppStatus.onTheWay),
          ),
          _TimelineStep(
            title: 'Delivered',
            isDone: _isStepDone(AppStatus.delivered),
            isCurrent: _isCurrentStep(AppStatus.delivered),
            isLast: true,
          ),
        ],
      ),
    );
  }
}

class _TimelineStep extends StatelessWidget {
  final String title;
  final bool isDone;
  final bool isCurrent;
  final bool isLast;

  const _TimelineStep({
    required this.title,
    required this.isDone,
    required this.isCurrent,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final dotColor =
        isDone ? const Color(0xFFFF5A1F) : const Color(0xFF4B5563);
    final lineColor =
        isDone ? const Color(0x66FF5A1F) : const Color(0x334B5563);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
                boxShadow: isCurrent
                    ? const [
                        BoxShadow(
                          color: Color(0x66FF5A1F),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 26,
                color: lineColor,
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 0),
            child: Text(
              title,
              style: TextStyle(
                color: isDone
                    ? const Color(0xFFF5F7FA)
                    : const Color(0xFF98A1AE),
                fontSize: 14,
                fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusActionSection extends StatelessWidget {
  final OrderModel order;
  final Future<void> Function(OrderModel order, String status) onUpdateStatus;

  const _StatusActionSection({
    required this.order,
    required this.onUpdateStatus,
  });

  @override
  Widget build(BuildContext context) {
    final status = _normalizedOrderStatus(order);

    if (status == AppStatus.accepted) {
      return _ActionButtonCard(
        title: 'Notify Picked Up',
        subtitle: 'Tell seller that the package has been picked up.',
        buttonLabel: 'Picked Up',
        icon: Icons.inventory_2_outlined,
        onTap: () => onUpdateStatus(order, AppStatus.pickedUp),
      );
    }

    if (status == AppStatus.pickedUp) {
      return _ActionButtonCard(
        title: 'Notify On The Way',
        subtitle: 'Tell seller that the package is now on the way.',
        buttonLabel: 'On The Way',
        icon: Icons.route_outlined,
        onTap: () => onUpdateStatus(order, AppStatus.onTheWay),
      );
    }

    if (status == AppStatus.onTheWay) {
      return _ActionButtonCard(
        title: 'Notify Delivered',
        subtitle: 'Tell seller that the package has been delivered.',
        buttonLabel: 'Delivered',
        icon: Icons.check_circle_outline,
        onTap: () => onUpdateStatus(order, AppStatus.delivered),
      );
    }

    if (status == AppStatus.delivered) {
      return const _DarkEmptySection(
        title: 'Delivery completed',
        subtitle:
            'This order is already delivered and the seller has been notified.',
        icon: Icons.check_circle_outline,
      );
    }

    return const SizedBox.shrink();
  }
}

class _ActionButtonCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String buttonLabel;
  final IconData icon;
  final VoidCallback onTap;

  const _ActionButtonCard({
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1F26),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x14FFFFFF)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFFF5A1F),
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFFF5F7FA),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF98A1AE),
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5A1F),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              ),
              child: Text(buttonLabel),
            ),
          ),
        ],
      ),
    );
  }
}

class _DarkEmptySection extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _DarkEmptySection({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1F26),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0x14FFFFFF)),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF2A2F37),
            ),
            child: Icon(
              icon,
              color: const Color(0xFFF5F7FA),
              size: 30,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFFF5F7FA),
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF98A1AE),
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 88,
          child: Text(
            '$label:',
            style: const TextStyle(
              color: Color(0xFF98A1AE),
              fontSize: 13,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Color(0xFFF5F7FA),
              fontSize: 14,
              fontWeight: FontWeight.w500,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _ProfileTile({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF252A33),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: const Color(0xFFFF5A1F),
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Color(0xFFF5F7FA),
                fontSize: 15,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF98A1AE),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

/* ----------------------------- HELPERS ----------------------------- */

List<OrderModel> _extractActiveOrders(OrderProvider provider) {
  final List<OrderModel> orders = [];

  try {
    final dynamic p = provider;
    final dynamic maybeList = p.activeOrders;

    if (maybeList is List) {
      for (final item in maybeList) {
        if (item is OrderModel) {
          final status = _normalizedOrderStatus(item);
          if (status == AppStatus.accepted ||
              status == AppStatus.pickedUp ||
              status == AppStatus.onTheWay ||
              status == AppStatus.delivered) {
            orders.add(item);
          }
        }
      }
    }
  } catch (_) {}

  if (orders.isNotEmpty) return orders;

  try {
    final dynamic p = provider;
    final dynamic single = p.activeOrder;
    if (single is OrderModel) {
      orders.add(single);
    }
  } catch (_) {}

  return orders;
}

List<OrderModel> _extractAvailableOrders(OrderProvider provider) {
  try {
    final dynamic p = provider;
    final dynamic list = p.availableOrders;

    if (list is List) {
      return list.whereType<OrderModel>().toList();
    }
  } catch (_) {}

  return [];
}

String _orderId(OrderModel order) {
  try {
    final dynamic o = order;
    final dynamic id = o.id;
    if (id != null && id.toString().trim().isNotEmpty) {
      return id.toString();
    }
  } catch (_) {}
  return '';
}

String _orderStatus(OrderModel order) {
  try {
    final dynamic o = order;
    final dynamic value = o.status;
    if (value != null && value.toString().trim().isNotEmpty) {
      return value.toString();
    }
  } catch (_) {}
  return 'unknown';
}

String _normalizedOrderStatus(OrderModel order) {
  final raw = _orderStatus(order).trim().toLowerCase();

  if (raw == AppStatus.accepted.toLowerCase()) return AppStatus.accepted;
  if (raw == AppStatus.pickedUp.toLowerCase()) return AppStatus.pickedUp;
  if (raw == AppStatus.onTheWay.toLowerCase()) return AppStatus.onTheWay;
  if (raw == AppStatus.delivered.toLowerCase()) return AppStatus.delivered;

  if (raw == 'picked_up') return AppStatus.pickedUp;
  if (raw == 'pickedup') return AppStatus.pickedUp;
  if (raw == 'on_the_way') return AppStatus.onTheWay;
  if (raw == 'ontheway') return AppStatus.onTheWay;

  return _orderStatus(order);
}

String _orderTitle(OrderModel order) {
  return _safeOrderText(order, 'description', fallback: 'Untitled order');
}

String _safeOrderText(
  OrderModel order,
  String field, {
  String fallback = '—',
}) {
  try {
    final dynamic o = order;
    dynamic value;

    switch (field) {
      case 'description':
        value = o.description;
        break;
      case 'pickupLocation':
        value = o.pickupLocation;
        break;
      case 'dropoffLocation':
        value = o.dropoffLocation;
        break;
      case 'status':
        value = o.status;
        break;
      case 'id':
        value = o.id;
        break;
      default:
        value = null;
    }

    if (value == null) return fallback;
    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  } catch (_) {
    return fallback;
  }
}

double _safeOrderPrice(OrderModel order) {
  try {
    final dynamic o = order;
    final dynamic value = o.price;

    if (value == null) return 0;
    if (value is num) return value.toDouble();

    return double.tryParse(value.toString()) ?? 0;
  } catch (_) {
    return 0;
  }
}
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

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  int _selectedIndex = 0;
  String? _driverId;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final authProvider = context.read<AuthProvider>();
      final orderProvider = context.read<OrderProvider>();
      final chatProvider = context.read<ChatProvider>();
      final notificationProvider = context.read<NotificationProvider>();

      _driverId = authProvider.currentUserId;

      orderProvider.startAvailableOrdersListener();

      if (_driverId != null && _driverId!.isNotEmpty) {
        orderProvider.startDriverActiveOrderListener(driverId: _driverId!);

        // FIX: Start chats listener here so the driver's chat list is
        // populated as soon as the seller accepts a chat request.
        // Previously this was only started when the driver manually opened
        // the ChatListScreen, so newly accepted chats never appeared.
        chatProvider.startChatsListener(_driverId!);

        // FIX: Start notification listener for the driver so they receive
        // notifications about chat acceptances, delivery approvals, etc.
        notificationProvider.startNotificationsListener(_driverId!);
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
    try {
      context.read<ChatProvider>().stopChatsListener();
    } catch (_) {}
    try {
      context.read<NotificationProvider>().stopNotificationsListener(
        userId: _driverId,
      );
    } catch (_) {}
    super.dispose();
  }

  Future<void> _logout() async {
    final authProvider = context.read<AuthProvider>();

    await authProvider.logout();

    if (!mounted) return;
    Navigator.pushReplacementNamed(context, AppRoutes.login);
  }

  Future<void> _sendDeliveryRequest(OrderModel order) async {
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
      orderId: order.id,
      driverId: driverId,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Delivery request sent. Wait for seller approval before delivery starts.',
          ),
        ),
      );
      setState(() {
        _selectedIndex = 1;
      });
    } else {
      final message =
          orderProvider.errorMessage ?? 'Failed to send delivery request';
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
      orderId: order.id,
      driverId: driverId,
      status: status,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Order updated: $status')),
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

    await Future.delayed(const Duration(milliseconds: 300));
  }

  @override
  Widget build(BuildContext context) {
    final notificationProvider = context.watch<NotificationProvider>();

    final pages = [
      _DriverAvailableOrdersTab(
        onSendRequest: _sendDeliveryRequest,
        onRefresh: _refreshData,
      ),
      _DriverActiveOrdersTab(
        onUpdateStatus: _updateStatus,
        onRefresh: _refreshData,
      ),
      const _DriverChatsTab(),
      _DriverProfileTab(
        onLogout: _logout,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Dashboard'),
        actions: [
          // FIX: show notification bell for driver too
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  onPressed: () {
                    Navigator.pushNamed(context, AppRoutes.notifications);
                  },
                  icon: const Icon(Icons.notifications_none),
                ),
                if (notificationProvider.unreadCount > 0)
                  Positioned(
                    right: 10,
                    top: 10,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      body: pages[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.local_shipping_outlined),
            label: 'Orders',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            label: 'Active',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            label: 'Chats',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _DriverAvailableOrdersTab extends StatelessWidget {
  final Future<void> Function(OrderModel order) onSendRequest;
  final Future<void> Function() onRefresh;

  const _DriverAvailableOrdersTab({
    required this.onSendRequest,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final orderProvider = context.watch<OrderProvider>();

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: orderProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : orderProvider.availableOrders.isEmpty
              ? ListView(
                  children: const [
                    SizedBox(height: 220),
                    Center(child: Text('No available orders')),
                  ],
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: orderProvider.availableOrders.length,
                  itemBuilder: (context, index) {
                    final order = orderProvider.availableOrders[index];

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              order.description,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text('Pickup: ${order.pickupLocation}'),
                            Text('Dropoff: ${order.dropoffLocation}'),
                            Text(
                                'Price: \$${order.price.toStringAsFixed(2)}'),
                            Text('Status: ${order.status}'),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () => onSendRequest(order),
                                child: const Text('Send Delivery Request'),
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Seller must approve before you can deliver this package.',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

class _DriverActiveOrdersTab extends StatelessWidget {
  final Future<void> Function(OrderModel order, String status) onUpdateStatus;
  final Future<void> Function() onRefresh;

  const _DriverActiveOrdersTab({
    required this.onUpdateStatus,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final orderProvider = context.watch<OrderProvider>();

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: orderProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : orderProvider.activeOrders.isEmpty
              ? ListView(
                  children: const [
                    SizedBox(height: 220),
                    Center(child: Text('No active orders')),
                  ],
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: orderProvider.activeOrders.length,
                  itemBuilder: (context, index) {
                    final order = orderProvider.activeOrders[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              order.description,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text('Pickup: ${order.pickupLocation}'),
                            Text('Dropoff: ${order.dropoffLocation}'),
                            Text(
                                'Price: \$${order.price.toStringAsFixed(2)}'),
                            Text('Status: ${order.status}'),
                            const SizedBox(height: 14),
                            _DriverChatButton(order: order),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                if (order.status == AppStatus.accepted)
                                  ElevatedButton(
                                    onPressed: () => onUpdateStatus(
                                      order,
                                      AppStatus.pickedUp,
                                    ),
                                    child: const Text('Picked Up'),
                                  ),
                                if (order.status == AppStatus.pickedUp)
                                  ElevatedButton(
                                    onPressed: () => onUpdateStatus(
                                      order,
                                      AppStatus.onTheWay,
                                    ),
                                    child: const Text('On The Way'),
                                  ),
                                if (order.status == AppStatus.onTheWay)
                                  ElevatedButton(
                                    onPressed: () => onUpdateStatus(
                                      order,
                                      AppStatus.delivered,
                                    ),
                                    child: const Text('Delivered'),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

class _DriverChatButton extends StatelessWidget {
  final OrderModel order;

  const _DriverChatButton({
    required this.order,
  });

  String _buildChatId() {
    final driverId = order.driverId ?? '';
    return '${order.id}_${order.sellerId}_$driverId';
  }

  @override
  Widget build(BuildContext context) {
    final driverId = order.driverId ?? '';
    if (driverId.isEmpty) {
      return const SizedBox.shrink();
    }

    final chatId = _buildChatId();

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chat_requests')
          .doc(chatId)
          .snapshots(),
      builder: (context, requestSnapshot) {
        final exists = requestSnapshot.data?.exists ?? false;
        final requestData = requestSnapshot.data?.data();
        final requestMap = requestData is Map<String, dynamic>
            ? requestData
            : <String, dynamic>{};
        final requestStatus = (requestMap['status'] ?? '').toString();

        if (!exists || requestStatus == 'pending') {
          return const Text(
            'Waiting for seller approval',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 13,
            ),
          );
        }

        if (requestStatus == 'rejected') {
          return const Text(
            'Seller rejected the delivery request',
            style: TextStyle(
              color: Colors.redAccent,
              fontSize: 13,
            ),
          );
        }

        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('chats')
              .doc(chatId)
              .snapshots(),
          builder: (context, chatSnapshot) {
            final chatExists = chatSnapshot.data?.exists ?? false;

            if (!chatExists) {
              return const Text(
                'Preparing chat...',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 13,
                ),
              );
            }

            return SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    AppRoutes.chatScreen,
                    arguments: ChatScreenArgs(
                      chatId: chatId,
                      title: order.description,
                    ),
                  );
                },
                icon: const Icon(Icons.chat_bubble_outline),
                label: const Text('Open Chat'),
              ),
            );
          },
        );
      },
    );
  }
}

// FIX: _DriverChatsTab now shows chats inline instead of just a button
// to navigate to ChatListScreen. It reuses the live ChatProvider stream
// that was started in DriverHomeScreen.initState().
class _DriverChatsTab extends StatelessWidget {
  const _DriverChatsTab();

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();
    final authProvider = context.watch<AuthProvider>();
    final currentUserId = authProvider.currentUserId ?? '';

    if (chatProvider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (chatProvider.chats.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.chat_bubble_outline, size: 60, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No chats yet',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 8),
            const Text(
              'Send a delivery request to start a chat with a seller.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, AppRoutes.chatList);
              },
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open Full Chat List'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: chatProvider.chats.length,
      itemBuilder: (context, index) {
        final doc = chatProvider.chats[index];
        final data = doc.data() as Map<String, dynamic>;

        final sellerId = (data['sellerId'] ?? '').toString();
        final driverId = (data['driverId'] ?? '').toString();
        final otherUserId =
            currentUserId == sellerId ? driverId : sellerId;

        final orderDescription =
            (data['orderDescription'] ?? 'Chat').toString();
        final lastMessage = (data['lastMessage'] ?? '').toString();

        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(otherUserId)
              .snapshots(),
          builder: (context, snapshot) {
            final userData = snapshot.data?.data();
            final userMap = userData is Map<String, dynamic>
                ? userData
                : <String, dynamic>{};

            final otherEmail =
                (userMap['email'] ?? 'Unknown user').toString();
            final isOnline = userMap['isOnline'] == true;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    AppRoutes.chatScreen,
                    arguments: ChatScreenArgs(
                      chatId: doc.id,
                      title: orderDescription,
                    ),
                  );
                },
                leading: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const CircleAvatar(
                      radius: 24,
                      child: Icon(Icons.person),
                    ),
                    Positioned(
                      right: -1,
                      bottom: -1,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color:
                              isOnline ? Colors.green : Colors.grey,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF101216),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                title: Text(
                  orderDescription,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      otherEmail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      lastMessage.isEmpty ? 'No messages yet' : lastMessage,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
                trailing: Icon(
                  isOnline
                      ? Icons.circle
                      : Icons.access_time_outlined,
                  size: isOnline ? 12 : 18,
                  color: isOnline ? Colors.green : Colors.grey,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _DriverProfileTab extends StatelessWidget {
  final Future<void> Function() onLogout;

  const _DriverProfileTab({
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final profile = authProvider.currentUserProfile;
    final email = authProvider.currentUserEmail ?? 'driver@truckcab.com';
    final role = profile?.role ?? 'driver';
    final isOnline = profile?.isOnline ?? false;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const CircleAvatar(
                  radius: 40,
                  child: Icon(Icons.person, size: 38),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Driver Account',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  email,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                Text('Role: $role'),
                const SizedBox(height: 6),
                Text(
                  isOnline ? 'Status: Online' : 'Status: Offline',
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onLogout,
                    child: const Text('Logout'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
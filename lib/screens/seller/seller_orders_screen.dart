import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/order_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/order_provider.dart';
import '../../routes/app_routes.dart';

class SellerOrdersScreen extends StatefulWidget {
  const SellerOrdersScreen({super.key});

  @override
  State<SellerOrdersScreen> createState() => _SellerOrdersScreenState();
}

class _SellerOrdersScreenState extends State<SellerOrdersScreen> {
  @override
  void initState() {
    super.initState();

    Future.microtask(() {
      final authProvider = context.read<AuthProvider>();
      final orderProvider = context.read<OrderProvider>();

      final sellerId = authProvider.currentUserId;
      if (sellerId != null && sellerId.isNotEmpty) {
        orderProvider.startSellerOrdersListener(sellerId: sellerId);
      }
    });
  }

  @override
  void dispose() {
    try {
      context.read<OrderProvider>().stopSellerOrdersListener();
    } catch (_) {}
    super.dispose();
  }

  String _buildChatId(OrderModel order) {
    final driverId = order.driverId ?? '';
    return '${order.id}_${order.sellerId}_$driverId';
  }

  @override
  Widget build(BuildContext context) {
    final orderProvider = context.watch<OrderProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Orders'),
      ),
      body: orderProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : orderProvider.sellerOrders.isEmpty
              ? const Center(child: Text('No orders found'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: orderProvider.sellerOrders.length,
                  itemBuilder: (context, index) {
                    final order = orderProvider.sellerOrders[index];

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
                            Text('Price: \$${order.price.toStringAsFixed(2)}'),
                            Text('Status: ${order.status}'),
                            Text(
                              'Driver ID: ${order.driverId == null || order.driverId!.isEmpty ? 'Not assigned yet' : order.driverId}',
                            ),
                            if (order.driverId != null &&
                                order.driverId!.isNotEmpty) ...[
                              const SizedBox(height: 14),
                              _SellerOrderChatSection(
                                order: order,
                                chatId: _buildChatId(order),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

class _SellerOrderChatSection extends StatelessWidget {
  final OrderModel order;
  final String chatId;

  const _SellerOrderChatSection({
    required this.order,
    required this.chatId,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chat_requests')
          .doc(chatId)
          .snapshots(),
      builder: (context, requestSnapshot) {
        final requestExists = requestSnapshot.data?.exists ?? false;
        final requestData = requestSnapshot.data?.data();
        final requestMap = requestData is Map<String, dynamic>
            ? requestData
            : <String, dynamic>{};
        final requestStatus = (requestMap['status'] ?? '').toString();

        if (!requestExists) {
          return const Text(
            'No chat request yet',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 13,
            ),
          );
        }

        if (requestStatus == 'pending') {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Driver requested chat',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pushNamed(context, AppRoutes.chatRequests);
                      },
                      child: const Text('Review Request'),
                    ),
                  ),
                ],
              ),
            ],
          );
        }

        if (requestStatus == 'rejected') {
          return const Text(
            'Chat request rejected',
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
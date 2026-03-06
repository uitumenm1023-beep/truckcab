import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/order_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/order_model.dart';

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
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final orderProvider = Provider.of<OrderProvider>(context, listen: false);

      final sellerId = authProvider.currentUserId;

      if (sellerId != null && sellerId.isNotEmpty) {
        orderProvider.startSellerOrdersListener(sellerId: sellerId);
      }
    });
  }

  @override
  void dispose() {
    Provider.of<OrderProvider>(context, listen: false).stopSellerOrdersListener();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final orderProvider = Provider.of<OrderProvider>(context);

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
                    final OrderModel order = orderProvider.sellerOrders[index];

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        title: Text(
                          order.description,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Pickup: ${order.pickupLocation}'),
                              Text('Dropoff: ${order.dropoffLocation}'),
                              Text('Price: \$${order.price.toStringAsFixed(2)}'),
                              Text('Status: ${order.status}'),
                              Text(
                                'Driver ID: ${order.driverId == null || order.driverId!.isEmpty ? 'Not assigned yet' : order.driverId}',
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
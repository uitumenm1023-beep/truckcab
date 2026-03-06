import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/order_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/order_model.dart';
import '../../core/constants/app_status.dart';

class DriverActiveOrder extends StatefulWidget {
  const DriverActiveOrder({super.key});

  @override
  State<DriverActiveOrder> createState() => _DriverActiveOrderState();
}

class _DriverActiveOrderState extends State<DriverActiveOrder> {
  @override
  void initState() {
    super.initState();

    Future.microtask(() {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final orderProvider = Provider.of<OrderProvider>(context, listen: false);

      final driverId = authProvider.currentUserId;

      if (driverId != null && driverId.isNotEmpty) {
        orderProvider.startDriverActiveOrderListener(driverId: driverId);
      }
    });
  }

  @override
  void dispose() {
    Provider.of<OrderProvider>(context, listen: false)
        .stopDriverActiveOrderListener();
    super.dispose();
  }

  Future<void> _updateStatus(
    BuildContext context,
    String status,
  ) async {
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final activeOrder = orderProvider.activeOrder;

    if (activeOrder == null) return;

    final success = await orderProvider.updateOrderStatus(
      orderId: activeOrder.id,
      driverId: authProvider.currentUserId ?? '',
      status: status,
    );

    if (!context.mounted) return;

    if (success) {
      final message = status == AppStatus.delivered
          ? 'Order completed successfully'
          : 'Order status updated';

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

  Widget _buildStatusButtons(BuildContext context, OrderModel order) {
    if (order.status == AppStatus.accepted) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => _updateStatus(context, AppStatus.pickedUp),
          child: const Text('Picked Up'),
        ),
      );
    }

    if (order.status == AppStatus.pickedUp) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => _updateStatus(context, AppStatus.onTheWay),
          child: const Text('On The Way'),
        ),
      );
    }

    if (order.status == AppStatus.onTheWay) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => _updateStatus(context, AppStatus.delivered),
          child: const Text('Delivered'),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final orderProvider = Provider.of<OrderProvider>(context);
    final OrderModel? order = orderProvider.activeOrder;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Active Delivery'),
      ),
      body: orderProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : order == null
              ? const Center(child: Text('No active delivery'))
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              order.description,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text('Pickup: ${order.pickupLocation}'),
                            Text('Dropoff: ${order.dropoffLocation}'),
                            Text('Price: \$${order.price.toStringAsFixed(2)}'),
                            Text('Status: ${order.status}'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildStatusButtons(context, order),
                  ],
                ),
    );
  }
}
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../core/constants/app_status.dart';
import '../models/order_model.dart';
import 'notification_service.dart';

class OrderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();

  final String _ordersCollection = 'orders';

  CollectionReference<Map<String, dynamic>> get _ordersRef =>
      _firestore.collection(_ordersCollection);

  Future<void> createOrder({
    required String sellerId,
    required String pickupLocation,
    required String dropoffLocation,
    required String description,
    required double price,
  }) async {
    try {
      await _ordersRef.add({
        'sellerId': sellerId,
        'driverId': null,
        'pickupLocation': pickupLocation.trim(),
        'dropoffLocation': dropoffLocation.trim(),
        'description': description.trim(),
        'price': price,
        'status': AppStatus.open,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e, st) {
      debugPrint('createOrder error: $e');
      debugPrint('$st');
      throw Exception('Failed to create order');
    }
  }

  Future<List<OrderModel>> getAvailableOrders() async {
    try {
      final querySnapshot = await _ordersRef
          .where('status', isEqualTo: AppStatus.open)
          .get();

      final orders = querySnapshot.docs
          .map((doc) => OrderModel.fromFirestore(doc))
          .toList();

      orders.sort((a, b) {
        final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });

      return orders;
    } catch (e, st) {
      debugPrint('getAvailableOrders error: $e');
      debugPrint('$st');
      throw Exception('Failed to fetch available orders');
    }
  }

  Stream<List<OrderModel>> streamAvailableOrders() {
    return _ordersRef
        .where('status', isEqualTo: AppStatus.open)
        .snapshots()
        .map((snapshot) {
      final orders = snapshot.docs
          .map((doc) => OrderModel.fromFirestore(doc))
          .toList();

      orders.sort((a, b) {
        final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });

      return orders;
    });
  }

  Future<List<OrderModel>> getSellerOrders({
    required String sellerId,
  }) async {
    try {
      final querySnapshot =
          await _ordersRef.where('sellerId', isEqualTo: sellerId).get();

      final orders = querySnapshot.docs
          .map((doc) => OrderModel.fromFirestore(doc))
          .toList();

      orders.sort((a, b) {
        final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });

      return orders;
    } catch (e, st) {
      debugPrint('getSellerOrders error: $e');
      debugPrint('$st');
      throw Exception('Failed to fetch seller orders');
    }
  }

  Stream<List<OrderModel>> streamSellerOrders({
    required String sellerId,
  }) {
    return _ordersRef
        .where('sellerId', isEqualTo: sellerId)
        .snapshots()
        .map((snapshot) {
      final orders = snapshot.docs
          .map((doc) => OrderModel.fromFirestore(doc))
          .toList();

      orders.sort((a, b) {
        final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });

      return orders;
    });
  }

  Future<List<OrderModel>> getDriverActiveOrders({
    required String driverId,
  }) async {
    try {
      final querySnapshot =
          await _ordersRef.where('driverId', isEqualTo: driverId).get();

      final orders = querySnapshot.docs
          .map((doc) => OrderModel.fromFirestore(doc))
          .where(_isActiveDriverOrder)
          .toList();

      orders.sort((a, b) {
        final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });

      return orders;
    } catch (e, st) {
      debugPrint('getDriverActiveOrders error: $e');
      debugPrint('$st');
      throw Exception('Failed to fetch driver active orders');
    }
  }

  Stream<List<OrderModel>> streamDriverActiveOrders({
    required String driverId,
  }) {
    return _ordersRef
        .where('driverId', isEqualTo: driverId)
        .snapshots()
        .map((snapshot) {
      final orders = snapshot.docs
          .map((doc) => OrderModel.fromFirestore(doc))
          .where(_isActiveDriverOrder)
          .toList();

      orders.sort((a, b) {
        final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });

      return orders;
    });
  }

  bool _isActiveDriverOrder(OrderModel order) {
    return order.status == AppStatus.accepted ||
        order.status == AppStatus.pickedUp ||
        order.status == AppStatus.onTheWay;
  }

  // FIX: This now does TWO things that were broken before:
  //   1. Creates the chat_request in Firestore (was done in ChatService before,
  //      bypassing notifications entirely)
  //   2. Creates a notification for the seller so it appears in their
  //      notification section immediately
  Future<void> acceptOrder({
    required String orderId,
    required String driverId,
    required String orderDescription,
    required String pickupLocation,
    required String dropoffLocation,
  }) async {
    try {
      final orderRef = _ordersRef.doc(orderId);
      final snapshot = await orderRef.get();

      if (!snapshot.exists) {
        throw Exception('Order not found');
      }

      final order = OrderModel.fromFirestore(snapshot);

      if (order.status != AppStatus.open) {
        throw Exception('Order is no longer available');
      }

      // Build the shared chatId used across chat_requests and chats collections
      final chatId = '${orderId}_${order.sellerId}_$driverId';

      // Write chat_request doc
      await _firestore.collection('chat_requests').doc(chatId).set({
        'orderId': orderId,
        'sellerId': order.sellerId,
        'driverId': driverId,
        'orderDescription': orderDescription,
        'pickupLocation': pickupLocation,
        'dropoffLocation': dropoffLocation,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('acceptOrder: chat_request created chatId=$chatId');

      // Notify the seller that a driver wants to deliver their package
      try {
        await _notificationService.createNotification(
          userId: order.sellerId,
          orderId: orderId,
          title: 'New Delivery Request',
          message: 'A driver wants to deliver your package. Check Chat Requests.',
          type: 'chat_request',
        );
        debugPrint('acceptOrder: notification sent to seller=${order.sellerId}');
      } catch (e, st) {
        debugPrint('acceptOrder notification error: $e');
        debugPrint('$st');
        // Don't rethrow — the chat request was still saved successfully
      }
    } catch (e, st) {
      debugPrint('acceptOrder error: $e');
      debugPrint('$st');
      throw Exception('Failed to send delivery request');
    }
  }

  Future<OrderModel> updateOrderStatus({
    required String orderId,
    required String driverId,
    required String status,
  }) async {
    try {
      final orderRef = _ordersRef.doc(orderId);

      final snapshot = await orderRef.get();

      if (!snapshot.exists) {
        throw Exception('Order not found');
      }

      final order = OrderModel.fromFirestore(snapshot);

      if (order.driverId != driverId) {
        throw Exception('Only the assigned driver can update this order');
      }

      await orderRef.update({
        'status': status,
      });

      debugPrint('Order status updated: orderId=$orderId status=$status sellerId=${order.sellerId}');

      String title = '';
      String message = '';
      String type = '';

      if (status == AppStatus.pickedUp) {
        title = 'Package Picked Up';
        message = 'The driver has picked up your package.';
        type = 'package_picked_up';
      } else if (status == AppStatus.onTheWay) {
        title = 'Driver On The Way';
        message = 'The driver is on the way with your package.';
        type = 'driver_on_the_way';
      } else if (status == AppStatus.delivered) {
        title = 'Package Delivered';
        message = 'Your package has been successfully delivered!';
        type = 'package_delivered';
      }

      // FIX: notification is created for EVERY status change, using
      // order.sellerId which is reliably fetched from Firestore above.
      if (message.isNotEmpty) {
        try {
          await _notificationService.createNotification(
            userId: order.sellerId,
            orderId: orderId,
            title: title,
            message: message,
            type: type,
          );
          debugPrint('Notification created: seller=${order.sellerId} type=$type order=$orderId');
        } catch (e, st) {
          debugPrint('updateOrderStatus notification error: $e');
          debugPrint('$st');
          // Don't rethrow — the status update itself succeeded
        }
      }

      final updatedSnapshot = await orderRef.get();
      return OrderModel.fromFirestore(updatedSnapshot);
    } catch (e, st) {
      debugPrint('updateOrderStatus error: $e');
      debugPrint('$st');
      throw Exception('Failed to update order status');
    }
  }
}
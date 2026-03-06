import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/order_model.dart';
import 'notification_service.dart';

class OrderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();

  final String _ordersCollection = 'orders';

  Future<void> createOrder({
    required String sellerId,
    required String pickupLocation,
    required String dropoffLocation,
    required String description,
    required double price,
  }) async {
    try {
      await _firestore.collection(_ordersCollection).add({
        'sellerId': sellerId,
        'driverId': null,
        'pickupLocation': pickupLocation,
        'dropoffLocation': dropoffLocation,
        'description': description,
        'price': price,
        'status': 'OPEN',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to create order');
    }
  }

  Future<List<OrderModel>> getAvailableOrders() async {
    try {
      final querySnapshot = await _firestore
          .collection(_ordersCollection)
          .where('status', isEqualTo: 'OPEN')
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
    } catch (e) {
      throw Exception('Failed to fetch available orders');
    }
  }

  Stream<List<OrderModel>> streamAvailableOrders() {
    return _firestore
        .collection(_ordersCollection)
        .where('status', isEqualTo: 'OPEN')
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
      final querySnapshot = await _firestore
          .collection(_ordersCollection)
          .where('sellerId', isEqualTo: sellerId)
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
    } catch (e) {
      throw Exception('Failed to fetch seller orders');
    }
  }

  Stream<List<OrderModel>> streamSellerOrders({
    required String sellerId,
  }) {
    return _firestore
        .collection(_ordersCollection)
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

  Future<OrderModel?> getDriverActiveOrder({
    required String driverId,
  }) async {
    try {
      final querySnapshot = await _firestore
          .collection(_ordersCollection)
          .where('driverId', isEqualTo: driverId)
          .get();

      final orders = querySnapshot.docs
          .map((doc) => OrderModel.fromFirestore(doc))
          .where(
            (order) =>
                order.status == 'ACCEPTED' ||
                order.status == 'PICKED_UP' ||
                order.status == 'ON_THE_WAY',
          )
          .toList();

      if (orders.isEmpty) {
        return null;
      }

      orders.sort((a, b) {
        final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });

      return orders.first;
    } catch (e) {
      throw Exception('Failed to fetch driver active order');
    }
  }

  Stream<OrderModel?> streamDriverActiveOrder({
    required String driverId,
  }) {
    return _firestore
        .collection(_ordersCollection)
        .where('driverId', isEqualTo: driverId)
        .snapshots()
        .map((snapshot) {
      final orders = snapshot.docs
          .map((doc) => OrderModel.fromFirestore(doc))
          .where(
            (order) =>
                order.status == 'ACCEPTED' ||
                order.status == 'PICKED_UP' ||
                order.status == 'ON_THE_WAY',
          )
          .toList();

      if (orders.isEmpty) {
        return null;
      }

      orders.sort((a, b) {
        final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });

      return orders.first;
    });
  }

  Future<OrderModel> acceptOrder({
    required String orderId,
    required String driverId,
  }) async {
    try {
      final orderRef = _firestore.collection(_ordersCollection).doc(orderId);

      final snapshot = await orderRef.get();

      if (!snapshot.exists) {
        throw Exception('Order not found');
      }

      final order = OrderModel.fromFirestore(snapshot);

      if (order.status != 'OPEN') {
        throw Exception('Order is no longer available');
      }

      await orderRef.update({
        'driverId': driverId,
        'status': 'ACCEPTED',
      });

      await _notificationService.createNotification(
        userId: order.sellerId,
        orderId: orderId,
        message: 'Driver accepted your order',
      );

      final updatedSnapshot = await orderRef.get();
      return OrderModel.fromFirestore(updatedSnapshot);
    } catch (e) {
      throw Exception('Failed to accept order');
    }
  }

  Future<OrderModel> updateOrderStatus({
    required String orderId,
    required String driverId,
    required String status,
  }) async {
    try {
      final orderRef = _firestore.collection(_ordersCollection).doc(orderId);

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

      String message = '';

      if (status == 'PICKED_UP') {
        message = 'Driver picked up your package';
      } else if (status == 'ON_THE_WAY') {
        message = 'Driver is on the way';
      } else if (status == 'DELIVERED') {
        message = 'Package delivered';
      }

      if (message.isNotEmpty) {
        await _notificationService.createNotification(
          userId: order.sellerId,
          orderId: orderId,
          message: message,
        );
      }

      final updatedSnapshot = await orderRef.get();
      return OrderModel.fromFirestore(updatedSnapshot);
    } catch (e) {
      throw Exception('Failed to update order status');
    }
  }
}
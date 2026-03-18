import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/notification_model.dart';

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final String _notificationsCollection = 'notifications';

  CollectionReference<Map<String, dynamic>> get _notificationsRef =>
      _firestore.collection(_notificationsCollection);

  Future<void> createNotification({
    required String userId,
    required String orderId,
    required String message,
    String title = 'Order Update',
    String type = 'order_update',
  }) async {
    try {
      final doc = await _notificationsRef.add({
        'userId': userId,
        'orderId': orderId,
        'title': title,
        'message': message,
        'type': type,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      debugPrint('Notification doc created: ${doc.id} for userId=$userId');
    } catch (e, st) {
      debugPrint('createNotification error: $e');
      debugPrint('$st');
      rethrow;
    }
  }

  Future<List<NotificationModel>> getUserNotifications(String userId) async {
    try {
      final querySnapshot = await _notificationsRef
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      debugPrint('Fetched notifications for $userId count=${querySnapshot.docs.length}');

      return querySnapshot.docs
          .map((doc) => NotificationModel.fromFirestore(doc))
          .toList();
    } catch (e, st) {
      debugPrint('getUserNotifications error: $e');
      debugPrint('$st');
      throw Exception('Failed to fetch notifications');
    }
  }

  Stream<List<NotificationModel>> streamUserNotifications(String userId) {
    return _notificationsRef
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      debugPrint('Notification stream for $userId count=${snapshot.docs.length}');
      return snapshot.docs
          .map((doc) => NotificationModel.fromFirestore(doc))
          .toList();
    });
  }

  Future<void> markNotificationAsRead(String notificationId) async {
    try {
      await _notificationsRef.doc(notificationId).update({
        'isRead': true,
      });
    } catch (e, st) {
      debugPrint('markNotificationAsRead error: $e');
      debugPrint('$st');
      throw Exception('Failed to mark notification as read');
    }
  }

  Future<void> markAllNotificationsAsRead(String userId) async {
    try {
      final querySnapshot = await _notificationsRef
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();

      final batch = _firestore.batch();

      for (final doc in querySnapshot.docs) {
        batch.update(doc.reference, {
          'isRead': true,
        });
      }

      await batch.commit();
    } catch (e, st) {
      debugPrint('markAllNotificationsAsRead error: $e');
      debugPrint('$st');
      throw Exception('Failed to mark all notifications as read');
    }
  }
}
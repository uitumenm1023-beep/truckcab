import 'package:flutter/material.dart';
import '../models/notification_model.dart';
import '../services/notification_service.dart';

class NotificationProvider extends ChangeNotifier {
  final NotificationService _notificationService = NotificationService();

  List<NotificationModel> _notifications = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<NotificationModel> get notifications => _notifications;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  int get unreadCount =>
      _notifications.where((n) => n.isRead == false).length;

  Future<void> fetchUserNotifications(String userId) async {
    _setLoading(true);
    _clearError();

    try {
      final data = await _notificationService.getUserNotifications(userId);
      _notifications = data;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to load notifications';
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> createNotification({
    required String userId,
    required String orderId,
    required String message,
  }) async {
    try {
      await _notificationService.createNotification(
        userId: userId,
        orderId: orderId,
        message: message,
      );
    } catch (e) {
      _errorMessage = 'Failed to create notification';
      notifyListeners();
    }
  }

  Future<void> markNotificationAsRead(String notificationId) async {
    try {
      await _notificationService.markNotificationAsRead(notificationId);

      final index = _notifications.indexWhere((n) => n.id == notificationId);

      if (index != -1) {
        _notifications[index] =
            _notifications[index].copyWith(isRead: true);
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = 'Failed to update notification';
      notifyListeners();
    }
  }

  void clearNotifications() {
    _notifications = [];
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
  }
}
import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../models/notification_model.dart';
import '../services/notification_service.dart';

// ── Types that use the "delivery" sound ──────────────────────────────────────
const _deliverySoundTypes = {'package_delivered', 'delivery_approved'};

// ── Types that use the "message" sound ───────────────────────────────────────
// Everything else: chat_request, chat_accepted, chat_message, chat_rejected,
// package_picked_up, driver_on_the_way, order_update, etc.

class NotificationProvider extends ChangeNotifier {
  final NotificationService _notificationService = NotificationService();
  final AudioPlayer _audioPlayer = AudioPlayer();

  List<NotificationModel> _notifications = [];
  bool _isLoading = false;
  String? _errorMessage;

  StreamSubscription<List<NotificationModel>>? _notificationsSubscription;
  String? _latestNotificationId;

  // ── In-app toast ──────────────────────────────────────────────────────────
  NotificationModel? _toastNotification;
  NotificationModel? get toastNotification => _toastNotification;

  List<NotificationModel> get notifications => _notifications;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  void startNotificationsListener(String userId) {
    _notificationsSubscription?.cancel();
    _errorMessage = null;
    _isLoading = true;
    notifyListeners();

    _notificationsSubscription =
        _notificationService.streamUserNotifications(userId).listen(
      (data) async {
        final previousLatestId = _latestNotificationId;
        final newLatestId = data.isNotEmpty ? data.first.id : null;

        final isNew =
            previousLatestId != null &&
            newLatestId != null &&
            previousLatestId != newLatestId &&
            data.first.isRead == false;

        _notifications = data;
        _latestNotificationId = newLatestId;
        _isLoading = false;
        notifyListeners();

        if (isNew) {
          final notif = data.first;
          _playSound(notif.type);
          _showToast(notif);
        }
      },
      onError: (_) {
        _errorMessage = 'Failed to load notifications';
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  Future<void> _playSound(String type) async {
    try {
      await _audioPlayer.stop();
      final isDelivery = _deliverySoundTypes.contains(type);
      final asset = isDelivery
          ? 'sounds/delivered.mp3'
          : 'sounds/notification.mp3';
      await _audioPlayer.play(AssetSource(asset), volume: 1.0);
    } catch (_) {}
  }

  void _showToast(NotificationModel notif) {
    _toastNotification = notif;
    notifyListeners();
    // Auto-dismiss after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      if (_toastNotification?.id == notif.id) {
        _toastNotification = null;
        notifyListeners();
      }
    });
  }

  void dismissToast() {
    _toastNotification = null;
    notifyListeners();
  }

  void stopNotificationsListener() {
    _notificationsSubscription?.cancel();
    _notificationsSubscription = null;
  }

  Future<void> createNotification({
    required String userId,
    required String orderId,
    required String message,
    String title = 'Order Update',
    String type = 'order_update',
  }) async {
    try {
      await _notificationService.createNotification(
        userId: userId,
        orderId: orderId,
        message: message,
        title: title,
        type: type,
      );
    } catch (_) {
      _errorMessage = 'Failed to create notification';
      notifyListeners();
    }
  }

  Future<void> markNotificationAsRead(String notificationId) async {
    try {
      await _notificationService.markNotificationAsRead(notificationId);
      final i = _notifications.indexWhere((n) => n.id == notificationId);
      if (i != -1) {
        _notifications[i] = _notifications[i].copyWith(isRead: true);
        notifyListeners();
      }
    } catch (_) {
      _errorMessage = 'Failed to update notification';
      notifyListeners();
    }
  }

  Future<void> markAllNotificationsAsRead(String userId) async {
    try {
      await _notificationService.markAllNotificationsAsRead(userId);
      _notifications = _notifications.map((n) => n.copyWith(isRead: true)).toList();
      notifyListeners();
    } catch (_) {
      _errorMessage = 'Failed to update notifications';
      notifyListeners();
    }
  }

  void clearNotifications() {
    _notifications = [];
    _latestNotificationId = null;
    _toastNotification = null;
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _notificationsSubscription?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }
}
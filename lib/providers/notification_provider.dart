import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../models/notification_model.dart';
import '../services/notification_service.dart';

class NotificationProvider extends ChangeNotifier {
  final NotificationService _notificationService = NotificationService();
  final AudioPlayer _audioPlayer = AudioPlayer();

  List<NotificationModel> _notifications = [];
  bool _isLoading = false;
  String? _errorMessage;

  // FIX: Track which userId the listener belongs to.
  // This prevents NotificationScreen.dispose() from accidentally cancelling
  // the global listener that SellerHomeScreen started.
  String? _listeningForUserId;
  StreamSubscription<List<NotificationModel>>? _notificationsSubscription;
  String? _latestNotificationId;

  List<NotificationModel> get notifications => _notifications;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  // FIX: If we're already listening for this exact userId, do nothing.
  // This prevents SellerHomeScreen and NotificationScreen from creating
  // duplicate or conflicting subscriptions.
  void startNotificationsListener(String userId) {
    if (_listeningForUserId == userId &&
        _notificationsSubscription != null) {
      // Already listening — don't restart, just return.
      debugPrint('NotificationProvider: already listening for $userId, skip restart.');
      return;
    }

    _notificationsSubscription?.cancel();
    _listeningForUserId = userId;
    _errorMessage = null;
    _isLoading = true;
    notifyListeners();

    _notificationsSubscription =
        _notificationService.streamUserNotifications(userId).listen(
      (data) async {
        final previousLatestId = _latestNotificationId;
        final newLatestId = data.isNotEmpty ? data.first.id : null;

        final shouldPlaySound =
            previousLatestId != null &&
            newLatestId != null &&
            previousLatestId != newLatestId &&
            data.first.isRead == false;

        _notifications = data;
        _latestNotificationId = newLatestId;
        _isLoading = false;
        notifyListeners();

        if (shouldPlaySound) {
          try {
            await _audioPlayer.stop();
            await _audioPlayer.play(
              AssetSource('sounds/notification.mp3'),
              volume: 1.0,
            );
          } catch (_) {}
        }
      },
      onError: (error) {
        _errorMessage = 'Failed to load notifications';
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  // FIX: stopNotificationsListener now only cancels the subscription if
  // called with the matching userId — OR if called with no userId (full stop).
  // NotificationScreen calls this on dispose with its userId, but because
  // SellerHomeScreen started the listener first (same userId), this is now
  // a no-op when called from NotificationScreen.dispose(), preventing the
  // listener from being killed prematurely.
  void stopNotificationsListener({String? userId}) {
    if (userId != null && userId != _listeningForUserId) {
      // A different screen is asking to stop — ignore it.
      debugPrint('NotificationProvider: ignoring stop request from $userId (listening for $_listeningForUserId)');
      return;
    }

    _notificationsSubscription?.cancel();
    _notificationsSubscription = null;
    _listeningForUserId = null;
    debugPrint('NotificationProvider: stopped listener.');
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
        _notifications[index] = _notifications[index].copyWith(isRead: true);
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = 'Failed to update notification';
      notifyListeners();
    }
  }

  Future<void> markAllNotificationsAsRead(String userId) async {
    try {
      await _notificationService.markAllNotificationsAsRead(userId);
      _notifications = _notifications
          .map((n) => n.copyWith(isRead: true))
          .toList();
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to update notifications';
      notifyListeners();
    }
  }

  void clearNotifications() {
    _notifications = [];
    _latestNotificationId = null;
    _listeningForUserId = null;
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
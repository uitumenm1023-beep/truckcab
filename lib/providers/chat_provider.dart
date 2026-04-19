import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/chat_service.dart';

class ChatProvider extends ChangeNotifier {
  final ChatService _chatService = ChatService();

  List<QueryDocumentSnapshot> _chatRequests = [];
  List<QueryDocumentSnapshot> _chats = [];
  List<QueryDocumentSnapshot> _messages = [];

  bool _isLoading = false;
  String? _errorMessage;

  StreamSubscription<QuerySnapshot>? _chatRequestsSubscription;
  StreamSubscription<QuerySnapshot>? _chatsSubscription;
  StreamSubscription<QuerySnapshot>? _messagesSubscription;

  List<QueryDocumentSnapshot> get chatRequests => _chatRequests;
  List<QueryDocumentSnapshot> get chats => _chats;
  List<QueryDocumentSnapshot> get messages => _messages;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void startSellerChatRequestsListener(String sellerId) {
    _chatRequestsSubscription?.cancel();
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _chatRequestsSubscription =
        _chatService.getChatRequestsForSeller(sellerId).listen(
      (snapshot) {
        _chatRequests = snapshot.docs;
        _isLoading = false;
        notifyListeners();
      },
      onError: (_) {
        _errorMessage = 'Failed to load chat requests.';
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  void stopSellerChatRequestsListener() {
    _chatRequestsSubscription?.cancel();
    _chatRequestsSubscription = null;
  }

  void startChatsListener(String userId) {
    _chatsSubscription?.cancel();
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _chatsSubscription = _chatService.getUserChats(userId).listen(
      (snapshot) {
        _chats = snapshot.docs;
        _isLoading = false;
        notifyListeners();
      },
      onError: (_) {
        _errorMessage = 'Failed to load chats.';
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  void stopChatsListener() {
    _chatsSubscription?.cancel();
    _chatsSubscription = null;
  }

  void startMessagesListener(String chatId) {
    _messagesSubscription?.cancel();
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _messagesSubscription = _chatService.getMessages(chatId).listen(
      (snapshot) {
        _messages = snapshot.docs;
        _isLoading = false;
        notifyListeners();
      },
      onError: (_) {
        _errorMessage = 'Failed to load messages.';
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  void stopMessagesListener() {
    _messagesSubscription?.cancel();
    _messagesSubscription = null;
  }

  Future<bool> sendChatRequest({
    required String orderId,
    required String sellerId,
    required String driverId,
    required String orderDescription,
    required String pickupLocation,
    required String dropoffLocation,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      await _chatService.sendChatRequest(
        orderId: orderId,
        sellerId: sellerId,
        driverId: driverId,
        orderDescription: orderDescription,
        pickupLocation: pickupLocation,
        dropoffLocation: dropoffLocation,
      );
      return true;
    } catch (_) {
      _errorMessage = 'Failed to send chat request.';
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> acceptChatRequest({
    required String requestId,
    required Map<String, dynamic> requestData,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      await _chatService.acceptChatRequest(
        requestId: requestId,
        requestData: requestData,
      );
      return true;
    } catch (_) {
      _errorMessage = 'Failed to open chat.';
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> confirmDriverForDelivery({
    required String requestId,
    required Map<String, dynamic> requestData,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      await _chatService.confirmDriverForDelivery(
        requestId: requestId,
        requestData: requestData,
      );
      return true;
    } catch (_) {
      _errorMessage = 'Failed to confirm driver for delivery.';
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> rejectChatRequest(String requestId) async {
    _setLoading(true);
    _clearError();

    try {
      await _chatService.rejectChatRequest(requestId);
      return true;
    } catch (_) {
      _errorMessage = 'Failed to reject chat request.';
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> sendMessage({
    required String chatId,
    required String senderId,
    required String text,
  }) async {
    _clearError();

    try {
      await _chatService.sendMessage(
        chatId: chatId,
        senderId: senderId,
        text: text,
      );
      return true;
    } catch (_) {
      _errorMessage = 'Failed to send message.';
      notifyListeners();
      return false;
    }
  }

  Future<void> markMessagesAsRead({
    required String chatId,
    required String currentUserId,
  }) async {
    try {
      await _chatService.markMessagesAsRead(
        chatId: chatId,
        currentUserId: currentUserId,
      );
    } catch (_) {
      _errorMessage = 'Failed to mark messages as read.';
      notifyListeners();
    }
  }

  void clearChatState() {
    _chatRequests = [];
    _chats = [];
    _messages = [];
    _errorMessage = null;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
  }

  @override
  void dispose() {
    _chatRequestsSubscription?.cancel();
    _chatsSubscription?.cancel();
    _messagesSubscription?.cancel();
    super.dispose();
  }
}
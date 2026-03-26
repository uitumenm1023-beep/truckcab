import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../core/constants/app_status.dart';
import 'notification_service.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();

  // ─── Chat Requests ────────────────────────────────────────────────────────

  Stream<QuerySnapshot> getChatRequestsForSeller(String sellerId) {
    return _firestore
        .collection('chat_requests')
        .where('sellerId', isEqualTo: sellerId)
        .where('status', whereIn: ['pending', 'chat_open'])
        .snapshots();
  }

  // FIX: acceptChatRequest now also notifies the DRIVER that the seller
  // opened the chat, so the chat shows up immediately on the driver side.
  Future<void> acceptChatRequest({
    required String requestId,
    required Map<String, dynamic> requestData,
  }) async {
    final chatRef = _firestore.collection('chats').doc(requestId);
    final requestRef = _firestore.collection('chat_requests').doc(requestId);

    await _firestore.runTransaction((transaction) async {
      transaction.set(chatRef, {
        'orderId': requestData['orderId'],
        'sellerId': requestData['sellerId'],
        'driverId': requestData['driverId'],
        'orderDescription': requestData['orderDescription'],
        'pickupLocation': requestData['pickupLocation'],
        'dropoffLocation': requestData['dropoffLocation'],
        'participantIds': [
          requestData['sellerId'],
          requestData['driverId'],
        ],
        'lastMessage': '',
        'lastMessageSenderId': '',
        'lastMessageAt': null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      transaction.update(requestRef, {
        'status': 'chat_open',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    // FIX: notify the driver that the seller accepted and chat is open.
    // This is why the chat was not appearing in the driver's chat section —
    // the driver had no signal to refresh/navigate to chat.
    final driverId = (requestData['driverId'] ?? '').toString();
    final orderId = (requestData['orderId'] ?? '').toString();
    final sellerId = (requestData['sellerId'] ?? '').toString();
    // chatId = requestId (they share the same id: orderId_sellerId_driverId)
    final chatId = requestId;
    if (driverId.isNotEmpty && orderId.isNotEmpty) {
      try {
        await _notificationService.createNotification(
          userId: driverId,
          orderId: orderId,
          chatId: chatId,
          title: 'Chat Request Accepted',
          message: 'The seller accepted your request. You can now chat.',
          type: 'chat_accepted',
        );
        debugPrint('acceptChatRequest: driver notified driverId=$driverId');
      } catch (e) {
        debugPrint('acceptChatRequest notification error: $e');
      }
    }
  }

  Future<void> confirmDriverForDelivery({
    required String requestId,
    required Map<String, dynamic> requestData,
  }) async {
    final requestRef = _firestore.collection('chat_requests').doc(requestId);
    final orderRef = _firestore
        .collection('orders')
        .doc((requestData['orderId'] ?? '').toString());

    await _firestore.runTransaction((transaction) async {
      transaction.update(requestRef, {
        'status': 'approved',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      transaction.update(orderRef, {
        'driverId': requestData['driverId'],
        'status': AppStatus.accepted,
      });
    });

    // Notify driver that they are confirmed for delivery
    final driverId = (requestData['driverId'] ?? '').toString();
    final orderId = (requestData['orderId'] ?? '').toString();
    final chatId = requestId; // same id as chat_request doc
    if (driverId.isNotEmpty && orderId.isNotEmpty) {
      try {
        await _notificationService.createNotification(
          userId: driverId,
          orderId: orderId,
          chatId: chatId,
          title: 'Delivery Approved',
          message: 'The seller approved you for delivery. You can start now.',
          type: 'delivery_approved',
        );
        debugPrint('confirmDriverForDelivery: driver notified driverId=$driverId');
      } catch (e) {
        debugPrint('confirmDriverForDelivery notification error: $e');
      }
    }
  }

  Future<void> rejectChatRequest(String requestId) async {
    // Fetch first so we can notify the driver
    final doc = await _firestore
        .collection('chat_requests')
        .doc(requestId)
        .get();
    final data = doc.data() ?? {};

    await _firestore.collection('chat_requests').doc(requestId).update({
      'status': 'rejected',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final driverId = (data['driverId'] ?? '').toString();
    final orderId  = (data['orderId']  ?? '').toString();
    if (driverId.isNotEmpty && orderId.isNotEmpty) {
      try {
        await _notificationService.createNotification(
          userId:  driverId,
          orderId: orderId,
          chatId:  requestId,
          title:   'Request Rejected',
          message: 'The seller rejected your delivery request.',
          type:    'chat_rejected',
        );
      } catch (e) {
        debugPrint('rejectChatRequest notification error: $e');
      }
    }
  }

  // ─── Chats ────────────────────────────────────────────────────────────────

  // getUserChats uses only a simple where filter — no orderBy — so it works
  // without a composite Firestore index. We sort client-side in ChatProvider.
  Stream<QuerySnapshot> getUserChats(String userId) {
    return _firestore
        .collection('chats')
        .where('participantIds', arrayContains: userId)
        .snapshots();
  }

  // ─── Messages ────────────────────────────────────────────────────────────

  // FIX: Messages are stored in a Firestore subcollection under the chat doc.
  // They persist indefinitely until explicitly deleted. The stream stays
  // active as long as the ChatScreen is open, and re-subscribes on return.
  Stream<QuerySnapshot> getMessages(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // FIX: sendMessage now fetches the chat participants and creates a
  // notification for the OTHER participant (not the sender).
  // This is what was missing — messages were saved but no one was notified.
  Future<void> sendMessage({
    required String chatId,
    required String senderId,
    required String text,
  }) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty) return;

    final messageRef = _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc();

    final chatRef = _firestore.collection('chats').doc(chatId);

    // Fetch chat doc to get participant info for notification
    final chatSnapshot = await chatRef.get();
    final chatData = chatSnapshot.data() ?? {};
    final participantIds = (chatData['participantIds'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList();
    final orderId = (chatData['orderId'] ?? '').toString();

    // Determine who the OTHER participant is (the one to notify)
    final recipientId = participantIds.firstWhere(
      (id) => id != senderId,
      orElse: () => '',
    );

    // Save the message and update chat's lastMessage atomically
    await _firestore.runTransaction((transaction) async {
      transaction.set(messageRef, {
        'chatId': chatId,
        'senderId': senderId,
        'text': cleanText,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      transaction.update(chatRef, {
        'lastMessage': cleanText,
        'lastMessageSenderId': senderId,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    // FIX: notify the recipient of the new message
    if (recipientId.isNotEmpty && orderId.isNotEmpty) {
      try {
        final preview = cleanText.length > 60
            ? '${cleanText.substring(0, 60)}...'
            : cleanText;

        await _notificationService.createNotification(
          userId: recipientId,
          orderId: orderId,
          chatId: chatId,
          title: 'New Message',
          message: preview,
          type: 'chat_message',
        );
        debugPrint('sendMessage: notified recipientId=$recipientId');
      } catch (e) {
        debugPrint('sendMessage notification error: $e');
        // Don't rethrow — message was sent successfully
      }
    }
  }

  Future<void> markMessagesAsRead({
    required String chatId,
    required String currentUserId,
  }) async {
    final messages = await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .where('isRead', isEqualTo: false)
        .get();

    // Use a batch for efficiency instead of sequential individual updates
    final batch = _firestore.batch();
    for (final doc in messages.docs) {
      final data = doc.data();
      if ((data['senderId'] ?? '').toString() != currentUserId) {
        batch.update(doc.reference, {'isRead': true});
      }
    }
    await batch.commit();
  }

  // ─── Delete Chat ──────────────────────────────────────────────────────────

  // Deletes all messages in a chat and the chat doc itself.
  // Called when a user chooses to delete a conversation.
  Future<void> deleteChat(String chatId) async {
    // Delete all messages in the subcollection first
    final messages = await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .get();

    final batch = _firestore.batch();
    for (final doc in messages.docs) {
      batch.delete(doc.reference);
    }
    // Delete the chat doc itself
    batch.delete(_firestore.collection('chats').doc(chatId));
    await batch.commit();

    debugPrint('deleteChat: deleted chatId=$chatId with ${messages.docs.length} messages');
  }
}
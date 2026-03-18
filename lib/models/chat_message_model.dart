import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessageModel {
  final String id;
  final String chatId;
  final String senderId;
  final String text;
  final bool isRead;
  final DateTime? createdAt;

  ChatMessageModel({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.text,
    required this.isRead,
    required this.createdAt,
  });

  factory ChatMessageModel.fromFirestore(DocumentSnapshot doc) {
    final raw = doc.data();
    final data = raw is Map<String, dynamic> ? raw : <String, dynamic>{};

    return ChatMessageModel(
      id: doc.id,
      chatId: (data['chatId'] ?? '').toString(),
      senderId: (data['senderId'] ?? '').toString(),
      text: (data['text'] ?? '').toString(),
      isRead: (data['isRead'] ?? false) as bool,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'chatId': chatId,
      'senderId': senderId,
      'text': text,
      'isRead': isRead,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
    };
  }

  ChatMessageModel copyWith({
    String? id,
    String? chatId,
    String? senderId,
    String? text,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return ChatMessageModel(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      senderId: senderId ?? this.senderId,
      text: text ?? this.text,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
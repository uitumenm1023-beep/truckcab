import 'package:cloud_firestore/cloud_firestore.dart';

class ChatModel {
  final String id;
  final String orderId;
  final String sellerId;
  final String driverId;
  final String orderDescription;
  final String pickupLocation;
  final String dropoffLocation;
  final List<String> participantIds;
  final String lastMessage;
  final String lastMessageSenderId;
  final DateTime? lastMessageAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ChatModel({
    required this.id,
    required this.orderId,
    required this.sellerId,
    required this.driverId,
    required this.orderDescription,
    required this.pickupLocation,
    required this.dropoffLocation,
    required this.participantIds,
    required this.lastMessage,
    required this.lastMessageSenderId,
    required this.lastMessageAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ChatModel.fromFirestore(DocumentSnapshot doc) {
    final raw = doc.data();
    final data = raw is Map<String, dynamic> ? raw : <String, dynamic>{};

    return ChatModel(
      id: doc.id,
      orderId: (data['orderId'] ?? '').toString(),
      sellerId: (data['sellerId'] ?? '').toString(),
      driverId: (data['driverId'] ?? '').toString(),
      orderDescription: (data['orderDescription'] ?? '').toString(),
      pickupLocation: (data['pickupLocation'] ?? '').toString(),
      dropoffLocation: (data['dropoffLocation'] ?? '').toString(),
      participantIds: (data['participantIds'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      lastMessage: (data['lastMessage'] ?? '').toString(),
      lastMessageSenderId: (data['lastMessageSenderId'] ?? '').toString(),
      lastMessageAt: (data['lastMessageAt'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'orderId': orderId,
      'sellerId': sellerId,
      'driverId': driverId,
      'orderDescription': orderDescription,
      'pickupLocation': pickupLocation,
      'dropoffLocation': dropoffLocation,
      'participantIds': participantIds,
      'lastMessage': lastMessage,
      'lastMessageSenderId': lastMessageSenderId,
      'lastMessageAt': lastMessageAt != null
          ? Timestamp.fromDate(lastMessageAt!)
          : null,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'updatedAt': updatedAt != null
          ? Timestamp.fromDate(updatedAt!)
          : FieldValue.serverTimestamp(),
    };
  }

  ChatModel copyWith({
    String? id,
    String? orderId,
    String? sellerId,
    String? driverId,
    String? orderDescription,
    String? pickupLocation,
    String? dropoffLocation,
    List<String>? participantIds,
    String? lastMessage,
    String? lastMessageSenderId,
    DateTime? lastMessageAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ChatModel(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      sellerId: sellerId ?? this.sellerId,
      driverId: driverId ?? this.driverId,
      orderDescription: orderDescription ?? this.orderDescription,
      pickupLocation: pickupLocation ?? this.pickupLocation,
      dropoffLocation: dropoffLocation ?? this.dropoffLocation,
      participantIds: participantIds ?? this.participantIds,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageSenderId: lastMessageSenderId ?? this.lastMessageSenderId,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
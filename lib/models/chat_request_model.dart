import 'package:cloud_firestore/cloud_firestore.dart';

class ChatRequestModel {
  final String id;
  final String orderId;
  final String sellerId;
  final String driverId;
  final String orderDescription;
  final String pickupLocation;
  final String dropoffLocation;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ChatRequestModel({
    required this.id,
    required this.orderId,
    required this.sellerId,
    required this.driverId,
    required this.orderDescription,
    required this.pickupLocation,
    required this.dropoffLocation,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ChatRequestModel.fromFirestore(DocumentSnapshot doc) {
    final raw = doc.data();
    final data = raw is Map<String, dynamic> ? raw : <String, dynamic>{};

    return ChatRequestModel(
      id: doc.id,
      orderId: (data['orderId'] ?? '').toString(),
      sellerId: (data['sellerId'] ?? '').toString(),
      driverId: (data['driverId'] ?? '').toString(),
      orderDescription: (data['orderDescription'] ?? '').toString(),
      pickupLocation: (data['pickupLocation'] ?? '').toString(),
      dropoffLocation: (data['dropoffLocation'] ?? '').toString(),
      status: (data['status'] ?? 'pending').toString(),
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
      'status': status,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'updatedAt': updatedAt != null
          ? Timestamp.fromDate(updatedAt!)
          : FieldValue.serverTimestamp(),
    };
  }

  ChatRequestModel copyWith({
    String? id,
    String? orderId,
    String? sellerId,
    String? driverId,
    String? orderDescription,
    String? pickupLocation,
    String? dropoffLocation,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ChatRequestModel(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      sellerId: sellerId ?? this.sellerId,
      driverId: driverId ?? this.driverId,
      orderDescription: orderDescription ?? this.orderDescription,
      pickupLocation: pickupLocation ?? this.pickupLocation,
      dropoffLocation: dropoffLocation ?? this.dropoffLocation,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
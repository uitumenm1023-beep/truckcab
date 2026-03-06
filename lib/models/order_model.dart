import 'package:cloud_firestore/cloud_firestore.dart';

class OrderModel {
  final String id;
  final String sellerId;
  final String? driverId;
  final String pickupLocation;
  final String dropoffLocation;
  final String description;
  final double price;
  final String status;
  final DateTime? createdAt;

  OrderModel({
    required this.id,
    required this.sellerId,
    required this.driverId,
    required this.pickupLocation,
    required this.dropoffLocation,
    required this.description,
    required this.price,
    required this.status,
    required this.createdAt,
  });

  factory OrderModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return OrderModel(
      id: doc.id,
      sellerId: data['sellerId'] ?? '',
      driverId: data['driverId'],
      pickupLocation: data['pickupLocation'] ?? '',
      dropoffLocation: data['dropoffLocation'] ?? '',
      description: data['description'] ?? '',
      price: (data['price'] ?? 0).toDouble(),
      status: data['status'] ?? 'OPEN',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sellerId': sellerId,
      'driverId': driverId,
      'pickupLocation': pickupLocation,
      'dropoffLocation': dropoffLocation,
      'description': description,
      'price': price,
      'status': status,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
    };
  }

  OrderModel copyWith({
    String? id,
    String? sellerId,
    String? driverId,
    String? pickupLocation,
    String? dropoffLocation,
    String? description,
    double? price,
    String? status,
    DateTime? createdAt,
  }) {
    return OrderModel(
      id: id ?? this.id,
      sellerId: sellerId ?? this.sellerId,
      driverId: driverId ?? this.driverId,
      pickupLocation: pickupLocation ?? this.pickupLocation,
      dropoffLocation: dropoffLocation ?? this.dropoffLocation,
      description: description ?? this.description,
      price: price ?? this.price,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
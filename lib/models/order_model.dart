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
  // Optional coordinates for map-based location picking
  final double? pickupLat;
  final double? pickupLng;
  final double? dropoffLat;
  final double? dropoffLng;
  // Photo URLs uploaded by seller
  final List<String> imageUrls;

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
    this.pickupLat,
    this.pickupLng,
    this.dropoffLat,
    this.dropoffLng,
    this.imageUrls = const [],
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
      pickupLat: (data['pickupLat'] as num?)?.toDouble(),
      pickupLng: (data['pickupLng'] as num?)?.toDouble(),
      dropoffLat: (data['dropoffLat'] as num?)?.toDouble(),
      dropoffLng: (data['dropoffLng'] as num?)?.toDouble(),
      imageUrls: List<String>.from(data['imageUrls'] ?? []),
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
      if (pickupLat != null) 'pickupLat': pickupLat,
      if (pickupLng != null) 'pickupLng': pickupLng,
      if (dropoffLat != null) 'dropoffLat': dropoffLat,
      if (dropoffLng != null) 'dropoffLng': dropoffLng,
      'imageUrls': imageUrls,
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
    double? pickupLat,
    double? pickupLng,
    double? dropoffLat,
    double? dropoffLng,
    List<String>? imageUrls,
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
      pickupLat: pickupLat ?? this.pickupLat,
      pickupLng: pickupLng ?? this.pickupLng,
      dropoffLat: dropoffLat ?? this.dropoffLat,
      dropoffLng: dropoffLng ?? this.dropoffLng,
      imageUrls: imageUrls ?? this.imageUrls,
    );
  }
}
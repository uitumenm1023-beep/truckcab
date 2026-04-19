import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String userId;
  final String email;
  final String name;
  final DateTime? birthdate;
  final String role;
  final bool isOnline;
  final DateTime? lastSeen;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Driver-only fields
  final String vehicleType;      // 'suv' | 'small_truck' | 'medium_truck' | 'big_truck'
  final int yearsExperience;
  final bool hasCrash;
  final int crashCount;

  // Subscription fields
  final DateTime? subscriptionExpiry;
  final bool isAdmin;

  UserModel({
    required this.userId,
    required this.email,
    this.name = '',
    this.birthdate,
    required this.role,
    required this.isOnline,
    required this.lastSeen,
    required this.createdAt,
    required this.updatedAt,
    this.vehicleType = '',
    this.yearsExperience = 0,
    this.hasCrash = false,
    this.crashCount = 0,
    this.subscriptionExpiry,
    this.isAdmin = false,
  });

  /// Returns name if set, otherwise email prefix.
  String get displayName =>
      name.isNotEmpty ? name : email.split('@').first;

  bool get isSubscriptionActive {
    if (isAdmin) return true;
    if (subscriptionExpiry == null) return false;
    return subscriptionExpiry!.isAfter(DateTime.now());
  }

  factory UserModel.fromMap(Map<String, dynamic> data) {
    return UserModel(
      userId: (data['userId'] ?? '').toString(),
      email: (data['email'] ?? '').toString(),
      name: (data['name'] ?? '').toString(),
      birthdate: (data['birthdate'] as Timestamp?)?.toDate(),
      role: (data['role'] ?? '').toString(),
      isOnline: data['isOnline'] == true,
      lastSeen: (data['lastSeen'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      vehicleType: (data['vehicleType'] ?? '').toString(),
      yearsExperience: (data['yearsExperience'] as num?)?.toInt() ?? 0,
      hasCrash: data['hasCrash'] == true,
      crashCount: (data['crashCount'] as num?)?.toInt() ?? 0,
      subscriptionExpiry: (data['subscriptionExpiry'] as Timestamp?)?.toDate(),
      isAdmin: data['isAdmin'] == true,
    );
  }

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final raw = doc.data();
    final data = raw is Map<String, dynamic> ? raw : <String, dynamic>{};
    return UserModel.fromMap(data);
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'email': email,
      'name': name,
      'birthdate': birthdate != null
          ? Timestamp.fromDate(birthdate!)
          : null,
      'role': role,
      'isOnline': isOnline,
      'vehicleType': vehicleType,
      'yearsExperience': yearsExperience,
      'hasCrash': hasCrash,
      'crashCount': crashCount,
      'subscriptionExpiry': subscriptionExpiry != null
          ? Timestamp.fromDate(subscriptionExpiry!)
          : null,
      'isAdmin': isAdmin,
      'lastSeen': lastSeen != null
          ? Timestamp.fromDate(lastSeen!)
          : FieldValue.serverTimestamp(),
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'updatedAt': updatedAt != null
          ? Timestamp.fromDate(updatedAt!)
          : FieldValue.serverTimestamp(),
    };
  }

  UserModel copyWith({
    String? userId,
    String? email,
    String? name,
    DateTime? birthdate,
    String? role,
    bool? isOnline,
    DateTime? lastSeen,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? vehicleType,
    int? yearsExperience,
    bool? hasCrash,
    int? crashCount,
    DateTime? subscriptionExpiry,
    bool? isAdmin,
  }) {
    return UserModel(
      userId: userId ?? this.userId,
      email: email ?? this.email,
      name: name ?? this.name,
      birthdate: birthdate ?? this.birthdate,
      role: role ?? this.role,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      vehicleType: vehicleType ?? this.vehicleType,
      yearsExperience: yearsExperience ?? this.yearsExperience,
      hasCrash: hasCrash ?? this.hasCrash,
      crashCount: crashCount ?? this.crashCount,
      subscriptionExpiry: subscriptionExpiry ?? this.subscriptionExpiry,
      isAdmin: isAdmin ?? this.isAdmin,
    );
  }
}
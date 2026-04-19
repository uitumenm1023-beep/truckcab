import 'package:cloud_firestore/cloud_firestore.dart';

class PaymentModel {
  final String id;
  final String userId;
  final String userName;
  final String userEmail;
  final double amount;
  final String bankRef;       // reference number user provides
  final String status;        // 'pending' | 'approved' | 'rejected'
  final DateTime? submittedAt;
  final DateTime? processedAt;
  final String? processedBy;  // admin UID who approved/rejected
  final String? note;         // admin's note on rejection

  PaymentModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.amount,
    required this.bankRef,
    required this.status,
    this.submittedAt,
    this.processedAt,
    this.processedBy,
    this.note,
  });

  factory PaymentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PaymentModel(
      id: doc.id,
      userId: (data['userId'] ?? '').toString(),
      userName: (data['userName'] ?? '').toString(),
      userEmail: (data['userEmail'] ?? '').toString(),
      amount: (data['amount'] as num?)?.toDouble() ?? 9900,
      bankRef: (data['bankRef'] ?? '').toString(),
      status: (data['status'] ?? 'pending').toString(),
      submittedAt: (data['submittedAt'] as Timestamp?)?.toDate(),
      processedAt: (data['processedAt'] as Timestamp?)?.toDate(),
      processedBy: data['processedBy']?.toString(),
      note: data['note']?.toString(),
    );
  }

  Map<String, dynamic> toMap() => {
    'userId': userId,
    'userName': userName,
    'userEmail': userEmail,
    'amount': amount,
    'bankRef': bankRef,
    'status': status,
    'submittedAt': submittedAt != null
        ? Timestamp.fromDate(submittedAt!)
        : FieldValue.serverTimestamp(),
    if (processedAt != null) 'processedAt': Timestamp.fromDate(processedAt!),
    if (processedBy != null) 'processedBy': processedBy,
    if (note != null) 'note': note,
  };
}

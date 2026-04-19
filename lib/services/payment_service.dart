import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/payment_model.dart';

class PaymentService {
  final FirebaseFirestore _fs = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _payments =>
      _fs.collection('payments');

  /// User submits a payment request.
  Future<void> submitPayment({
    required String userId,
    required String userName,
    required String userEmail,
    required String bankRef,
    double amount = 9900,
  }) async {
    try {
      await _payments.add({
        'userId': userId,
        'userName': userName,
        'userEmail': userEmail,
        'amount': amount,
        'bankRef': bankRef.trim(),
        'status': 'pending',
        'submittedAt': FieldValue.serverTimestamp(),
      });
    } catch (e, st) {
      debugPrint('submitPayment error: $e\n$st');
      throw Exception('Failed to submit payment');
    }
  }

  /// Stream all pending payments (admin use).
  Stream<List<PaymentModel>> streamPendingPayments() {
    return _payments
        .where('status', isEqualTo: 'pending')
        .orderBy('submittedAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(PaymentModel.fromFirestore).toList());
  }

  /// Stream all payments (admin use).
  Stream<List<PaymentModel>> streamAllPayments() {
    return _payments
        .orderBy('submittedAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(PaymentModel.fromFirestore).toList());
  }

  /// Stream payments for a specific user.
  Stream<List<PaymentModel>> streamUserPayments(String userId) {
    return _payments
        .where('userId', isEqualTo: userId)
        .orderBy('submittedAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(PaymentModel.fromFirestore).toList());
  }

  /// Admin approves a payment → sets user subscriptionExpiry to now + 30 days.
  Future<void> approvePayment({
    required String paymentId,
    required String userId,
    required String adminId,
  }) async {
    final batch = _fs.batch();

    final expiry = DateTime.now().add(const Duration(days: 30));

    batch.update(_payments.doc(paymentId), {
      'status': 'approved',
      'processedAt': FieldValue.serverTimestamp(),
      'processedBy': adminId,
    });

    batch.set(
      _fs.collection('users').doc(userId),
      {
        'subscriptionExpiry': Timestamp.fromDate(expiry),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    await batch.commit();
  }

  /// Admin rejects a payment with an optional note.
  Future<void> rejectPayment({
    required String paymentId,
    required String adminId,
    String? note,
  }) async {
    await _payments.doc(paymentId).update({
      'status': 'rejected',
      'processedAt': FieldValue.serverTimestamp(),
      'processedBy': adminId,
      if (note != null && note.isNotEmpty) 'note': note,
    });
  }
}

import 'dart:async';

import 'package:flutter/material.dart';

import '../models/payment_model.dart';
import '../services/payment_service.dart';

class PaymentProvider extends ChangeNotifier {
  final PaymentService _svc = PaymentService();

  List<PaymentModel> _allPayments = [];
  List<PaymentModel> _userPayments = [];
  bool _isLoading = false;
  String? _errorMessage;

  StreamSubscription<List<PaymentModel>>? _allSub;
  StreamSubscription<List<PaymentModel>>? _userSub;

  List<PaymentModel> get allPayments => _allPayments;
  List<PaymentModel> get pendingPayments =>
      _allPayments.where((p) => p.status == 'pending').toList();
  List<PaymentModel> get userPayments => _userPayments;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  bool get hasActivePendingRequest =>
      _userPayments.any((p) => p.status == 'pending');

  // ── Admin: stream all payments ─────────────────────────────────────────────
  void startAllPaymentsListener() {
    _allSub?.cancel();
    _allSub = _svc.streamAllPayments().listen(
      (data) {
        _allPayments = data;
        notifyListeners();
      },
      onError: (_) {
        _errorMessage = 'Failed to load payments';
        notifyListeners();
      },
    );
  }

  void stopAllPaymentsListener() {
    _allSub?.cancel();
    _allSub = null;
  }

  // ── User: stream own payments ──────────────────────────────────────────────
  void startUserPaymentsListener(String userId) {
    _userSub?.cancel();
    _userSub = _svc.streamUserPayments(userId).listen(
      (data) {
        _userPayments = data;
        notifyListeners();
      },
      onError: (_) {
        _errorMessage = 'Failed to load your payment history';
        notifyListeners();
      },
    );
  }

  void stopUserPaymentsListener() {
    _userSub?.cancel();
    _userSub = null;
  }

  // ── Submit payment ─────────────────────────────────────────────────────────
  Future<bool> submitPayment({
    required String userId,
    required String userName,
    required String userEmail,
    required String bankRef,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _svc.submitPayment(
        userId: userId,
        userName: userName,
        userEmail: userEmail,
        bankRef: bankRef,
      );
      return true;
    } catch (_) {
      _errorMessage = 'Failed to submit payment. Please try again.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Admin: approve ─────────────────────────────────────────────────────────
  Future<bool> approvePayment({
    required String paymentId,
    required String userId,
    required String adminId,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _svc.approvePayment(
          paymentId: paymentId, userId: userId, adminId: adminId);
      return true;
    } catch (_) {
      _errorMessage = 'Failed to approve payment';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Admin: reject ──────────────────────────────────────────────────────────
  Future<bool> rejectPayment({
    required String paymentId,
    required String adminId,
    String? note,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _svc.rejectPayment(
          paymentId: paymentId, adminId: adminId, note: note);
      return true;
    } catch (_) {
      _errorMessage = 'Failed to reject payment';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _allSub?.cancel();
    _userSub?.cancel();
    super.dispose();
  }
}

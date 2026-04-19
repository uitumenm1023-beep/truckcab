import 'dart:async';

import 'package:flutter/material.dart';

import '../core/constants/app_status.dart';
import '../models/order_model.dart';
import '../services/chat_service.dart';
import '../services/order_service.dart';

class OrderProvider extends ChangeNotifier {
  final OrderService _orderService = OrderService();
  final ChatService _chatService = ChatService();

  List<OrderModel> _availableOrders = [];
  List<OrderModel> _sellerOrders = [];
  List<OrderModel> _driverActiveOrders = [];

  bool _isLoading = false;
  String? _errorMessage;

  StreamSubscription<List<OrderModel>>? _availableOrdersSubscription;
  StreamSubscription<List<OrderModel>>? _sellerOrdersSubscription;
  StreamSubscription<List<OrderModel>>? _driverActiveOrdersSubscription;

  List<OrderModel> get availableOrders => _availableOrders;
  List<OrderModel> get sellerOrders => _sellerOrders;
  List<OrderModel> get activeOrders => _driverActiveOrders;
  OrderModel? get activeOrder =>
      _driverActiveOrders.isNotEmpty ? _driverActiveOrders.first : null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchAvailableOrders() async {
    _setLoading(true);
    _clearError();

    try {
      final orders = await _orderService.getAvailableOrders();
      _availableOrders = orders;
      notifyListeners();
    } catch (_) {
      _errorMessage = 'Failed to load available orders.';
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  void startAvailableOrdersListener() {
    _availableOrdersSubscription?.cancel();
    _clearError();
    _setLoading(true);

    _availableOrdersSubscription =
        _orderService.streamAvailableOrders().listen(
      (orders) {
        _availableOrders = orders;
        _isLoading = false;
        notifyListeners();
      },
      onError: (_) {
        _errorMessage = 'Failed to load available orders.';
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  Future<void> fetchSellerOrders({
    required String sellerId,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final orders = await _orderService.getSellerOrders(sellerId: sellerId);
      _sellerOrders = orders;
      notifyListeners();
    } catch (_) {
      _errorMessage = 'Failed to load seller orders.';
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  void startSellerOrdersListener({
    required String sellerId,
  }) {
    _sellerOrdersSubscription?.cancel();
    _clearError();
    _setLoading(true);

    _sellerOrdersSubscription =
        _orderService.streamSellerOrders(sellerId: sellerId).listen(
      (orders) {
        _sellerOrders = orders;
        _isLoading = false;
        notifyListeners();
      },
      onError: (_) {
        _errorMessage = 'Failed to load seller orders.';
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  Future<void> fetchDriverActiveOrders({
    required String driverId,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final orders =
          await _orderService.getDriverActiveOrders(driverId: driverId);
      _driverActiveOrders = orders;
      notifyListeners();
    } catch (_) {
      _errorMessage = 'Failed to load active orders.';
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  void startDriverActiveOrderListener({
    required String driverId,
  }) {
    _driverActiveOrdersSubscription?.cancel();
    _clearError();
    _setLoading(true);

    _driverActiveOrdersSubscription =
        _orderService.streamDriverActiveOrders(driverId: driverId).listen(
      (orders) {
        _driverActiveOrders = orders;
        _isLoading = false;
        notifyListeners();
      },
      onError: (_) {
        _errorMessage = 'Failed to load active orders.';
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  Future<bool> createOrder({
    required String sellerId,
    required String pickupLocation,
    required String dropoffLocation,
    required String description,
    required double price,
    double? pickupLat,
    double? pickupLng,
    double? dropoffLat,
    double? dropoffLng,
    List<String>? imageUrls,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      await _orderService.createOrder(
        sellerId: sellerId,
        pickupLocation: pickupLocation,
        dropoffLocation: dropoffLocation,
        description: description,
        price: price,
        pickupLat: pickupLat,
        pickupLng: pickupLng,
        dropoffLat: dropoffLat,
        dropoffLng: dropoffLng,
        imageUrls: imageUrls,
      );
      return true;
    } catch (_) {
      _errorMessage = 'Failed to create order.';
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> acceptOrder({
    required String orderId,
    required String driverId,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final selectedOrder = _availableOrders.firstWhere(
        (order) => order.id == orderId,
      );

      await _chatService.sendChatRequest(
        orderId: selectedOrder.id,
        sellerId: selectedOrder.sellerId,
        driverId: driverId,
        orderDescription: selectedOrder.description,
        pickupLocation: selectedOrder.pickupLocation,
        dropoffLocation: selectedOrder.dropoffLocation,
      );

      notifyListeners();
      return true;
    } catch (_) {
      _errorMessage = 'Failed to send delivery request.';
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> updateOrderStatus({
    required String orderId,
    required String driverId,
    required String status,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final updatedOrder = await _orderService.updateOrderStatus(
        orderId: orderId,
        driverId: driverId,
        status: status,
      );

      if (status == AppStatus.delivered) {
        _driverActiveOrders.removeWhere((order) => order.id == orderId);
      } else {
        final activeIndex = _driverActiveOrders.indexWhere(
          (order) => order.id == updatedOrder.id,
        );

        if (activeIndex != -1) {
          _driverActiveOrders[activeIndex] = updatedOrder;
        } else {
          _driverActiveOrders.insert(0, updatedOrder);
        }
      }

      final sellerIndex =
          _sellerOrders.indexWhere((order) => order.id == updatedOrder.id);

      if (sellerIndex != -1) {
        _sellerOrders[sellerIndex] = updatedOrder;
      }

      final availableIndex =
          _availableOrders.indexWhere((order) => order.id == updatedOrder.id);

      if (availableIndex != -1) {
        _availableOrders[availableIndex] = updatedOrder;
      }

      notifyListeners();
      return true;
    } catch (_) {
      _errorMessage = 'Failed to update order status.';
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  void stopAvailableOrdersListener() {
    _availableOrdersSubscription?.cancel();
    _availableOrdersSubscription = null;
  }

  void stopSellerOrdersListener() {
    _sellerOrdersSubscription?.cancel();
    _sellerOrdersSubscription = null;
  }

  void stopDriverActiveOrderListener() {
    _driverActiveOrdersSubscription?.cancel();
    _driverActiveOrdersSubscription = null;
  }

  void clearActiveOrder() {
    _driverActiveOrders = [];
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
  }

  @override
  void dispose() {
    _availableOrdersSubscription?.cancel();
    _sellerOrdersSubscription?.cancel();
    _driverActiveOrdersSubscription?.cancel();
    super.dispose();
  }
}
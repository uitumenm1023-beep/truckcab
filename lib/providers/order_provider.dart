import 'dart:async';

import 'package:flutter/material.dart';

import '../core/constants/app_status.dart';
import '../models/order_model.dart';
import '../services/order_service.dart';

class OrderProvider extends ChangeNotifier {
  final OrderService _orderService = OrderService();

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

  // New: all active orders for driver
  List<OrderModel> get activeOrders => _driverActiveOrders;

  // Backward compatibility for screens that still use single active order
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
    } catch (e) {
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
    } catch (e) {
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
      final orders = await _orderService.getDriverActiveOrder(driverId: driverId);
      _driverActiveOrders = orders as List<OrderModel>;
      notifyListeners();
    } catch (e) {
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
        _orderService.streamDriverActiveOrder(driverId: driverId).listen(
      (orders) {
        _driverActiveOrders = orders as List<OrderModel>;
        _isLoading = false;
        notifyListeners();
      },
      onError: (_) {
        _errorMessage = 'Failed to load active orders.';
        _isLoading = false;
        notifyListeners();
      },
    ) as StreamSubscription<List<OrderModel>>?;
  }

  Future<bool> createOrder({
    required String sellerId,
    required String pickupLocation,
    required String dropoffLocation,
    required String description,
    required double price,
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
      );
      return true;
    } catch (e) {
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
      final updatedOrder = await _orderService.acceptOrder(
        orderId: orderId,
        driverId: driverId,
      );

      _availableOrders.removeWhere((order) => order.id == orderId);

      final activeIndex =
          _driverActiveOrders.indexWhere((order) => order.id == updatedOrder.id);

      if (activeIndex == -1) {
        _driverActiveOrders.insert(0, updatedOrder);
      } else {
        _driverActiveOrders[activeIndex] = updatedOrder;
      }

      final sellerIndex =
          _sellerOrders.indexWhere((order) => order.id == updatedOrder.id);

      if (sellerIndex != -1) {
        _sellerOrders[sellerIndex] = updatedOrder;
      }

      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to accept order.';
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
        final activeIndex =
            _driverActiveOrders.indexWhere((order) => order.id == updatedOrder.id);

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
    } catch (e) {
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
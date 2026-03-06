import 'package:flutter/material.dart';

import '../screens/auth/login_screen.dart';
import '../screens/auth/signup_screen.dart';
import '../screens/splash/splash_screen.dart';

import '../screens/seller/seller_home_screen.dart';
import '../screens/seller/create_order_screen.dart';
import '../screens/seller/seller_orders_screen.dart';

import '../screens/driver/driver_home_screen.dart';
import '../screens/driver/driver_dashboard.dart';
import '../screens/driver/driver_active_order.dart';

class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String signup = '/signup';

  static const String sellerHome = '/sellerHome';
  static const String createOrder = '/createOrder';
  static const String sellerOrders = '/sellerOrders';

  static const String driverHome = '/driverHome';
  static const String driverDashboard = '/driverDashboard';
  static const String driverActiveOrder = '/driverActiveOrder';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return MaterialPageRoute(builder: (_) => const SplashScreen());

      case login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());

      case signup:
        return MaterialPageRoute(builder: (_) => const SignupScreen());

      case sellerHome:
        return MaterialPageRoute(builder: (_) => const SellerHomeScreen());

      case createOrder:
        return MaterialPageRoute(builder: (_) => const CreateOrderScreen());

      case sellerOrders:
        return MaterialPageRoute(builder: (_) => const SellerOrdersScreen());

      case driverHome:
        return MaterialPageRoute(builder: (_) => const DriverHomeScreen());

      case driverDashboard:
        return MaterialPageRoute(builder: (_) => const DriverDashboard());

      case driverActiveOrder:
        return MaterialPageRoute(builder: (_) => const DriverActiveOrder());

      default:
        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(
              child: Text('Route not found'),
            ),
          ),
        );
    }
  }
}
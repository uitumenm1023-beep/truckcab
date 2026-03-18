import 'package:flutter/material.dart';

import '../screens/auth/login_screen.dart';
import '../screens/auth/signup_screen.dart';
import '../screens/chat/chat_list_screen.dart';
import '../screens/chat/chat_screen.dart';
import '../screens/driver/driver_active_order.dart';
import '../screens/driver/driver_dashboard.dart';
import '../screens/driver/driver_home_screen.dart';
import '../screens/notifications/notification_screen.dart';
import '../screens/seller/chat_requests_screen.dart';
import '../screens/seller/create_order_screen.dart';
import '../screens/seller/seller_home_screen.dart';
import '../screens/seller/seller_orders_screen.dart';
import '../screens/splash/splash_screen.dart';

class ChatScreenArgs {
  final String chatId;
  final String title;

  ChatScreenArgs({
    required this.chatId,
    required this.title,
  });
}

class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String signup = '/signup';

  static const String sellerHome = '/sellerHome';
  static const String createOrder = '/createOrder';
  static const String sellerOrders = '/sellerOrders';
  static const String chatRequests = '/chatRequests';
  static const String notifications = '/notifications';

  static const String driverHome = '/driverHome';
  static const String driverDashboard = '/driverDashboard';
  static const String driverActiveOrder = '/driverActiveOrder';

  static const String chatList = '/chatList';
  static const String chatScreen = '/chatScreen';

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

      case chatRequests:
        return MaterialPageRoute(builder: (_) => const ChatRequestsScreen());

      case notifications:
        return MaterialPageRoute(builder: (_) => const NotificationScreen());

      case driverHome:
        return MaterialPageRoute(builder: (_) => const DriverHomeScreen());

      case driverDashboard:
        return MaterialPageRoute(builder: (_) => const DriverDashboard());

      case driverActiveOrder:
        return MaterialPageRoute(builder: (_) => const DriverActiveOrder());

      case chatList:
        return MaterialPageRoute(builder: (_) => const ChatListScreen());

      case chatScreen:
        final args = settings.arguments as ChatScreenArgs;
        return MaterialPageRoute(
          builder: (_) => ChatScreen(
            chatId: args.chatId,
            title: args.title,
          ),
        );

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
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/order_provider.dart';
import 'providers/payment_provider.dart';
import 'routes/app_routes.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const TruckCabApp());
}

class TruckCabApp extends StatelessWidget {
  const TruckCabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppAuthProvider>(create: (_) => AppAuthProvider()),
        ChangeNotifierProvider<OrderProvider>(create: (_) => OrderProvider()),
        ChangeNotifierProvider<NotificationProvider>(create: (_) => NotificationProvider()),
        ChangeNotifierProvider<ChatProvider>(create: (_) => ChatProvider()),
        ChangeNotifierProvider<PaymentProvider>(create: (_) => PaymentProvider()),
      ],
      child: const _AppLifecycleGate(),
    );
  }
}

class _AppLifecycleGate extends StatefulWidget {
  const _AppLifecycleGate();
  @override State<_AppLifecycleGate> createState() => _AppLifecycleGateState();
}

class _AppLifecycleGateState extends State<_AppLifecycleGate> with WidgetsBindingObserver {
  ThemeMode _themeMode = ThemeMode.dark;
  final GlobalKey<NavigatorState> _navKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    context.read<AppAuthProvider>().handleAppLifecycleState(state);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _toggleTheme() {
    setState(() => _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
  }

  // ── Dark theme ─────────────────────────────────────────────────────────────
  static final _dark = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF1E1E1E),
    fontFamily: 'Roboto',
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF89F336),
      secondary: Color(0xFF89F336),
      surface: Color(0xFF2C2C2C),
      error: Colors.redAccent,
    ),
    splashColor: const Color(0x1A89F336),
    highlightColor: const Color(0x0D89F336),
    hoverColor: const Color(0x1A89F336),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: Color(0xFFF5F7FA),
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(color: Color(0xFFF5F7FA), fontSize: 24, fontWeight: FontWeight.w500),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: const Color(0xFF2C2C2C),
      indicatorColor: const Color(0x2289F336),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: Color(0xFF89F336));
        }
        return const IconThemeData(color: Color(0xFF98A1AE));
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const TextStyle(color: Color(0xFF89F336), fontWeight: FontWeight.w700, fontSize: 12);
        }
        return const TextStyle(color: Color(0xFF98A1AE), fontSize: 12);
      }),
    ),
  );

  // ── Light theme ────────────────────────────────────────────────────────────
  static final _light = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: const Color(0xFFF2F3F8),
    fontFamily: 'Roboto',
    colorScheme: const ColorScheme.light(
      primary: Color(0xFF89F336),
      secondary: Color(0xFF89F336),
      surface: Color(0xFFFFFFFF),
      error: Colors.redAccent,
    ),
    splashColor: const Color(0x1A89F336),
    highlightColor: const Color(0x0D89F336),
    hoverColor: const Color(0x1A89F336),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: Color(0xFF4A4A4A),
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(color: Color(0xFF4A4A4A), fontSize: 24, fontWeight: FontWeight.w500),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: const Color(0xFFFFFFFF),
      indicatorColor: const Color(0x2289F336),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: Color(0xFF89F336));
        }
        return const IconThemeData(color: Color(0xFF8A8FA8));
      }),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: _navKey,
      title: 'TruckCab',
      theme: _light,
      darkTheme: _dark,
      themeMode: _themeMode,
      initialRoute: AppRoutes.splash,
      onGenerateRoute: AppRoutes.generateRoute,
      // Pass toggle down via a simple inherited approach
      builder: (ctx, child) => _ThemeToggleProvider(
        themeMode: _themeMode,
        onToggle: _toggleTheme,
        child: _NotificationToastWrapper(navKey: _navKey, child: child!),
      ),
    );
  }
}

// ── Simple InheritedWidget to expose theme toggle ─────────────────────────────
class _ThemeToggleProvider extends InheritedWidget {
  final ThemeMode themeMode;
  final VoidCallback onToggle;
  const _ThemeToggleProvider({required this.themeMode, required this.onToggle, required super.child});

  static _ThemeToggleProvider? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_ThemeToggleProvider>();

  @override
  bool updateShouldNotify(_ThemeToggleProvider old) =>
      themeMode != old.themeMode;
}

// ── Extension for easy access ─────────────────────────────────────────────────
extension ThemeToggle on BuildContext {
  void toggleTheme() => _ThemeToggleProvider.of(this)?.onToggle();
  ThemeMode get currentThemeMode => _ThemeToggleProvider.of(this)?.themeMode ?? ThemeMode.dark;
}

// ── In-app notification toast overlay ────────────────────────────────────────
class _NotificationToastWrapper extends StatelessWidget {
  final Widget child;
  final GlobalKey<NavigatorState> navKey;
  const _NotificationToastWrapper({required this.child, required this.navKey});

  IconData _iconFor(String type) {
    switch (type) {
      case 'package_delivered':
      case 'delivery_approved': return Icons.check_circle_rounded;
      case 'chat_request':
      case 'chat_accepted':    return Icons.mark_chat_unread_outlined;
      case 'chat_message':     return Icons.chat_bubble_rounded;
      case 'package_picked_up': return Icons.inventory_2_rounded;
      case 'driver_on_the_way': return Icons.local_shipping_rounded;
      default:                 return Icons.notifications_rounded;
    }
  }

  Color _colorFor(String type) {
    switch (type) {
      case 'package_delivered':
      case 'delivery_approved': return const Color(0xFF89F336);
      case 'chat_message':
      case 'chat_accepted':
      case 'chat_request':     return const Color(0xFF89F336);
      default:                 return const Color(0xFF89F336);
    }
  }

  void _navigate(dynamic notification) {
    final nav = navKey.currentState;
    if (nav == null) return;
    final type   = (notification.type ?? '') as String;
    final chatId = (notification.chatId ?? '') as String;
    final title  = (notification.title ?? '') as String;

    if (type == 'chat_message' || type == 'chat_accepted') {
      if (chatId.isNotEmpty) {
        nav.pushNamed(AppRoutes.chatScreen,
            arguments: ChatScreenArgs(chatId: chatId, title: title));
      } else {
        nav.pushNamed(AppRoutes.chatList);
      }
    } else if (type == 'chat_request') {
      nav.pushNamed(AppRoutes.chatRequests);
    } else {
      nav.pushNamed(AppRoutes.notifications);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationProvider>(
      builder: (ctx, notifProvider, _) {
        final toast = notifProvider.toastNotification;
        return Stack(children: [
          child,
          if (toast != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 12,
              left: 16,
              right: 16,
              child: _ToastCard(
                notification: toast,
                color: _colorFor(toast.type),
                icon: _iconFor(toast.type),
                onTap: () {
                  notifProvider.dismissToast();
                  _navigate(toast);
                },
              ),
            ),
        ]);
      },
    );
  }
}

class _ToastCard extends StatefulWidget {
  final dynamic notification;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;
  const _ToastCard({required this.notification, required this.color, required this.icon, required this.onTap});

  @override
  State<_ToastCard> createState() => _ToastCardState();
}

class _ToastCardState extends State<_ToastCard> with SingleTickerProviderStateMixin {
  late final AnimationController _ac;
  late final Animation<Offset>   _slide;
  late final Animation<double>   _fade;

  @override
  void initState() {
    super.initState();
    _ac    = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
    _slide = Tween<Offset>(begin: const Offset(0, -1.2), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ac, curve: Curves.easeOutBack));
    _fade  = CurvedAnimation(parent: _ac, curve: Curves.easeIn);
    _ac.forward();
  }

  @override
  void dispose() { _ac.dispose(); super.dispose(); }

  Future<void> _handleTap() async {
    await _ac.reverse();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final c = widget.color;
    return SlideTransition(
      position: _slide,
      child: FadeTransition(
        opacity: _fade,
        child: Material(
          color: Colors.transparent,
          child: GestureDetector(
            onTap: _handleTap,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: dark ? const Color(0xFF2C2C2C) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: c.withOpacity(0.4), width: 1.5),
                boxShadow: [
                  BoxShadow(color: c.withOpacity(0.25), blurRadius: 20, offset: const Offset(0, 6)),
                  BoxShadow(color: Colors.black.withOpacity(dark ? 0.4 : 0.1), blurRadius: 12, offset: const Offset(0, 4)),
                ],
              ),
              child: Row(children: [
                Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(color: c.withOpacity(0.15), shape: BoxShape.circle),
                  child: Icon(widget.icon, color: c, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    widget.notification.title ?? 'Notification',
                    style: TextStyle(
                      color: dark ? const Color(0xFFF5F7FA) : const Color(0xFF4A4A4A),
                      fontWeight: FontWeight.w700, fontSize: 14),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Text(
                    widget.notification.message ?? '',
                    style: TextStyle(color: dark ? const Color(0xFF98A1AE) : const Color(0xFF6B7280), fontSize: 12),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                ])),
                const SizedBox(width: 8),
                Icon(Icons.close_rounded, color: dark ? const Color(0xFF98A1AE) : const Color(0xFF9CA3AF), size: 18),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
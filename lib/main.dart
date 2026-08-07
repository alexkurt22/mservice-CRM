import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart'; 
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'package:firebase_messaging/firebase_messaging.dart';

import 'firebase_options.dart';
import 'screens/dashboard_screen.dart'; 
import 'screens/login_screen.dart'; 
import 'screens/settings_screen.dart'; 

import 'screens/orders_screen.dart';
import 'screens/chat_lists_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final prefs = await SharedPreferences.getInstance();
  final savedPhone = prefs.getString('employee_phone');
  final bool isDarkSaved = prefs.getBool('is_dark_mode') ?? false;

  Widget startScreen = const LoginScreen();

  if (savedPhone != null && savedPhone.isNotEmpty) {
    try {
      final doc = await FirebaseFirestore.instance.collection('employees').doc(savedPhone).get();
      if (doc.exists && doc.data()?['is_approved'] == true) {
        startScreen = const DashboardScreen();
      }
    } catch (e) {
      debugPrint('Ошибка при проверке сотрудника: $e');
    }
  }

  runApp(MyApp(startScreen: startScreen, initialDarkMode: isDarkSaved));
}

class MyApp extends StatefulWidget {
  final Widget startScreen;
  final bool initialDarkMode;

  const MyApp({super.key, required this.startScreen, required this.initialDarkMode});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late bool _isDarkMode;

  @override
  void initState() {
    super.initState();
    _isDarkMode = widget.initialDarkMode;
    _setupPushRouting(); 
  }

  Future<void> _setupPushRouting() async {
    // 🛑 СПАСЕНИЕ ОТ ПАДЕНИЯ: Если мы на Windows, пропускаем прослушивание Push-уведомлений!
    if (!kIsWeb && Platform.isWindows) {
      return; 
    }

    RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _handlePushMessage(initialMessage);
    }

    FirebaseMessaging.onMessageOpenedApp.listen(_handlePushMessage);
  }

  void _handlePushMessage(RemoteMessage message) {
    final type = message.data['type'];
    
    if (type == 'chat') {
      navigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => const TeamChatsListScreen()));
    } else if (type == 'negotiation') {
      navigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => const OrdersScreen(status: 'awaiting_approval', title: 'Ожидают ответа')));
    } else if (type == 'new_order') {
      navigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => const OrdersScreen(status: 'new', title: 'Новые заказы')));
    }
  }

  Future<void> _toggleTheme(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_dark_mode', value);
    setState(() {
      _isDarkMode = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false, 
      title: 'M-Service CRM',
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.blueGrey,
        scaffoldBackgroundColor: Colors.grey[50],
        cardColor: Colors.white,
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blueGrey,
        scaffoldBackgroundColor: Colors.grey[950],
        cardColor: Colors.grey[900],
        useMaterial3: true,
      ),
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: widget.startScreen,
    );
  }
}

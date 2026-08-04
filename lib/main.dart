import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart'; 
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'package:firebase_messaging/firebase_messaging.dart'; // <--- Добавили для Push

import 'firebase_options.dart';
import 'screens/dashboard_screen.dart'; 
import 'screens/login_screen.dart'; 
import 'screens/settings_screen.dart'; // Р’Р°Р¶РЅРѕ Р·Р° РїСЂРµРЅРѕСЃРѕС‚ РЅР° С‚РµРјР°С‚Р°

// Экспорты для маршрутизации
import 'screens/orders_screen.dart';
import 'screens/chat_lists_screen.dart';

// ГЛОБАЛЬНЫЙ КЛЮЧ: Позволяет переключать экраны без контекста при клике на Push
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
      debugPrint('Р“СЂРµС€РєР° РїСЂРё РїСЂРѕРІРµСЂРєР° РЅР° СЃРµСЃРёСР°С‚Р° РЅР° РІСЂР°Р±РѕС‚РµРЅРёРѕС‚: $e');
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
    _setupPushRouting(); // <--- ЗАПУСКАЕМ СЛУХАЧ ПУШЕЙ
  }

  // --- ЛОГИКА МАРШРУТИЗАЦИИ (DEEP LINKS) ПРИ КЛИКЕ НА PUSH ---
  Future<void> _setupPushRouting() async {
    // 1. Приложение было полностью закрыто, и открылось по клику на Пуш
    RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _handlePushMessage(initialMessage);
    }

    // 2. Приложение было свернуто (в фоне), и открылось по клику на Пуш
    FirebaseMessaging.onMessageOpenedApp.listen(_handlePushMessage);
  }

  void _handlePushMessage(RemoteMessage message) {
    final type = message.data['type'];
    
    // Перекидываем пользователя на нужный экран в зависимости от типа Пуша
    if (type == 'chat') {
      navigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => const TeamChatsListScreen()));
    } else if (type == 'negotiation') {
      navigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => const OrdersScreen(status: 'awaiting_approval', title: 'Ожидают ответа')));
    } else if (type == 'new_order') {
      navigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => const OrdersScreen(status: 'new', title: 'Новые заказы')));
    }
  }

  // Р¤СѓРЅРєС†РёСР° Р·Р° РїСЂРѕРјРµРЅР° Рё Р·Р°С‡СѓРІСѓРІР°СљРµ РЅР° С‚РµРјР°С‚Р°
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
      navigatorKey: navigatorKey, // <--- ПРИВЯЗАЛИ КЛЮЧ
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

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Добавлен локальный хранитель сессии
import 'package:cloud_firestore/cloud_firestore.dart'; // Добавлен для проверки статуса в базе
import 'firebase_options.dart';
import 'screens/dashboard_screen.dart'; // Указываем прямой путь на наш новый Дашборд
import 'screens/login_screen.dart'; // Импортируем будущий экран входа

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Проверяем перед запуском: есть ли сохраненный номер сотрудника в телефоне
  final prefs = await SharedPreferences.getInstance();
  final savedPhone = prefs.getString('employee_phone');

  Widget startScreen = const LoginScreen();

  // Если номер есть, на всякий случай проверяем в Firestore, не заблокирован ли он
  if (savedPhone != null && savedPhone.isNotEmpty) {
    try {
      final doc = await FirebaseFirestore.instance.collection('employees').doc(savedPhone).get();
      if (doc.exists && doc.data()?['is_approved'] == true) {
        startScreen = const DashboardScreen();
      }
    } catch (e) {
      debugPrint('Ошибка проверки сессии сотрудника: $e');
    }
  }

  runApp(MyApp(startScreen: startScreen));
}

class MyApp extends StatelessWidget {
  final Widget startScreen;
  const MyApp({super.key, required this.startScreen});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, // Убираем красную ленточку "DEBUG" в углу
      title: 'M-Service CRM',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey), // Корпоративный цвет
        useMaterial3: true,
      ),
      home: startScreen, // Загружаем стартовый экран в зависимости от авторизации
    );
  }
}

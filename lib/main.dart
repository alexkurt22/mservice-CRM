import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart'; 
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'firebase_options.dart';
import 'screens/dashboard_screen.dart'; 
import 'screens/login_screen.dart'; 
import 'screens/settings_screen.dart'; // Важно за преносот на темата

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
      debugPrint('Грешка при проверка на сесијата на вработениот: $e');
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
  }

  // Функција за промена и зачувување на темата
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

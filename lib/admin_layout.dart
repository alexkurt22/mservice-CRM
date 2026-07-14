import 'package:flutter/material.dart';
import 'screens/dashboard_screen.dart';
import 'screens/requests_screen.dart';

class AdminLayout extends StatefulWidget {
  const AdminLayout({super.key});

  @override
  State<AdminLayout> createState() => _AdminLayoutState();
}

class _AdminLayoutState extends State<AdminLayout> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const DashboardScreen(),
    const RequestsScreen(),
    const Center(child: Text('Все заказы (в разработке)')),
    const Center(child: Text('Настройки темы (в разработке)')),
  ];

  void _onItemTapped(int index) {
    if (index == 4) {
      Navigator.pop(context); // Закрываем шторку
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выход из аккаунта (в разработке)')),
      );
      return;
    }
    setState(() {
      _currentIndex = index;
    });
    Navigator.pop(context); // Закрываем шторку
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("M-Service CRM"),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.teal),
              child: Text(
                'Меню',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard),
              title: const Text('Дашборд'),
              onTap: () => _onItemTapped(0),
            ),
            ListTile(
              leading: const Icon(Icons.person_add),
              title: const Text('Новые заявки'),
              onTap: () => _onItemTapped(1),
            ),
            ListTile(
              leading: const Icon(Icons.list),
              title: const Text('Все заказы'),
              onTap: () => _onItemTapped(2),
            ),
            ListTile(
              leading: const Icon(Icons.palette),
              title: const Text('Настройки темы'),
              onTap: () => _onItemTapped(3),
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Выход'),
              onTap: () => _onItemTapped(4),
            ),
          ],
        ),
      ),
      body: _screens[_currentIndex],
    );
  }
}

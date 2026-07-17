import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'categories_management_screen.dart'; 
import 'login_screen.dart'; // Для выхода из аккаунта
import 'employees_management_screen.dart'; // Экран модерации (создадим в следующем шаге)

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blueGrey[900],
        foregroundColor: Colors.white,
        title: const Text('Настройки'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // --- НОВАЯ СЕКЦИЯ ДЛЯ МОДЕРАЦИИ СОТРУДНИКОВ ---
          _buildSectionHeader('Команда'),
          ListTile(
            leading: const Icon(Icons.people_alt, color: Colors.blueGrey),
            title: const Text('Сотрудники и доступы'),
            subtitle: const Text('Модерация заявок и роли'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const EmployeesManagementScreen()));
            },
          ),
          const Divider(),
          // ---------------------------------------------

          _buildSectionHeader('Контент и База'),
          ListTile(
            leading: const Icon(Icons.category, color: Colors.blueGrey),
            title: const Text('Категории устройств'),
            subtitle: const Text('Управление выпадающим списком'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const CategoriesManagementScreen()));
            },
          ),
          const Divider(),
          
          _buildSectionHeader('Основные'),
          SwitchListTile(
            title: const Text('Темная тема'),
            subtitle: const Text('В разработке'),
            value: false,
            onChanged: (bool value) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Функция будет доступна в обновлениях')),
              );
            },
          ),
          const Divider(),
          
          _buildSectionHeader('Аккаунт'),
          ListTile(
            leading: const Icon(Icons.admin_panel_settings),
            title: const Text('Данные администратора'),
            onTap: () {
              // Можно добавить переход на экран редактирования профиля
            },
          ),
          const Divider(),
          
          _buildSectionHeader('Система'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('О приложении'),
            subtitle: const Text('Версия 1.0.0'),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'M-Service CRM',
                applicationVersion: '1.0.0',
              );
            },
          ),
          // --- РАБОЧАЯ КНОПКА ВЫХОДА ---
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Выйти', style: TextStyle(color: Colors.red)),
            onTap: () async {
              // Очищаем сессию в телефоне
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('employee_phone');
              
              if (context.mounted) {
                // Полностью очищаем историю навигации и кидаем на экран логина
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.blueGrey[600],
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }
}

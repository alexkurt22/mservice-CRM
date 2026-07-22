import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'categories_management_screen.dart'; 
import 'login_screen.dart'; // Для выхода из аккаунта
import 'employees_management_screen.dart'; // Экран модерации

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Контроллеры для системы лояльности
  final TextEditingController _welcomeController = TextEditingController();
  final TextEditingController _referralController = TextEditingController();
  final TextEditingController _discountController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _welcomeController.dispose();
    _referralController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  // Загрузка настроек из Firebase
  Future<void> _loadSettings() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('settings').doc('loyalty').get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        _welcomeController.text = (data['welcome_points'] ?? 10).toString();
        _referralController.text = (data['referral_points'] ?? 15).toString();
        _discountController.text = (data['max_discount_percent'] ?? 30).toString();
      } else {
        // Значения по умолчанию, если документа еще нет
        _welcomeController.text = '10';
        _referralController.text = '15';
        _discountController.text = '30';
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка загрузки: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Сохранение настроек в Firebase
  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    
    int welcome = int.tryParse(_welcomeController.text.trim()) ?? 10;
    int referral = int.tryParse(_referralController.text.trim()) ?? 15;
    int discount = int.tryParse(_discountController.text.trim()) ?? 30;

    // Защита от дурака (скидка не может быть больше 100% или меньше 0)
    if (discount > 100) discount = 100;
    if (discount < 0) discount = 0;

    try {
      await FirebaseFirestore.instance.collection('settings').doc('loyalty').set({
        'welcome_points': welcome,
        'referral_points': referral,
        'max_discount_percent': discount,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Настройки успешно сохранены!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка сохранения: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
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
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blueGrey[900],
        foregroundColor: Colors.white,
        title: const Text('Настройки', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                // --- СЕКЦИЯ: КОМАНДА ---
                _buildSectionHeader('КОМАНДА'),
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

                // --- СЕКЦИЯ: КОНТЕНТ И БАЗА ---
                _buildSectionHeader('КОНТЕНТ И БАЗА'),
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

                // --- СЕКЦИЯ: СИСТЕМА ЛОЯЛЬНОСТИ (НОВОЕ) ---
                _buildSectionHeader('СИСТЕМА ЛОЯЛЬНОСТИ'),
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Управление баллами', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 8),
                        const Text('Изменения мгновенно применяются во всех клиентских приложениях.', style: TextStyle(color: Colors.grey, fontSize: 13)),
                        const Divider(height: 24),
                        
                        TextField(
                          controller: _welcomeController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Бонус за регистрацию (баллов)',
                            prefixIcon: Icon(Icons.card_giftcard, color: Colors.green),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        TextField(
                          controller: _referralController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Бонус за друга (баллов каждому)',
                            prefixIcon: Icon(Icons.people, color: Colors.orange),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        TextField(
                          controller: _discountController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Макс. оплата баллами от чека (%)',
                            prefixIcon: Icon(Icons.percent, color: Colors.blue),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueGrey[900],
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: _isSaving ? null : _saveSettings,
                            icon: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.save, color: Colors.white),
                            label: Text(_isSaving ? 'Сохранение...' : 'СОХРАНИТЬ НАСТРОЙКИ', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(),

                // --- СЕКЦИЯ: ОСНОВНЫЕ ---
                _buildSectionHeader('ОСНОВНЫЕ'),
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
                
                // --- СЕКЦИЯ: АККАУНТ ---
                _buildSectionHeader('АККАУНТ'),
                ListTile(
                  leading: const Icon(Icons.admin_panel_settings),
                  title: const Text('Данные администратора'),
                  onTap: () {},
                ),
                const Divider(),
                
                // --- СЕКЦИЯ: СИСТЕМА И ВЫХОД ---
                _buildSectionHeader('СИСТЕМА'),
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
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text('Выйти', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  onTap: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.remove('employee_phone');
                    
                    if (context.mounted) {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                        (route) => false,
                      );
                    }
                  },
                ),
                const SizedBox(height: 32),
              ],
            ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'categories_management_screen.dart'; 
import 'login_screen.dart'; 
import 'employees_management_screen.dart'; 
import 'bonus_distribution_screen.dart';
import 'reviews_management_screen.dart'; // <--- ИМПОРТ ЭКРАНА МОДЕРАЦИИ ОТЗЫВОВ

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
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

  Future<void> _loadSettings() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('settings').doc('loyalty').get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        _welcomeController.text = (data['welcome_points'] ?? 10).toString();
        _referralController.text = (data['referral_points'] ?? 15).toString();
        _discountController.text = (data['max_discount_percent'] ?? 30).toString();
      } else {
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

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    
    int welcome = int.tryParse(_welcomeController.text.trim()) ?? 10;
    int referral = int.tryParse(_referralController.text.trim()) ?? 15;
    int discount = int.tryParse(_discountController.text.trim()) ?? 30;

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
      child: Text(title, style: TextStyle(color: Colors.blueGrey[600], fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1.2)),
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

                // --- КНОПКА МОДЕРАЦИИ ОТЗЫВОВ ---
                ListTile(
                  leading: const Icon(Icons.forum, color: Colors.blueGrey),
                  title: const Text('Модерация отзывов'),
                  subtitle: const Text('Проверка и публикация оценок клиентов'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const ReviewsManagementScreen()));
                  },
                ),
                const Divider(),

                _buildSectionHeader('СИСТЕМА ЛОЯЛЬНОСТИ'),
                
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  color: Colors.orange[50],
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(12),
                    leading: CircleAvatar(backgroundColor: Colors.orange[200], child: const Icon(Icons.card_giftcard, color: Colors.deepOrange)),
                    title: const Text('Рассылка баллов клиентам', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    subtitle: const Text('Индивидуально или массово'),
                    trailing: const Icon(Icons.arrow_forward_ios, color: Colors.orange),
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const BonusDistributionScreen()));
                    },
                  ),
                ),
                const SizedBox(height: 12),
                
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Автоматические правила', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _welcomeController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Бонус за регистрацию', prefixIcon: Icon(Icons.person_add, color: Colors.green), border: OutlineInputBorder()),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _referralController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Бонус за друга', prefixIcon: Icon(Icons.people, color: Colors.orange), border: OutlineInputBorder()),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _discountController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Макс. % оплаты баллами', prefixIcon: Icon(Icons.percent, color: Colors.blue), border: OutlineInputBorder()),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey[900], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                            onPressed: _isSaving ? null : _saveSettings,
                            icon: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.save, color: Colors.white),
                            label: Text(_isSaving ? 'Сохранение...' : 'СОХРАНИТЬ ПРАВИЛА', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(),

                _buildSectionHeader('ОСНОВНЫЕ'),
                SwitchListTile(
                  title: const Text('Темная тема'),
                  subtitle: const Text('В разработке'),
                  value: false,
                  onChanged: (bool value) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Функция будет доступна в обновлениях')));
                  },
                ),
                const Divider(),
                
                _buildSectionHeader('АККАУНТ'),
                ListTile(leading: const Icon(Icons.admin_panel_settings), title: const Text('Данные администратора'), onTap: () {}),
                const Divider(),
                
                _buildSectionHeader('СИСТЕМА'),
                ListTile(leading: const Icon(Icons.info_outline), title: const Text('О приложении'), subtitle: const Text('Версия 1.0.0'), onTap: () {}),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text('Выйти', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  onTap: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.remove('employee_phone');
                    if (context.mounted) {
                      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
                    }
                  },
                ),
                const SizedBox(height: 32),
              ],
            ),
    );
  }
}

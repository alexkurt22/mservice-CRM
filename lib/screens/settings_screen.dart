import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'categories_management_screen.dart'; 
import 'login_screen.dart'; 
import 'employees_management_screen.dart'; 
import 'bonus_distribution_screen.dart';
import 'reviews_management_screen.dart'; 

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _welcomeController = TextEditingController();
  final TextEditingController _discountController = TextEditingController();

  // Состояние галочек для пушей
  bool _pushOnNegotiation = true;
  bool _pushOnBonus = true;
  bool _pushOnChat = true;

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
    _discountController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      // 1. Загрузка правил лояльности
      final loyaltyDoc = await FirebaseFirestore.instance.collection('settings').doc('loyalty').get();
      if (loyaltyDoc.exists && loyaltyDoc.data() != null) {
        final data = loyaltyDoc.data()!;
        _welcomeController.text = (data['welcome_points'] ?? 10).toString();
        _discountController.text = (data['max_discount_percent'] ?? 30).toString();
      } else {
        _welcomeController.text = '10';
        _discountController.text = '30';
      }

      // 2. Загрузка правил пуш-уведомлений
      final pushDoc = await FirebaseFirestore.instance.collection('settings').doc('notifications').get();
      if (pushDoc.exists && pushDoc.data() != null) {
        final data = pushDoc.data()!;
        setState(() {
          _pushOnNegotiation = data['push_on_negotiation'] ?? true;
          _pushOnBonus = data['push_on_bonus'] ?? true;
          _pushOnChat = data['push_on_chat'] ?? true;
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка загрузки: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveAllSettings() async {
    setState(() => _isSaving = true);
    
    int welcome = int.tryParse(_welcomeController.text.trim()) ?? 10;
    int discount = int.tryParse(_discountController.text.trim()) ?? 30;

    if (discount > 100) discount = 100;
    if (discount < 0) discount = 0;

    try {
      final db = FirebaseFirestore.instance;
      WriteBatch batch = db.batch();

      // Запись лояльности
      batch.set(db.collection('settings').doc('loyalty'), {
        'welcome_points': welcome,
        'max_discount_percent': discount,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Запись настроек пушей (наш глобальный рубильник)
      batch.set(db.collection('settings').doc('notifications'), {
        'push_on_negotiation': _pushOnNegotiation,
        'push_on_bonus': _pushOnBonus,
        'push_on_chat': _pushOnChat,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Все настройки успешно сохранены!'), backgroundColor: Colors.green));
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

                // --- ЦЕНТР УПРАВЛЕНИЯ УВЕДОМЛЕНИЯМИ ---
                _buildSectionHeader('УПРАВЛЕНИЕ УВЕДОМЛЕНИЯМИ'),
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Column(
                      children: [
                        SwitchListTile(
                          title: const Text('Согласование ремонта', style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: const Text('Отправка цен и вариантов клиенту'),
                          activeColor: Colors.orange,
                          value: _pushOnNegotiation,
                          onChanged: (val) => setState(() => _pushOnNegotiation = val),
                        ),
                        const Divider(horizontalMargin: 16),
                        SwitchListTile(
                          title: const Text('Начисление баллов', style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: const Text('Уведомление при раздаче подарков'),
                          activeColor: Colors.orange,
                          value: _pushOnBonus,
                          onChanged: (val) => setState(() => _pushOnBonus = val),
                        ),
                        const Divider(horizontalMargin: 16),
                        SwitchListTile(
                          title: const Text('Чат поддержки', style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: const Text('Новые сообщения от администратора'),
                          activeColor: Colors.orange,
                          value: _pushOnChat,
                          onChanged: (val) => setState(() => _pushOnChat = val),
                        ),
                      ],
                    ),
                  ),
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
                          controller: _discountController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Макс. % оплаты баллами', prefixIcon: Icon(Icons.percent, color: Colors.blue), border: OutlineInputBorder()),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Глобальная кнопка сохранения
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey[900], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    onPressed: _isSaving ? null : _saveAllSettings,
                    icon: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.save, color: Colors.white),
                    label: Text(_isSaving ? 'Сохранение...' : 'СОХРАНИТЬ ВСЕ НАСТРОЙКИ', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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

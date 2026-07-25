import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'categories_management_screen.dart'; 
import 'catalog_editor_screen.dart'; 
import 'login_screen.dart'; 
import 'employees_management_screen.dart'; 
import 'bonus_distribution_screen.dart';
import 'reviews_management_screen.dart'; 

class SettingsScreen extends StatefulWidget {
  final Function(bool) onThemeChanged; // Передача колбэка для смены темы
  final bool isDarkMode;

  const SettingsScreen({
    super.key, 
    required this.onThemeChanged,
    required this.isDarkMode,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _welcomeController = TextEditingController();
  final TextEditingController _discountController = TextEditingController();

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
      final loyaltyDoc = await FirebaseFirestore.instance.collection('settings').doc('loyalty').get();
      if (loyaltyDoc.exists && loyaltyDoc.data() != null) {
        final data = loyaltyDoc.data()!;
        _welcomeController.text = (data['welcome_points'] ?? 10).toString();
        _discountController.text = (data['max_discount_percent'] ?? 30).toString();
      } else {
        _welcomeController.text = '10';
        _discountController.text = '30';
      }

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

      batch.set(db.collection('settings').doc('loyalty'), {
        'welcome_points': welcome,
        'max_discount_percent': discount,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

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

  Future<void> _showLogoutDialog() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text('Выход из аккаунта', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
        content: Text('Вы уверены, что хотите выйти из CRM? Вам потребуется заново ввести номер телефона.', style: TextStyle(color: isDark ? Colors.white70 : Colors.blueGrey[700])),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700]),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Выйти', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('employee_phone');
      if (mounted) {
        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
      }
    }
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
      child: Text(title, style: TextStyle(color: isDark ? Colors.grey[500] : Colors.blueGrey[600], fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1.2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: isDark ? Colors.grey[900] : Colors.blueGrey[900],
        foregroundColor: Colors.white,
        title: const Text('Настройки', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                _buildSectionHeader('ИНТЕРФЕЙС', isDark),
                Card(
                  color: Theme.of(context).cardColor,
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: isDark ? Colors.grey[800]! : Colors.transparent)
                  ),
                  child: SwitchListTile(
                    secondary: Icon(widget.isDarkMode ? Icons.dark_mode : Icons.light_mode, color: widget.isDarkMode ? Colors.amber : Colors.blue),
                    title: Text('Тёмная тема', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                    subtitle: Text('Комфортная работа в темное время', style: TextStyle(color: isDark ? Colors.white54 : Colors.grey[600])),
                    activeColor: Colors.orange,
                    value: widget.isDarkMode,
                    onChanged: (val) {
                      widget.onThemeChanged(val); // Вызываем сохранение и смену темы
                    },
                  ),
                ),
                Divider(color: isDark ? Colors.grey[800] : Colors.grey[300]),

                _buildSectionHeader('КОМАНДА', isDark),
                ListTile(
                  leading: Icon(Icons.people_alt, color: isDark ? Colors.white54 : Colors.blueGrey),
                  title: Text('Сотрудники и доступы', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                  subtitle: Text('Модерация заявок и роли', style: TextStyle(color: isDark ? Colors.white54 : Colors.grey[600])),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const EmployeesManagementScreen()));
                  },
                ),
                Divider(color: isDark ? Colors.grey[800] : Colors.grey[300]),

                _buildSectionHeader('КОНТЕНТ И БАЗА', isDark),
                ListTile(
                  leading: Icon(Icons.category, color: isDark ? Colors.white54 : Colors.blueGrey),
                  title: Text('Категории устройств', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                  subtitle: Text('Смартфон, Ноутбук и т.д.', style: TextStyle(color: isDark ? Colors.white54 : Colors.grey[600])),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const CategoriesManagementScreen()));
                  },
                ),
                Divider(color: isDark ? Colors.grey[800] : Colors.grey[300]),

                ListTile(
                  leading: Icon(Icons.monetization_on, color: isDark ? Colors.white54 : Colors.blueGrey),
                  title: Text('Прайс-лист услуг', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                  subtitle: Text('Редактирование цен на услуги', style: TextStyle(color: isDark ? Colors.white54 : Colors.grey[600])),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const CatalogEditorScreen()));
                  },
                ),
                Divider(color: isDark ? Colors.grey[800] : Colors.grey[300]),

                ListTile(
                  leading: Icon(Icons.forum, color: isDark ? Colors.white54 : Colors.blueGrey),
                  title: Text('Модерация отзывов', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                  subtitle: Text('Проверка и публикация оценок клиентов', style: TextStyle(color: isDark ? Colors.white54 : Colors.grey[600])),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const ReviewsManagementScreen()));
                  },
                ),
                Divider(color: isDark ? Colors.grey[800] : Colors.grey[300]),

                _buildSectionHeader('УПРАВЛЕНИЕ УВЕДОМЛЕНИЯМИ', isDark),
                Card(
                  color: Theme.of(context).cardColor,
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: isDark ? Colors.grey[800]! : Colors.transparent)
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Column(
                      children: [
                        SwitchListTile(
                          title: Text('Согласование ремонта', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                          subtitle: Text('Отправка цен и вариантов клиенту', style: TextStyle(color: isDark ? Colors.white54 : Colors.grey[600])),
                          activeColor: Colors.orange,
                          value: _pushOnNegotiation,
                          onChanged: (val) => setState(() => _pushOnNegotiation = val),
                        ),
                        Divider(indent: 16, endIndent: 16, color: isDark ? Colors.grey[800] : Colors.grey[300]),
                        SwitchListTile(
                          title: Text('Начисление баллов', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                          subtitle: Text('Уведомление при раздаче подарков', style: TextStyle(color: isDark ? Colors.white54 : Colors.grey[600])),
                          activeColor: Colors.orange,
                          value: _pushOnBonus,
                          onChanged: (val) => setState(() => _pushOnBonus = val),
                        ),
                        Divider(indent: 16, endIndent: 16, color: isDark ? Colors.grey[800] : Colors.grey[300]),
                        SwitchListTile(
                          title: Text('Чат поддержки', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                          subtitle: Text('Новые сообщения от администратора', style: TextStyle(color: isDark ? Colors.white54 : Colors.grey[600])),
                          activeColor: Colors.orange,
                          value: _pushOnChat,
                          onChanged: (val) => setState(() => _pushOnChat = val),
                        ),
                      ],
                    ),
                  ),
                ),
                Divider(color: isDark ? Colors.grey[800] : Colors.grey[300]),

                _buildSectionHeader('СИСТЕМА ЛОЯЛЬНОСТИ', isDark),
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: isDark ? Colors.orange[900]! : Colors.transparent)
                  ),
                  color: isDark ? Colors.orange[900]?.withOpacity(0.2) : Colors.orange[50],
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(12),
                    leading: CircleAvatar(backgroundColor: isDark ? Colors.orange[900] : Colors.orange[200], child: Icon(Icons.card_giftcard, color: isDark ? Colors.white : Colors.deepOrange)),
                    title: Text('Рассылка баллов клиентам', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.orange[300] : Colors.black87)),
                    subtitle: Text('Индивидуально или массово', style: TextStyle(color: isDark ? Colors.white54 : Colors.grey[700])),
                    trailing: Icon(Icons.arrow_forward_ios, color: isDark ? Colors.orange[300] : Colors.orange),
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const BonusDistributionScreen()));
                    },
                  ),
                ),
                const SizedBox(height: 12),
                
                Card(
                  elevation: 1,
                  color: Theme.of(context).cardColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: isDark ? Colors.grey[800]! : Colors.transparent)
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Автоматические правила', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87)),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _welcomeController,
                          keyboardType: TextInputType.number,
                          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                          decoration: InputDecoration(
                            labelText: 'Бонус за регистрацию',
                            labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.grey[700]),
                            prefixIcon: const Icon(Icons.person_add, color: Colors.green), 
                            border: const OutlineInputBorder(),
                            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _discountController,
                          keyboardType: TextInputType.number,
                          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                          decoration: InputDecoration(
                            labelText: 'Макс. % оплаты баллами',
                            labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.grey[700]),
                            prefixIcon: const Icon(Icons.percent, color: Colors.blue), 
                            border: const OutlineInputBorder(),
                            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? Colors.blueGrey[700] : Colors.blueGrey[900], 
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                    ),
                    onPressed: _isSaving ? null : _saveAllSettings,
                    icon: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.save, color: Colors.white),
                    label: Text(_isSaving ? 'Сохранение...' : 'СОХРАНИТЬ ВСЕ НАСТРОЙКИ', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
                Divider(color: isDark ? Colors.grey[800] : Colors.grey[300], height: 32),

                ListTile(
                  leading: Icon(Icons.logout, color: isDark ? Colors.red[300] : Colors.red),
                  title: Text('Выйти из аккаунта', style: TextStyle(color: isDark ? Colors.red[300] : Colors.red, fontWeight: FontWeight.bold)),
                  onTap: _showLogoutDialog,
                ),
                const SizedBox(height: 32),
              ],
            ),
    );
  }
}

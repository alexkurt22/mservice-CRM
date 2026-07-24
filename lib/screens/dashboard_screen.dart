import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';

import 'users_screen.dart';
import 'orders_screen.dart';
import 'database_cleanup_screen.dart'; 
import 'settings_screen.dart';
import 'chat_lists_screen.dart'; 
import 'statistics_screen.dart'; // ВАЖНО: Подключили экран статистики

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _myPhone = 'admin';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _myPhone = prefs.getString('employee_phone') ?? 'admin';
    });
    _setupPushNotifications(); 
  }

  Future<void> _setupPushNotifications() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    await messaging.requestPermission();
    
    // Подписка на общую рацию (для системных уведомлений от клиентов)
    await messaging.subscribeToTopic('admins'); 

    // НОВОЕ: СОХРАНЯЕМ ЛИЧНЫЙ ТОКЕН СОТРУДНИКА ДЛЯ ПЕРЕПИСОК 1-НА-1
    if (_myPhone != 'admin') {
      String? token = await messaging.getToken();
      if (token != null) {
        await FirebaseFirestore.instance.collection('employees').doc(_myPhone).set({
          'fcm_token': token,
        }, SetOptions(merge: true));
      }

      // Обновляем токен, если Google его вдруг поменяет
      messaging.onTokenRefresh.listen((newToken) async {
        await FirebaseFirestore.instance.collection('employees').doc(_myPhone).set({
          'fcm_token': newToken,
        }, SetOptions(merge: true));
      });
    }

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      FlutterRingtonePlayer().playNotification();
      HapticFeedback.heavyImpact();
    });
  }

  Widget _buildDrawer(BuildContext context, bool isDark) {
    return Drawer(
      backgroundColor: Theme.of(context).cardColor,
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(color: isDark ? Colors.grey[900] : Colors.blueGrey[900]),
            accountName: const Text('M-SERVICE CRM', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Colors.white)),
            accountEmail: const Text('Панель Владельца', style: TextStyle(color: Colors.white70, fontSize: 14)),
            currentAccountPicture: CircleAvatar(
              backgroundColor: isDark ? Colors.grey[800] : Colors.white,
              child: Icon(Icons.admin_panel_settings, size: 40, color: isDark ? Colors.white : Colors.blueGrey[900]),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  child: Text('ИНСТРУМЕНТЫ', style: TextStyle(color: isDark ? Colors.grey[500] : Colors.blueGrey[400], fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.2)),
                ),
                ListTile(
                  leading: Icon(Icons.bar_chart, color: isDark ? Colors.white70 : Colors.blueGrey[700]),
                  title: Text('Статистика', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                  onTap: () {
                    Navigator.pop(context); // Закрываем меню
                    // Открываем наш новый экран статистики!
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const StatisticsScreen()));
                  },
                ),
                ListTile(
                  leading: Icon(Icons.send_to_mobile, color: isDark ? Colors.white70 : Colors.blueGrey[700]),
                  title: Text('Создать рассылку', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('В разработке: Маркетинговые Push-рассылки')));
                  },
                ),
                ListTile(
                  leading: Icon(Icons.edit_note, color: isDark ? Colors.white70 : Colors.blueGrey[700]),
                  title: Text('Заметки администратора', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('В разработке: Дневник администратора')));
                  },
                ),
                ListTile(
                  leading: Icon(Icons.settings, color: isDark ? Colors.white70 : Colors.blueGrey[700]),
                  title: Text('Настройки', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
                  },
                ),
              ],
            ),
          ),
          Divider(height: 1, color: isDark ? Colors.grey[800] : Colors.grey[300]),
          SafeArea(
            top: false,
            child: ListTile(
              tileColor: isDark ? Colors.red[900]?.withOpacity(0.2) : Colors.red[50],
              leading: Icon(Icons.delete_sweep, color: isDark ? Colors.red[300] : Colors.red),
              title: Text('Очистка базы данных', style: TextStyle(color: isDark ? Colors.red[300] : Colors.red, fontWeight: FontWeight.bold, fontSize: 15)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const DatabaseCleanupScreen()));
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Color color,
    required Widget child,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Card(
      elevation: 2,
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isDark ? Colors.grey[800]! : Colors.transparent)
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(height: 8),
              child,
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.grey[400] : Colors.blueGrey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStreamStat({
    required Stream<QuerySnapshot> stream,
    required Color color,
    bool Function(DocumentSnapshot)? filter,
  }) {
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2));
        }
        int count = 0;
        if (snapshot.hasData) {
          if (filter != null) {
            count = snapshot.data!.docs.where(filter).length;
          } else {
            count = snapshot.data!.docs.length;
          }
        }
        return Text(count.toString(), style: TextStyle(fontSize: 26, color: color, fontWeight: FontWeight.w900));
      },
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
        title: const Text('Сводка CRM', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      drawer: _buildDrawer(context, isDark), 
      
      floatingActionButton: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('chat_rooms').snapshots(),
        builder: (context, snapshot) {
          int unreadClientChats = 0;
          int unreadTeamChats = 0;

          if (snapshot.hasData) {
            for (var doc in snapshot.data!.docs) {
              final data = doc.data() as Map<String, dynamic>;
              int count = data['unread_count'] as int? ?? 0;
              
              if (count > 0 && data['last_sender'] != _myPhone) {
                if (data['type'] == 'private') unreadClientChats += count;
                if (data['type'] == 'team') unreadTeamChats += count;
              }
            }
          }

          return Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Badge(
                isLabelVisible: unreadClientChats > 0,
                label: Text(unreadClientChats.toString(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                backgroundColor: Colors.red,
                offset: const Offset(-4, -4),
                child: FloatingActionButton.extended(
                  heroTag: 'client_chat_btn',
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ClientChatsListScreen())),
                  backgroundColor: Colors.blue[700],
                  icon: const Icon(Icons.support_agent, color: Colors.white),
                  label: const Text('Чаты с клиентами', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 16),
              Badge(
                isLabelVisible: unreadTeamChats > 0,
                label: Text(unreadTeamChats.toString(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                backgroundColor: Colors.red,
                offset: const Offset(-4, -4),
                child: FloatingActionButton.extended(
                  heroTag: 'team_chat_btn',
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TeamChatsListScreen())),
                  backgroundColor: Colors.orange[600],
                  icon: const Icon(Icons.groups, color: Colors.white),
                  label: const Text('Чат команды', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          );
        },
      ),

      body: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 16.0, right: 16.0, top: 16.0, 
          bottom: MediaQuery.of(context).padding.bottom + 140.0
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.home_repair_service, color: isDark ? Colors.blueGrey[300] : Colors.blueGrey[800]),
                const SizedBox(width: 8),
                Text('Заказы', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.blueGrey[900], letterSpacing: 1.2)),
              ],
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.1,
              children: [
                _buildStatCard(
                  context: context,
                  isDark: isDark,
                  title: 'Новые заказы',
                  icon: Icons.fiber_new,
                  color: Colors.blue,
                  child: _buildStreamStat(
                    stream: FirebaseFirestore.instance.collection('orders').where('status', isEqualTo: 'new').snapshots(),
                    color: isDark ? Colors.blue[300]! : Colors.blue[800]!,
                  ),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OrdersScreen(status: 'new', title: 'Новые заказы'))),
                ),
                _buildStatCard(
                  context: context,
                  isDark: isDark,
                  title: 'Ожидают ответа',
                  icon: Icons.hourglass_empty,
                  color: Colors.deepPurple,
                  child: _buildStreamStat(
                    stream: FirebaseFirestore.instance.collection('orders').where('status', isEqualTo: 'awaiting_approval').snapshots(),
                    color: isDark ? Colors.deepPurple[300]! : Colors.deepPurple[800]!,
                  ),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OrdersScreen(status: 'awaiting_approval', title: 'Ожидают ответа'))),
                ),
                _buildStatCard(
                  context: context,
                  isDark: isDark,
                  title: 'Выполняются',
                  icon: Icons.build_circle,
                  color: Colors.orange,
                  child: _buildStreamStat(
                    stream: FirebaseFirestore.instance.collection('orders').where('status', isEqualTo: 'in_progress').snapshots(),
                    color: isDark ? Colors.orange[300]! : Colors.orange[800]!,
                  ),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OrdersScreen(status: 'in_progress', title: 'В работе (Выполняются)'))),
                ),
                _buildStatCard(
                  context: context,
                  isDark: isDark,
                  title: 'Выполненные',
                  icon: Icons.check_circle,
                  color: Colors.teal,
                  child: _buildStreamStat(
                    stream: FirebaseFirestore.instance.collection('orders').where('status', isEqualTo: 'completed').snapshots(),
                    color: isDark ? Colors.teal[300]! : Colors.teal[800]!,
                  ),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OrdersScreen(status: 'completed', title: 'Выполненные заказы'))),
                ),
              ],
            ),
            
            const SizedBox(height: 32),

            Row(
              children: [
                Icon(Icons.people_alt, color: isDark ? Colors.blueGrey[300] : Colors.blueGrey[800]),
                const SizedBox(width: 8),
                Text('Клиенты', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.blueGrey[900], letterSpacing: 1.2)),
              ],
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.1,
              children: [
                _buildStatCard(
                  context: context,
                  isDark: isDark,
                  title: 'Ждут одобрения',
                  icon: Icons.timer,
                  color: Colors.orange,
                  child: _buildStreamStat(
                    stream: FirebaseFirestore.instance.collection('clients').snapshots(),
                    color: isDark ? Colors.orange[300]! : Colors.orange[800]!,
                    filter: (doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return data['is_approved'] == false && data['rejection_reason'] == null && data['is_offline'] != true;
                    }
                  ),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UsersScreen(tabType: 0, title: 'Ждут одобрения'))),
                ),
                _buildStatCard(
                  context: context,
                  isDark: isDark,
                  title: 'Без приложения',
                  icon: Icons.person_outline, 
                  color: Colors.grey,
                  child: _buildStreamStat(
                    stream: FirebaseFirestore.instance.collection('clients').snapshots(),
                    color: isDark ? Colors.grey[400]! : Colors.grey[800]!,
                    filter: (doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return data['is_offline'] == true;
                    }
                  ),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UsersScreen(tabType: 1, title: 'Без приложения'))),
                ),
                _buildStatCard(
                  context: context,
                  isDark: isDark,
                  title: 'С приложением',
                  icon: Icons.verified_user,
                  color: Colors.green,
                  child: _buildStreamStat(
                    stream: FirebaseFirestore.instance.collection('clients').snapshots(),
                    color: isDark ? Colors.green[300]! : Colors.green[800]!,
                    filter: (doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return data['is_approved'] == true && data['is_offline'] != true; 
                    }
                  ),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UsersScreen(tabType: 2, title: 'С приложением'))),
                ),
                _buildStatCard(
                  context: context,
                  isDark: isDark,
                  title: 'Отклоненные',
                  icon: Icons.block,
                  color: Colors.red,
                  child: _buildStreamStat(
                    stream: FirebaseFirestore.instance.collection('clients').snapshots(),
                    color: isDark ? Colors.red[300]! : Colors.red[800]!,
                    filter: (doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return data['is_approved'] == false && data['rejection_reason'] != null;
                    }
                  ),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UsersScreen(tabType: 3, title: 'Отклоненные'))),
                ),
              ],
            ),
            
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

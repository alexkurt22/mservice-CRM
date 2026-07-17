import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'users_screen.dart';
import 'orders_screen.dart';
import 'database_cleanup_screen.dart'; 
import 'settings_screen.dart';
import 'internal_chat_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(color: Colors.blueGrey[900]),
            accountName: const Text('M-SERVICE CRM', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
            accountEmail: const Text('Панель Владельца', style: TextStyle(color: Colors.white70, fontSize: 14)),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.admin_panel_settings, size: 40, color: Colors.blueGrey[900]),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  child: Text('ИНСТРУМЕНТЫ', style: TextStyle(color: Colors.blueGrey[400], fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.2)),
                ),
                ListTile(
                  leading: Icon(Icons.bar_chart, color: Colors.blueGrey[700]),
                  title: const Text('Статистика', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('В разработке: Подробная статистика')));
                  },
                ),
                ListTile(
                  leading: Icon(Icons.send_to_mobile, color: Colors.blueGrey[700]),
                  title: const Text('Создать рассылку', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('В разработке: Маркетинговые Push-рассылки')));
                  },
                ),
                ListTile(
                  leading: Icon(Icons.edit_note, color: Colors.blueGrey[700]),
                  title: const Text('Заметки администратора', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('В разработке: Дневник администратора')));
                  },
                ),
                ListTile(
                  leading: Icon(Icons.settings, color: Colors.blueGrey[700]),
                  title: const Text('Настройки', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          SafeArea(
            top: false,
            child: ListTile(
              tileColor: Colors.red[50],
              leading: const Icon(Icons.delete_sweep, color: Colors.red),
              title: const Text('Очистка базы данных', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 15)),
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
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey),
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
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.blueGrey[900],
        foregroundColor: Colors.white,
        title: const Text('Сводка CRM', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      drawer: _buildDrawer(context), 
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InternalChatScreen())),
        backgroundColor: Colors.orange[600],
        child: const Icon(Icons.forum, color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 16.0, right: 16.0, top: 16.0, 
          bottom: MediaQuery.of(context).padding.bottom + 80.0
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ================== БЛОК 1: КЛИЕНТЫ ==================
            Row(
              children: [
                Icon(Icons.people_alt, color: Colors.blueGrey[800]),
                const SizedBox(width: 8),
                Text('Клиенты', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.blueGrey[900], letterSpacing: 1.2)),
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
                  title: 'Ждут одобрения',
                  icon: Icons.timer,
                  color: Colors.orange,
                  child: _buildStreamStat(
                    stream: FirebaseFirestore.instance.collection('clients').snapshots(),
                    color: Colors.orange[800]!,
                    filter: (doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return data['is_approved'] == false && data['rejection_reason'] == null && data['is_offline'] != true;
                    }
                  ),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UsersScreen(initialTab: 0))),
                ),
                _buildStatCard(
                  context: context,
                  title: 'Незарегистрированные',
                  icon: Icons.person_off,
                  color: Colors.grey,
                  child: _buildStreamStat(
                    stream: FirebaseFirestore.instance.collection('clients').snapshots(),
                    color: Colors.grey[800]!,
                    filter: (doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return data['is_offline'] == true;
                    }
                  ),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UsersScreen(initialTab: 1))),
                ),
                _buildStatCard(
                  context: context,
                  title: 'Зарегистрированные',
                  icon: Icons.verified_user,
                  color: Colors.green,
                  child: _buildStreamStat(
                    stream: FirebaseFirestore.instance.collection('clients').snapshots(),
                    color: Colors.green[800]!,
                    filter: (doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return data['is_approved'] == true;
                    }
                  ),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UsersScreen(initialTab: 2))),
                ),
                _buildStatCard(
                  context: context,
                  title: 'Отклоненные',
                  icon: Icons.block,
                  color: Colors.red,
                  child: _buildStreamStat(
                    stream: FirebaseFirestore.instance.collection('clients').snapshots(),
                    color: Colors.red[800]!,
                    filter: (doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return data['is_approved'] == false && data['rejection_reason'] != null;
                    }
                  ),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UsersScreen(initialTab: 3))),
                ),
              ],
            ),
            
            const SizedBox(height: 32),

            // ================== БЛОК 2: ЗАКАЗЫ ==================
            Row(
              children: [
                Icon(Icons.home_repair_service, color: Colors.blueGrey[800]),
                const SizedBox(width: 8),
                Text('Заказы', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.blueGrey[900], letterSpacing: 1.2)),
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
                  title: 'Новые заказы',
                  icon: Icons.fiber_new,
                  color: Colors.blue,
                  child: _buildStreamStat(
                    stream: FirebaseFirestore.instance.collection('orders').where('status', isEqualTo: 'new').snapshots(),
                    color: Colors.blue[800]!,
                  ),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OrdersScreen(initialTab: 0))),
                ),
                _buildStatCard(
                  context: context,
                  title: 'Ожидают ответа',
                  icon: Icons.hourglass_empty,
                  color: Colors.deepPurple,
                  child: _buildStreamStat(
                    stream: FirebaseFirestore.instance.collection('orders').where('status', isEqualTo: 'awaiting_approval').snapshots(),
                    color: Colors.deepPurple[800]!,
                  ),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OrdersScreen(initialTab: 1))),
                ),
                _buildStatCard(
                  context: context,
                  title: 'Выполняются',
                  icon: Icons.build_circle,
                  color: Colors.orange,
                  child: _buildStreamStat(
                    stream: FirebaseFirestore.instance.collection('orders').where('status', isEqualTo: 'in_progress').snapshots(),
                    color: Colors.orange[800]!,
                  ),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OrdersScreen(initialTab: 2))),
                ),
                _buildStatCard(
                  context: context,
                  title: 'Выполненные',
                  icon: Icons.check_circle,
                  color: Colors.teal,
                  child: _buildStreamStat(
                    stream: FirebaseFirestore.instance.collection('orders').where('status', isEqualTo: 'completed').snapshots(),
                    color: Colors.teal[800]!,
                  ),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OrdersScreen(initialTab: 3))),
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

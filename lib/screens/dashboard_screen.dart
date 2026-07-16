import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'users_screen.dart';
import 'orders_screen.dart';
import 'database_cleanup_screen.dart'; 

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  // --- УЛУЧШЕННОЕ БОКОВОЕ МЕНЮ (С ЗАЩИТОЙ ОТ ПЕРЕКРЫТИЯ СИСТЕМНЫХ КНОПОК) ---
  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(color: Colors.blueGrey[900]),
            accountName: const Text('M-SERVICE', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
            accountEmail: const Text('Панель администратора', style: TextStyle(color: Colors.white70, fontSize: 14)),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.admin_panel_settings, size: 40, color: Colors.blueGrey[900]),
            ),
          ),
          // Оборачиваем список в Expanded, чтобы меню скроллилось на маленьких экранах
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                ListTile(
                  leading: Icon(Icons.dashboard, color: Colors.blueGrey[800]),
                  title: const Text('Главный экран', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  onTap: () => Navigator.pop(context), 
                ),
                ListTile(
                  leading: Icon(Icons.list_alt, color: Colors.blueGrey[800]),
                  title: const Text('Управление заказами', style: TextStyle(fontSize: 16)),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const OrdersScreen(initialTab: 0)));
                  },
                ),
                ListTile(
                  leading: Icon(Icons.people, color: Colors.blueGrey[800]),
                  title: const Text('Пользователи', style: TextStyle(fontSize: 16)),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const UsersScreen(initialTab: 1)));
                  },
                ),
                const Divider(height: 32),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Text('ИНСТРУМЕНТЫ', style: TextStyle(color: Colors.blueGrey[400], fontWeight: FontWeight.bold, fontSize: 12)),
                ),
                ListTile(
                  leading: Icon(Icons.add_shopping_cart, color: Colors.blueGrey[600]),
                  title: const Text('Оффлайн-заказ', style: TextStyle(fontSize: 15)),
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Функция в разработке')));
                  },
                ),
                ListTile(
                  leading: Icon(Icons.send, color: Colors.blueGrey[600]),
                  title: const Text('Создать рассылку', style: TextStyle(fontSize: 15)),
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Функция в разработке')));
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // SafeArea защищает кнопку от системного бара Android!
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
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 36, color: color),
              const SizedBox(height: 12),
              child,
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueGrey),
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
        
        return Text(count.toString(), style: TextStyle(fontSize: 28, color: color, fontWeight: FontWeight.w900));
      },
    );
  }

  Widget _buildRevenueStat() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('orders').where('status', isEqualTo: 'completed').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator();
        }

        double totalRevenue = 0;
        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final priceRaw = data['price'];
            if (priceRaw != null) {
               totalRevenue += double.tryParse(priceRaw.toString()) ?? 0;
            }
          }
        }

        return Container(
          decoration: BoxDecoration(
            gradient: LinearAppGradient(colors: [Colors.green[700]!, Colors.teal[800]!]),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Выручка (Выполненные)', style: TextStyle(color: Colors.white70, fontSize: 14)),
                    const SizedBox(height: 8),
                    Text('${totalRevenue.toStringAsFixed(0)} TMT', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  ],
                ),
                const Icon(Icons.account_balance_wallet, size: 48, color: Colors.white30),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.blueGrey[900],
        foregroundColor: Colors.white,
        title: const Text('Главный экран', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      drawer: _buildDrawer(context), 
      body: SingleChildScrollView(
        // Динамический отступ: учитывает кнопки Android снизу + 24 пикселя
        padding: EdgeInsets.only(
          left: 16.0, 
          right: 16.0, 
          top: 16.0, 
          bottom: MediaQuery.of(context).padding.bottom + 24.0
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildRevenueStat(),
            const SizedBox(height: 32),
            
            const Text('Сводка по заказам', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              children: [
                _buildStatCard(
                  context: context,
                  title: 'Новые заказы',
                  icon: Icons.new_releases,
                  color: Colors.orange,
                  child: _buildStreamStat(
                    stream: FirebaseFirestore.instance.collection('orders').where('status', isEqualTo: 'new').snapshots(),
                    color: Colors.orange[800]!,
                  ),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OrdersScreen(initialTab: 0))),
                ),
                _buildStatCard(
                  context: context,
                  title: 'Все заказы',
                  icon: Icons.list_alt,
                  color: Colors.blue,
                  child: _buildStreamStat(
                    stream: FirebaseFirestore.instance.collection('orders').snapshots(),
                    color: Colors.blue[800]!,
                  ),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OrdersScreen(initialTab: 1))),
                ),
              ],
            ),
            
            const SizedBox(height: 32),
            const Text('Пользователи', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              children: [
                _buildStatCard(
                  context: context,
                  title: 'Ожидают подтверждения',
                  icon: Icons.mark_email_unread,
                  color: Colors.red,
                  child: _buildStreamStat(
                    stream: FirebaseFirestore.instance.collection('clients').where('is_approved', isEqualTo: false).snapshots(),
                    color: Colors.red[800]!,
                    filter: (doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return data['rejection_reason'] == null;
                    }
                  ),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UsersScreen(initialTab: 0))),
                ),
                _buildStatCard(
                  context: context,
                  title: 'Активные',
                  icon: Icons.people,
                  color: Colors.teal,
                  child: _buildStreamStat(
                    stream: FirebaseFirestore.instance.collection('clients').where('is_approved', isEqualTo: true).snapshots(),
                    color: Colors.teal[800]!,
                  ),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UsersScreen(initialTab: 1))),
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

class LinearAppGradient extends LinearGradient {
  const LinearAppGradient({required List<Color> colors})
      : super(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight);
}


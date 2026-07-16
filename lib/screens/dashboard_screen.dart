import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'users_screen.dart';
import 'orders_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

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
          return const SizedBox(
            height: 24,
            width: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          );
        }
        
        int count = 0;
        if (snapshot.hasData) {
          if (filter != null) {
            count = snapshot.data!.docs.where(filter).length;
          } else {
            count = snapshot.data!.docs.length;
          }
        }
        
        return Text(
          count.toString(),
          style: TextStyle(fontSize: 28, color: color, fontWeight: FontWeight.w900),
        );
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
            // Пытаемся безопасно спарсить цену (она может быть записана как строка или число)
            final priceRaw = data['price'];
            if (priceRaw != null) {
               totalRevenue += double.tryParse(priceRaw.toString()) ?? 0;
            }
          }
        }

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          color: Colors.green[800],
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Выручка (Выполненные заказы)', style: TextStyle(color: Colors.white70, fontSize: 14)),
                    const SizedBox(height: 8),
                    Text(
                      '${totalRevenue.toStringAsFixed(0)} TMT',
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const Icon(Icons.account_balance_wallet, size: 48, color: Colors.white24),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildRevenueStat(),
          const SizedBox(height: 24),
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
                    return data['rejection_reason'] == null; // Считаем только тех, кому еще не отказали
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
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueGrey[900],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('В разработке')));
            },
            icon: const Icon(Icons.add),
            label: const Text('ДОБАВИТЬ ОФФЛАЙН-ЗАКАЗ', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.blueGrey[900],
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: BorderSide(color: Colors.blueGrey[300]!),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('В разработке')));
            },
            icon: const Icon(Icons.send),
            label: const Text('СОЗДАТЬ РАССЫЛКУ', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}


// Файл: lib/screens/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'users_screen.dart';
import 'orders_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  Widget _buildStatCard(BuildContext context, String title, Stream<QuerySnapshot> stream, VoidCallback onTap) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              StreamBuilder<QuerySnapshot>(
                stream: stream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const CircularProgressIndicator();
                  }
                  return Text(
                    '${snapshot.data?.docs.length ?? 0}',
                    style: const TextStyle(fontSize: 32, color: Colors.teal, fontWeight: FontWeight.bold),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            children: [
              _buildStatCard(
                context,
                'Ожидают\nверификации',
                FirebaseFirestore.instance.collection('users').where('status', isEqualTo: 'pending').snapshots(),
                () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UsersScreen(initialTab: 0))),
              ),
              _buildStatCard(
                context,
                'Все\nпользователи',
                FirebaseFirestore.instance.collection('users').snapshots(),
                () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UsersScreen(initialTab: 1))),
              ),
              _buildStatCard(
                context,
                'Новые\nзаказы',
                FirebaseFirestore.instance.collection('orders').where('status', isEqualTo: 'new').snapshots(),
                () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OrdersScreen(initialTab: 0))),
              ),
              _buildStatCard(
                context,
                'Все\nзаказы',
                FirebaseFirestore.instance.collection('orders').snapshots(),
                () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OrdersScreen(initialTab: 1))),
              ),
            ],
          ),
          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('В разработке')));
              },
              icon: const Icon(Icons.add),
              label: const Text('Добавить оффлайн-заказ'),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('В разработке')));
              },
              icon: const Icon(Icons.send),
              label: const Text('Создать рассылку'),
            ),
          ),
        ],
      ),
    );
  }
}

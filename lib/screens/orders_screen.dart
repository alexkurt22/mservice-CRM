// Файл: lib/screens/orders_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OrdersScreen extends StatelessWidget {
  final int initialTab;
  const OrdersScreen({super.key, required this.initialTab});

  void _changeOrderStatus(String docId, String newStatus) {
    FirebaseFirestore.instance.collection('orders').doc(docId).update({'status': newStatus});
  }

  Widget _buildOrdersList(String status) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('orders').where('status', isEqualTo: status).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('Нет заказов'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;

            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data['client_name'] ?? 'Клиент', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(data['phone'] ?? ''),
                    const SizedBox(height: 8),
                    Text('Проблема: ${data['problem'] ?? ''}', style: const TextStyle(fontStyle: FontStyle.italic)),
                    const SizedBox(height: 12),
                    if (status == 'new')
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => _changeOrderStatus(doc.id, 'in_progress'),
                          child: const Text('В работу'),
                        ),
                      ),
                    if (status == 'in_progress')
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                          onPressed: () => _changeOrderStatus(doc.id, 'completed'),
                          child: const Text('Завершить', style: TextStyle(color: Colors.white)),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      initialIndex: initialTab,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Заказы'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Новые'),
              Tab(text: 'В работе'),
              Tab(text: 'Выполнены'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildOrdersList('new'),
            _buildOrdersList('in_progress'),
            _buildOrdersList('completed'),
          ],
        ),
      ),
    );
  }
}

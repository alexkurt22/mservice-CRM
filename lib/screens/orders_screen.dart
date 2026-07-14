// Файл 1: lib/screens/orders_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'order_details_screen.dart';

class OrdersScreen extends StatelessWidget {
  final int initialTab;

  const OrdersScreen({super.key, this.initialTab = 0});

  Widget _buildOrdersList(Query query) {
    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Ошибка: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('Нет заказов'));
        }

        // Локальная сортировка по дате, чтобы избежать ошибок индексов Firestore
        final docs = snapshot.data!.docs.toList();
        docs.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aTime = aData['created_at'] as Timestamp?;
          final bTime = bData['created_at'] as Timestamp?;
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return bTime.compareTo(aTime);
        });

        return ListView.builder(
          padding: const EdgeInsets.all(8.0),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final clientName = data['client_name'] ?? 'Неизвестный клиент';
            final deviceType = data['device_type'] ?? 'Устройство';
            
            return Card(
              elevation: 2,
              margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4.0),
              child: ListTile(
                title: Text(
                  '$clientName • $deviceType',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  data['problem'] ?? 'Проблема не указана',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => OrderDetailsScreen(
                        orderId: doc.id,
                        orderData: data,
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final firestore = FirebaseFirestore.instance.collection('orders');

    return DefaultTabController(
      length: 4,
      initialIndex: initialTab,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Управление заказами'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Новые'),
              Tab(text: 'Ожидают'),
              Tab(text: 'В работе'),
              Tab(text: 'Архив'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildOrdersList(firestore.where('status', isEqualTo: 'new')),
            _buildOrdersList(firestore.where('status', isEqualTo: 'awaiting_approval')),
            _buildOrdersList(firestore.where('status', isEqualTo: 'in_progress')),
            _buildOrdersList(firestore.where('status', whereIn: ['completed', 'canceled'])),
          ],
        ),
      ),
    );
  }
}

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
          return Center(child: Text('Ошибка базы данных', style: TextStyle(color: Colors.red[700])));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox_outlined, size: 64, color: Colors.blueGrey[200]),
                const SizedBox(height: 16),
                Text('В этой категории пока пусто', style: TextStyle(color: Colors.blueGrey[400], fontSize: 16)),
              ],
            ),
          );
        }

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
          padding: const EdgeInsets.all(12.0),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final clientName = data['client_name'] ?? 'Неизвестный клиент';
            final deviceType = data['device_type'] ?? 'Устройство';
            final status = data['status'] ?? 'new';
            
            // Определяем цвет иконки по статусу
            Color iconColor = Colors.orange;
            IconData statusIcon = Icons.new_releases;
            
            if (status == 'awaiting_approval') { iconColor = Colors.deepOrange; statusIcon = Icons.hourglass_top; }
            else if (status == 'in_progress') { iconColor = Colors.blue; statusIcon = Icons.handyman; }
            else if (status == 'completed') { iconColor = Colors.green; statusIcon = Icons.check_circle; }
            else if (status == 'canceled') { iconColor = Colors.red; statusIcon = Icons.cancel; }

            return Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.only(bottom: 12.0),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => OrderDetailsScreen(orderId: doc.id, orderData: data),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: iconColor.withOpacity(0.1), shape: BoxShape.circle),
                        child: Icon(statusIcon, color: iconColor, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('$clientName', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                            const SizedBox(height: 4),
                            Text(deviceType, style: TextStyle(color: Colors.blueGrey[800], fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text(
                              data['problem'] ?? 'Проблема не указана',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: Colors.blueGrey[400], fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Colors.grey),
                    ],
                  ),
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
    final firestore = FirebaseFirestore.instance.collection('orders');

    return DefaultTabController(
      length: 4,
      initialIndex: initialTab,
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          backgroundColor: Colors.blueGrey[900],
          foregroundColor: Colors.white,
          title: const Text('Управление заказами'),
          bottom: const TabBar(
            isScrollable: true,
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
            tabs: [
              Tab(text: 'Новые'),
              Tab(text: 'Ожидают'),
              Tab(text: 'Выполняются'),
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

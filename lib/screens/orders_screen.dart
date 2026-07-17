import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'order_details_screen.dart';
import 'offline_order_screen.dart'; // Импорт для создания оффлайн-заказов

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
          return bTime.compareTo(aTime); // Новые сверху
        });

        return ListView.builder(
          padding: const EdgeInsets.only(top: 12.0, left: 12.0, right: 12.0, bottom: 80.0), // Отступ снизу для кнопки
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
            
            if (status == 'awaiting_approval') { iconColor = Colors.deepPurple; statusIcon = Icons.hourglass_empty; }
            else if (status == 'in_progress') { iconColor = Colors.orange; statusIcon = Icons.build_circle; }
            else if (status == 'completed') { iconColor = Colors.teal; statusIcon = Icons.check_circle; }
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
                            Text(clientName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
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
                      const Icon(Icons.chevron_right, color: Colors.blueGrey),
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
    return DefaultTabController(
      length: 4, // 4 статуса заказа
      initialIndex: initialTab,
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          backgroundColor: Colors.blueGrey[900],
          foregroundColor: Colors.white,
          title: const Text('Заказы'),
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
            isScrollable: true, // Вкладки можно листать вправо-влево
            tabs: [
              Tab(text: 'Новые'),
              Tab(text: 'Ожидают'),
              Tab(text: 'В работе'),
              Tab(text: 'Выполнены'),
            ],
          ),
        ),
        body: Stack(
          children: [
            TabBarView(
              children: [
                _buildOrdersList(FirebaseFirestore.instance.collection('orders').where('status', isEqualTo: 'new')),
                _buildOrdersList(FirebaseFirestore.instance.collection('orders').where('status', isEqualTo: 'awaiting_approval')),
                _buildOrdersList(FirebaseFirestore.instance.collection('orders').where('status', isEqualTo: 'in_progress')),
                _buildOrdersList(FirebaseFirestore.instance.collection('orders').where('status', isEqualTo: 'completed')),
              ],
            ),
            
            // --- УМНАЯ КНОПКА ДОБАВЛЕНИЯ ЗАКАЗА ---
            // Она появляется только на вкладке "В работе" (индекс 2)
            Builder(
              builder: (ctx) {
                final TabController tabController = DefaultTabController.of(ctx);
                return AnimatedBuilder(
                  animation: tabController.animation!,
                  builder: (context, child) {
                    // Показывать кнопку, если выбрана 3-я вкладка (индекс 2 - "В работе")
                    final bool isWorkingTab = tabController.index == 2;
                    return Positioned(
                      bottom: 16.0,
                      right: 16.0,
                      child: AnimatedOpacity(
                        opacity: isWorkingTab ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 200),
                        child: IgnorePointer(
                          ignoring: !isWorkingTab,
                          child: FloatingActionButton(
                            onPressed: () {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const OfflineOrderScreen()));
                            },
                            backgroundColor: Colors.orange[600],
                            tooltip: 'Добавить заказ в работу',
                            child: const Icon(Icons.add, color: Colors.white, size: 28),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

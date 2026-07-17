import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'order_details_screen.dart';
import 'offline_order_screen.dart'; 

class OrdersScreen extends StatefulWidget {
  final int initialTab;

  const OrdersScreen({super.key, this.initialTab = 0});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this, initialIndex: widget.initialTab);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
  }
  
  // ЭТО ИСПРАВЛЯЕТ БАГ: Если экран уже был открыт, обновляем его вкладку
  @override
  void didUpdateWidget(covariant OrdersScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab != widget.initialTab) {
      _tabController.animateTo(widget.initialTab);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Widget _buildOrdersList(String statusKey) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('status', isEqualTo: statusKey)
          .snapshots(),
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
          padding: EdgeInsets.only(
            top: 12.0,
            left: 12.0,
            right: 12.0,
            bottom: MediaQuery.of(context).padding.bottom + 96.0,
          ),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final clientName = data['client_name'] ?? 'Неизвестный клиент';
            final deviceType = data['device_type'] ?? 'Устройство';
            final currentStatus = data['status'] ?? 'new';
            
            Color iconColor = Colors.orange;
            IconData statusIcon = Icons.new_releases;
            
            if (currentStatus == 'awaiting_approval') {
              iconColor = Colors.deepPurple;
              statusIcon = Icons.hourglass_empty;
            } else if (currentStatus == 'in_progress') {
              iconColor = Colors.orange;
              statusIcon = Icons.build_circle;
            } else if (currentStatus == 'completed') {
              iconColor = Colors.teal;
              statusIcon = Icons.check_circle;
            }

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
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.blueGrey[900],
        foregroundColor: Colors.white,
        title: const Text('Заказы Центр'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          isScrollable: true, 
          tabs: const [
            Tab(text: 'Новые заказы'),
            Tab(text: 'Ожидают ответа клиента'), 
            Tab(text: 'Выполняются'),
            Tab(text: 'Выполненные'),
          ],
        ),
      ),
      floatingActionButton: _tabController.index == 2
          ? Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 8.0),
              child: FloatingActionButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const OfflineOrderScreen()),
                  );
                },
                backgroundColor: Colors.orange[600],
                tooltip: 'Ручной ввод заказа',
                child: const Icon(Icons.add, color: Colors.white, size: 28),
              ),
            )
          : null,
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOrdersList('new'),               
          _buildOrdersList('awaiting_approval'), 
          _buildOrdersList('in_progress'),       
          _buildOrdersList('completed'),          
        ],
      ),
    );
  }
}

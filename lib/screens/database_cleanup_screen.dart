import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DatabaseCleanupScreen extends StatelessWidget {
  const DatabaseCleanupScreen({super.key});

  // Универсальная функция удаления с подтверждением
  Future<void> _deleteDocument(BuildContext context, String collection, String docId, String title) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Подтверждение удаления', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Вы действительно хотите безвозвратно удалить $title?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена', style: TextStyle(color: Colors.blueGrey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700]),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance.collection(collection).doc(docId).delete();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Успешно удалено'), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка удаления: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  // --- СПИСОК ВСЕХ ПОЛЬЗОВАТЕЛЕЙ ---
  Widget _buildClientsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('clients').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('База пользователей пуста', style: TextStyle(color: Colors.grey)));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final name = data['name'] ?? 'Без имени';
            final phone = data['phone'] ?? doc.id;
            final isApproved = data['is_approved'] == true;

            return Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(
                  isApproved ? Icons.person : Icons.person_outline, 
                  color: isApproved ? Colors.green : Colors.grey
                ),
                title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(phone),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_forever, color: Colors.red),
                  tooltip: 'Удалить из базы',
                  onPressed: () => _deleteDocument(context, 'clients', doc.id, 'пользователя "$name"'),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- СПИСОК ВСЕХ ЗАКАЗОВ ---
  Widget _buildOrdersList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('orders').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('База заказов пуста', style: TextStyle(color: Colors.grey)));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final device = data['device_type'] ?? 'Устройство';
            final clientName = data['client_name'] ?? 'Неизвестный';
            final status = data['status'] ?? '';

            return Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const Icon(Icons.build, color: Colors.blueGrey),
                title: Text('$device ($clientName)', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Статус: $status', maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_forever, color: Colors.red),
                  tooltip: 'Удалить из базы',
                  onPressed: () => _deleteDocument(context, 'orders', doc.id, 'заказ "$device"'),
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
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          backgroundColor: Colors.red[900], // Красная шапка, чтобы понимать, что мы в опасной зоне
          foregroundColor: Colors.white,
          title: const Text('Очистка базы', style: TextStyle(fontSize: 18)),
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
            tabs: [
              Tab(text: 'Пользователи'),
              Tab(text: 'Заказы'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildClientsList(),
            _buildOrdersList(),
          ],
        ),
      ),
    );
  }
}


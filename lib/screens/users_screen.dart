// Файл: lib/screens/users_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UsersScreen extends StatelessWidget {
  final int initialTab;
  const UsersScreen({super.key, required this.initialTab});

  void _approveUser(String docId) {
    FirebaseFirestore.instance.collection('users').doc(docId).update({'status': 'approved'});
  }

  void _rejectUser(BuildContext context, String docId) {
    String selectedReason = 'Неверный номер';
    final reasons = ['Неверный номер', 'Неверный код', 'Спам'];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Причина отклонения'),
              content: DropdownButton<String>(
                value: selectedReason,
                isExpanded: true,
                items: reasons.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => selectedReason = val);
                },
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: () {
                    FirebaseFirestore.instance.collection('users').doc(docId).update({
                      'status': 'rejected',
                      'rejection_reason': selectedReason,
                    });
                    Navigator.pop(context);
                  },
                  child: const Text('Отклонить', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          }
        );
      }
    );
  }

  Widget _buildUsersList(String status) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').where('status', isEqualTo: status).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('Нет пользователей'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;

            return Card(
              child: ListTile(
                title: Text(data['client_name'] ?? 'Без имени', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data['phone'] ?? ''),
                    if (status == 'pending')
                      Text('Код: ${data['auth_code'] ?? '-'}', style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
                    if (status == 'rejected')
                      Text('Причина: ${data['rejection_reason'] ?? '-'}', style: const TextStyle(color: Colors.red)),
                  ],
                ),
                trailing: status == 'pending' ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.check_circle, color: Colors.green),
                      onPressed: () => _approveUser(doc.id),
                    ),
                    IconButton(
                      icon: const Icon(Icons.cancel, color: Colors.red),
                      onPressed: () => _rejectUser(context, doc.id),
                    ),
                  ],
                ) : null,
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
          title: const Text('Пользователи'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Ожидают'),
              Tab(text: 'Активные'),
              Tab(text: 'Отклонены'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildUsersList('pending'),
            _buildUsersList('approved'),
            _buildUsersList('rejected'),
          ],
        ),
      ),
    );
  }
}

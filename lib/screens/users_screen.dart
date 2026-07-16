import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UsersScreen extends StatelessWidget {
  final int initialTab;
  const UsersScreen({super.key, required this.initialTab});

  void _approveUser(String docId) {
    FirebaseFirestore.instance.collection('clients').doc(docId).update({
      'is_approved': true,
      'rejection_reason': null, // Очищаем причину, если вдруг одобряем после отказа
    });
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
              title: const Text('Причина отклонения', style: TextStyle(fontWeight: FontWeight.bold)),
              content: DropdownButton<String>(
                value: selectedReason,
                isExpanded: true,
                items: reasons.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => selectedReason = val);
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context), 
                  child: const Text('Отмена', style: TextStyle(color: Colors.blueGrey))
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700]),
                  onPressed: () {
                    FirebaseFirestore.instance.collection('clients').doc(docId).update({
                      'is_approved': false,
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

  // Универсальный метод построения списка для каждой вкладки
  Widget _buildUsersList(bool isApproved, bool isRejected) {
    return StreamBuilder<QuerySnapshot>(
      // Сначала забираем все документы по флагу is_approved, чтобы не перегружать базу сложными индексами
      stream: FirebaseFirestore.instance.collection('clients')
          .where('is_approved', isEqualTo: isApproved)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text('Пусто', style: TextStyle(color: Colors.blueGrey[400], fontSize: 16)));
        }

        // Фильтруем данные в зависимости от того, какая вкладка открыта
        var docs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final reason = data['rejection_reason'];
          if (isApproved) return true; // Вкладка "Активные"
          if (isRejected) return reason != null; // Вкладка "Отклонены"
          return reason == null; // Вкладка "Ожидают"
        }).toList();

        // Сортируем по дате создания (новые сверху)
        docs.sort((a, b) {
          final aTime = (a.data() as Map<String, dynamic>)['created_at'] as Timestamp?;
          final bTime = (b.data() as Map<String, dynamic>)['created_at'] as Timestamp?;
          if (aTime == null || bTime == null) return 0;
          return bTime.compareTo(aTime);
        });

        if (docs.isEmpty) {
          return Center(child: Text('Пусто', style: TextStyle(color: Colors.blueGrey[400], fontSize: 16)));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            
            final isPending = !isApproved && !isRejected;

            return Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isApproved ? Colors.green[100] : (isRejected ? Colors.red[100] : Colors.orange[100]),
                    child: Icon(
                      isApproved ? Icons.person : (isRejected ? Icons.person_off : Icons.person_add),
                      color: isApproved ? Colors.green[700] : (isRejected ? Colors.red[700] : Colors.orange[700]),
                    ),
                  ),
                  title: Text(data['name'] ?? 'Без имени', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.phone, size: 16, color: Colors.blueGrey),
                            const SizedBox(width: 6),
                            Text(data['phone'] ?? '', style: const TextStyle(color: Colors.black87, fontSize: 14)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        if (isPending)
                          Row(
                            children: [
                              const Icon(Icons.sms, size: 16, color: Colors.deepOrange),
                              const SizedBox(width: 6),
                              Text('Код из SMS: ${data['sms_code'] ?? '-'}', style: const TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        if (isRejected)
                          Row(
                            children: [
                              const Icon(Icons.error_outline, size: 16, color: Colors.red),
                              const SizedBox(width: 6),
                              Expanded(child: Text('Причина: ${data['rejection_reason'] ?? '-'}', style: const TextStyle(color: Colors.red))),
                            ],
                          ),
                      ],
                    ),
                  ),
                  trailing: isPending ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.check_circle, color: Colors.green, size: 32),
                        onPressed: () => _approveUser(doc.id),
                        tooltip: 'Одобрить',
                      ),
                      IconButton(
                        icon: const Icon(Icons.cancel, color: Colors.red, size: 32),
                        onPressed: () => _rejectUser(context, doc.id),
                        tooltip: 'Отклонить',
                      ),
                    ],
                  ) : null,
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
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          backgroundColor: Colors.blueGrey[900],
          foregroundColor: Colors.white,
          title: const Text('Пользователи'),
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
            tabs: [
              Tab(text: 'Ожидают'),
              Tab(text: 'Активные'),
              Tab(text: 'Отклонены'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildUsersList(false, false), // Ожидают (isApproved: false, isRejected: false)
            _buildUsersList(true, false),  // Активные
            _buildUsersList(false, true),  // Отклонены
          ],
        ),
      ),
    );
  }
}

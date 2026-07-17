import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UsersScreen extends StatelessWidget {
  final int initialTab;
  const UsersScreen({super.key, required this.initialTab});

  void _approveUser(String docId) {
    FirebaseFirestore.instance.collection('clients').doc(docId).update({
      'is_approved': true,
      'rejection_reason': null, 
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

  // Обновленный метод построения списка с разделением на 4 вкладки
  Widget _buildUsersList(int tabType) {
    // tabType: 0 - Ожидают, 1 - Оффлайн (Незарегистрированные), 2 - Активные, 3 - Отклоненные
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('clients').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text('Пусто', style: TextStyle(color: Colors.blueGrey[400], fontSize: 16)));
        }

        var docs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final reason = data['rejection_reason'];
          final isApproved = data['is_approved'] == true;
          final isOffline = data['is_offline'] == true;

          if (tabType == 0) return !isApproved && reason == null && !isOffline; // Ожидают
          if (tabType == 1) return isOffline; // Оффлайн (Незарегистрированные)
          if (tabType == 2) return isApproved; // Активные
          if (tabType == 3) return !isApproved && reason != null; // Отклоненные
          return false;
        }).toList();

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
            
            final isPending = tabType == 0;
            final isRejected = tabType == 3;
            final isActive = tabType == 2;
            final phone = data['phone'] ?? '';

            return Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isActive ? Colors.green[100] : (isRejected ? Colors.red[100] : Colors.orange[100]),
                    child: Icon(
                      isActive ? Icons.person : (isRejected ? Icons.person_off : Icons.person_add),
                      color: isActive ? Colors.green[700] : (isRejected ? Colors.red[700] : Colors.orange[700]),
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
                            Text(phone, style: const TextStyle(color: Colors.black87, fontSize: 14)),
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
      length: 4, // Теперь 4 вкладки!
      initialIndex: initialTab,
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          backgroundColor: Colors.blueGrey[900],
          foregroundColor: Colors.white,
          title: const Text('База клиентов'),
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
            isScrollable: true, // Позволяет вкладкам скроллиться на маленьких экранах
            tabs: [
              Tab(text: 'Ожидают'),
              Tab(text: 'Незарегитрированные'),
              Tab(text: 'Зарегистрированные'),
              Tab(text: 'Отклоненные'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildUsersList(0), // Ожидают
            _buildUsersList(1), // Оффлайн
            _buildUsersList(2), // Активные
            _buildUsersList(3), // Отклоненные
          ],
        ),
      ),
    );
  }
}

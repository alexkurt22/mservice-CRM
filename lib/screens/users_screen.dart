import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'private_chat_screen.dart'; // Подключаем экран переписки

class UsersScreen extends StatefulWidget {
  final int initialTab;
  const UsersScreen({super.key, required this.initialTab});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this, initialIndex: widget.initialTab);
  }

  @override
  void didUpdateWidget(covariant UsersScreen oldWidget) {
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

  // --- ЛОГИКА СОЗДАНИЯ ИЛИ ОТКРЫТИЯ ЧАТА С КЛИЕНТОМ ---
  Future<void> _openPrivateChat(BuildContext context, String targetPhone, String targetName) async {
    final prefs = await SharedPreferences.getInstance();
    final myPhone = prefs.getString('employee_phone') ?? 'admin';

    // Формируем уникальный ID комнаты (сортируем номера, чтобы ID был одинаков для обоих)
    List<String> participants = [myPhone, targetPhone];
    participants.sort();
    String roomId = 'private_${participants[0]}_${participants[1]}';

    final roomRef = FirebaseFirestore.instance.collection('chat_rooms').doc(roomId);
    final doc = await roomRef.get();

    // Если комнаты еще нет — создаем её в базе
    if (!doc.exists) {
      await roomRef.set({
        'type': 'private',
        'participants': participants,
        'created_at': FieldValue.serverTimestamp(),
        'last_message': 'Чат создан',
        'last_message_time': FieldValue.serverTimestamp(),
      });
    }

    // Открываем экран переписки
    if (context.mounted) {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => PrivateChatScreen(roomId: roomId, targetName: targetName)
      ));
    }
  }

  Widget _buildUsersList(int tabType) {
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

          if (tabType == 0) return !isApproved && reason == null && !isOffline; // Ждут одобрения
          if (tabType == 1) return isOffline; // Не зарегистрированные (Оффлайн)
          if (tabType == 2) return isApproved; // Зарегистрированные
          if (tabType == 3) return !isApproved && reason != null; // Отклонённые
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
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 20, top: 12, left: 12, right: 12),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            
            final isPending = tabType == 0;
            final isRejected = tabType == 3;
            final isActive = tabType == 2;
            final phone = data['phone'] ?? '';
            final name = data['name'] ?? 'Без имени';

            // ОПРЕДЕЛЯЕМ КНОПКИ СПРАВА
            Widget? trailingWidget;
            if (isPending) {
              trailingWidget = Row(
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
              );
            } else if (isActive && phone.isNotEmpty) {
              // ❗ КНОПКА ЧАТА ДЛЯ ЗАРЕГИСТРИРОВАННЫХ КЛИЕНТОВ ❗
              trailingWidget = IconButton(
                icon: const Icon(Icons.chat, color: Colors.blue, size: 28),
                onPressed: () => _openPrivateChat(context, phone, name),
                tooltip: 'Написать сообщение',
              );
            }

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
                  title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                  trailing: trailingWidget,
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
        title: const Text('База клиентов'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          isScrollable: true, 
          tabs: const [
            Tab(text: 'Ждут одобрения'),
            Tab(text: 'Не зарегистрированные'),
            Tab(text: 'Зарегистрированные'),
            Tab(text: 'Отклонённые'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildUsersList(0), 
          _buildUsersList(1), 
          _buildUsersList(2), 
          _buildUsersList(3), 
        ],
      ),
    );
  }
}

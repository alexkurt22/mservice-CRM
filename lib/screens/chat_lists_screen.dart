import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'private_chat_screen.dart'; 

// 1. ЭКРАН СПИСКА ЧАТОВ С КЛИЕНТАМИ
class ClientChatsListScreen extends StatefulWidget {
  const ClientChatsListScreen({super.key});

  @override
  State<ClientChatsListScreen> createState() => _ClientChatsListScreenState();
}

class _ClientChatsListScreenState extends State<ClientChatsListScreen> {
  String _myPhone = 'admin';

  @override
  void initState() {
    super.initState();
    _loadMyPhone();
  }

  Future<void> _loadMyPhone() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _myPhone = prefs.getString('employee_phone') ?? 'admin';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Чаты с клиентами'), 
        backgroundColor: Colors.blue[700], 
        foregroundColor: Colors.white
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('chat_rooms').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState();
          }

          final allRooms = snapshot.data!.docs;
          final rooms = allRooms.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data['type'] == 'private';
          }).toList();

          if (rooms.isEmpty) {
            return _buildEmptyState();
          }

          rooms.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aTime = aData['last_message_time'] as Timestamp?;
            final bTime = bData['last_message_time'] as Timestamp?;
            if (aTime == null && bTime == null) return 0;
            if (aTime == null) return 1;
            if (bTime == null) return -1;
            return bTime.compareTo(aTime);
          });

          return ListView.builder(
            padding: EdgeInsets.only(
              top: 8.0,
              left: 8.0,
              right: 8.0,
              bottom: MediaQuery.of(context).padding.bottom + 20
            ),
            itemCount: rooms.length,
            itemBuilder: (context, i) {
              final data = rooms[i].data() as Map<String, dynamic>;
              final participants = data['participants'] as List<dynamic>? ?? [];
              
              String clientPhone = 'Клиент';
              if (participants.isNotEmpty) {
                clientPhone = participants.firstWhere((p) => p != _myPhone, orElse: () => participants.last).toString();
              }

              // ❗ НОВОЕ: ИЩЕМ ИМЯ КЛИЕНТА В БАЗЕ ПО ЕГО НОМЕРУ ❗
              return FutureBuilder<QuerySnapshot>(
                future: FirebaseFirestore.instance.collection('clients').where('phone', isEqualTo: clientPhone).limit(1).get(),
                builder: (context, clientSnapshot) {
                  
                  String displayName = clientPhone; // По умолчанию показываем номер телефона
                  
                  // Если клиент найден в базе, берем его имя
                  if (clientSnapshot.hasData && clientSnapshot.data!.docs.isNotEmpty) {
                    final clientData = clientSnapshot.data!.docs.first.data() as Map<String, dynamic>;
                    if (clientData['name'] != null && clientData['name'].toString().trim().isNotEmpty) {
                      displayName = clientData['name'];
                    }
                  }

                  return Card(
                    elevation: 1,
                    margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue[50], 
                        child: Icon(Icons.person, color: Colors.blue[700])
                      ),
                      title: Text(
                        displayName, // ❗ ВЫВОДИМ ИМЯ
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
                      ), 
                      subtitle: Text(
                        data['last_message'] ?? 'Нет сообщений', 
                        maxLines: 1, 
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.grey[600])
                      ),
                      trailing: const Icon(Icons.chevron_right, color: Colors.blueGrey),
                      onTap: () => Navigator.push(
                        context, 
                        MaterialPageRoute(
                          // Передаем ИМЯ внутрь чата, чтобы оно горело в шапке
                          builder: (_) => PrivateChatScreen(roomId: rooms[i].id, targetName: displayName)
                        )
                      ),
                    ),
                  );
                }
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 64, color: Colors.blueGrey[200]),
            const SizedBox(height: 16),
            Text(
              'Нет активных чатов', 
              style: TextStyle(color: Colors.blueGrey[600], fontSize: 16, fontWeight: FontWeight.bold)
            ),
            const SizedBox(height: 8),
            const Text(
              'Чтобы начать чат, перейдите в блок Клиенты -> Зарегистрированные и нажмите на синюю иконку сообщения.', 
              textAlign: TextAlign.center, 
              style: TextStyle(color: Colors.grey, fontSize: 13)
            ),
          ],
        ),
      ),
    );
  }
}

// 2. ЭКРАН СПИСКА СОТРУДНИКОВ (Для внутреннего чата команды)
class TeamChatsListScreen extends StatelessWidget {
  const TeamChatsListScreen({super.key});

  Future<void> _startChatWithEmployee(BuildContext context, String empPhone, String empName) async {
    final prefs = await SharedPreferences.getInstance();
    final myPhone = prefs.getString('employee_phone') ?? 'admin';
    
    List<String> participants = [myPhone, empPhone];
    participants.sort();
    String roomId = 'team_${participants[0]}_${participants[1]}';

    final roomRef = FirebaseFirestore.instance.collection('chat_rooms').doc(roomId);
    final doc = await roomRef.get();
    
    if (!doc.exists) {
      await roomRef.set({
        'type': 'team',
        'participants': participants,
        'created_at': FieldValue.serverTimestamp(),
        'last_message': 'Чат создан',
        'last_message_time': FieldValue.serverTimestamp(),
      });
    }

    if (context.mounted) {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => PrivateChatScreen(roomId: roomId, targetName: empName)
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Чат команды'), 
        backgroundColor: Colors.orange[600], 
        foregroundColor: Colors.white
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('employees').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.group_off, size: 64, color: Colors.blueGrey[200]),
                  const SizedBox(height: 16),
                  Text(
                    'Нет сотрудников', 
                    style: TextStyle(color: Colors.blueGrey[600], fontSize: 16, fontWeight: FontWeight.bold)
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'В базе данных (коллекция employees) пока пусто.', 
                    textAlign: TextAlign.center, 
                    style: TextStyle(color: Colors.grey, fontSize: 13)
                  ),
                ],
              ),
            );
          }

          final employees = snapshot.data!.docs;
          
          return ListView.builder(
            padding: EdgeInsets.only(
              top: 8.0,
              left: 8.0,
              right: 8.0,
              bottom: MediaQuery.of(context).padding.bottom + 20
            ),
            itemCount: employees.length,
            itemBuilder: (context, i) {
              final data = employees[i].data() as Map<String, dynamic>;
              final String empName = data['name'] ?? 'Сотрудник';
              final String empPhone = data['phone'] ?? '';
              
              return Card(
                elevation: 1,
                margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.orange, 
                    child: Icon(Icons.person, color: Colors.white)
                  ),
                  title: Text(empName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(empPhone),
                  trailing: const Icon(Icons.chevron_right, color: Colors.blueGrey),
                  onTap: () => _startChatWithEmployee(context, empPhone, empName),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'private_chat_screen.dart'; 

// 1. ЭКРАН СПИСКА ЧАТОВ С КЛИЕНТАМИ
class ClientChatsListScreen extends StatelessWidget {
  const ClientChatsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Чаты с клиентами'), backgroundColor: Colors.blue[700], foregroundColor: Colors.white),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('chat_rooms').where('type', isEqualTo: 'private').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('Нет активных чатов'));
          
          final rooms = snapshot.data!.docs;
          return ListView.builder(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 20),
            itemCount: rooms.length,
            itemBuilder: (context, i) {
              final data = rooms[i].data() as Map<String, dynamic>;
              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text('Клиент: ${data['participants']?.last ?? '...' }'), 
                subtitle: Text(data['last_message'] ?? 'Нет сообщений'),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PrivateChatScreen(roomId: rooms[i].id, targetName: 'Клиент'))),
              );
            },
          );
        },
      ),
    );
  }
}

// 2. ЭКРАН СПИСКА СОТРУДНИКОВ (Для внутреннего чата)
class TeamChatsListScreen extends StatelessWidget {
  const TeamChatsListScreen({super.key});

  // Логика перехода к приватному чату с сотрудником
  Future<void> _startChatWithEmployee(BuildContext context, String empPhone, String empName) async {
    final prefs = await SharedPreferences.getInstance();
    final myPhone = prefs.getString('employee_phone') ?? 'admin';
    
    List<String> participants = [myPhone, empPhone];
    participants.sort();
    String roomId = 'team_${participants[0]}_${participants[1]}';

    // Создаем комнату, если не существует
    final roomRef = FirebaseFirestore.instance.collection('chat_rooms').doc(roomId);
    final doc = await roomRef.get();
    
    if (!doc.exists) {
      await roomRef.set({
        'type': 'team',
        'participants': participants,
        'created_at': FieldValue.serverTimestamp(),
      });
    }

    if (context.mounted) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => PrivateChatScreen(roomId: roomId, targetName: empName)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Сотрудники'), backgroundColor: Colors.orange[600], foregroundColor: Colors.white),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('employees').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final employees = snapshot.data!.docs;
          
          return ListView.builder(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 20),
            itemCount: employees.length,
            itemBuilder: (context, i) {
              final data = employees[i].data() as Map<String, dynamic>;
              return ListTile(
                leading: const CircleAvatar(backgroundColor: Colors.orange, child: Icon(Icons.person, color: Colors.white)),
                title: Text(data['name'] ?? 'Сотрудник'),
                subtitle: Text(data['phone'] ?? ''),
                onTap: () => _startChatWithEmployee(context, data['phone'] ?? '', data['name'] ?? 'Сотрудник'),
              );
            },
          );
        },
      ),
    );
  }
}

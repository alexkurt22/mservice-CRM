import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'private_chat_screen.dart'; 

// 1. Экран списка чатов с КЛИЕНТАМИ
class ClientChatsListScreen extends StatelessWidget {
  const ClientChatsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Чаты с клиентами'), backgroundColor: Colors.blue[700], foregroundColor: Colors.white),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('chat_rooms').where('type', isEqualTo: 'private').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final rooms = snapshot.data!.docs;
          return ListView.builder(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 20),
            itemCount: rooms.length,
            itemBuilder: (context, i) {
              final data = rooms[i].data() as Map<String, dynamic>;
              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text('Клиент: ${data['participants']?.last ?? '...' }'), // Упрощенно
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

// 2. Экран списка чатов КОМАНДЫ (Сотрудники + Группы)
class TeamChatsListScreen extends StatelessWidget {
  const TeamChatsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Чат команды'), backgroundColor: Colors.orange[600], foregroundColor: Colors.white),
      floatingActionButton: FloatingActionButton(
        onPressed: () { /* Логика создания группы */ },
        child: const Icon(Icons.group_add),
      ),
      body: const Center(child: Text('Список сотрудников и групп')),
    );
  }
}


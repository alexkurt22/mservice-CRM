import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/push_service.dart'; // ❗ ПОДКЛЮЧИЛИ СЕРВИС ПУШЕЙ

class InternalChatScreen extends StatefulWidget {
  const InternalChatScreen({super.key});

  @override
  State<InternalChatScreen> createState() => _InternalChatScreenState();
}

class _InternalChatScreenState extends State<InternalChatScreen> {
  final TextEditingController _msgController = TextEditingController();
  String _employeeName = "Сотрудник";
  String _employeePhone = "";

  @override
  void initState() {
    super.initState();
    _loadEmployeeData();
  }

  Future<void> _loadEmployeeData() async {
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString('employee_phone') ?? "";
    setState(() => _employeePhone = phone);
    
    // Получаем имя из базы
    final doc = await FirebaseFirestore.instance.collection('employees').doc(phone).get();
    if (doc.exists) {
      setState(() => _employeeName = doc.data()?['name'] ?? "Сотрудник");
    }
  }

  Future<void> _sendMessage() async {
    if (_msgController.text.trim().isEmpty) return;

    final text = _msgController.text.trim();
    _msgController.clear();

    // 1. Сохраняем сообщение в базу
    await FirebaseFirestore.instance.collection('internal_chat').add({
      'sender_name': _employeeName,
      'sender_phone': _employeePhone,
      'text': text,
      'created_at': FieldValue.serverTimestamp(),
    });

    // 2. ❗ ОТПРАВЛЯЕМ PUSH ВСЕМ СОТРУДНИКАМ В РАЦИЮ ❗
    try {
      final result = await PushService.sendPushToAdmins('Чат сотрудников', '$_employeeName: $text');
      
      // Выводим диагностическую табличку (потом можно будет убрать)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Push команде: $result', style: const TextStyle(fontSize: 12)), 
            duration: const Duration(seconds: 3)
          )
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка Push: $e'))
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Чат сотрудников'),
        backgroundColor: Colors.blueGrey[900],
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('internal_chat').orderBy('created_at', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                
                final messages = snapshot.data!.docs;
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (ctx, i) {
                    final data = messages[i].data() as Map<String, dynamic>;
                    bool isMe = data['sender_phone'] == _employeePhone;
                    
                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isMe ? Colors.blueGrey[700] : Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(data['sender_name'], style: TextStyle(fontSize: 10, color: isMe ? Colors.white70 : Colors.blueGrey)),
                            Text(data['text'], style: TextStyle(fontSize: 16, color: isMe ? Colors.white : Colors.black)),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _msgController,
                      decoration: const InputDecoration(hintText: 'Сообщение...', border: OutlineInputBorder()),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send, color: Colors.blueGrey),
                    onPressed: _sendMessage,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

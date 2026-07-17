import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart'; // Добавь в pubspec.yaml: intl: ^0.18.0

class PrivateChatScreen extends StatefulWidget {
  final String roomId;
  final String targetName;

  const PrivateChatScreen({super.key, required this.roomId, required this.targetName});

  @override
  State<PrivateChatScreen> createState() => _PrivateChatScreenState();
}

class _PrivateChatScreenState extends State<PrivateChatScreen> {
  final TextEditingController _controller = TextEditingController();
  String? _myPhone;

  @override
  void initState() {
    super.initState();
    _getMyPhone();
  }

  Future<void> _getMyPhone() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _myPhone = prefs.getString('employee_phone'));
  }

  Future<void> _sendMessage() async {
    if (_controller.text.trim().isEmpty) return;
    final text = _controller.text.trim();
    _controller.clear();

    await FirebaseFirestore.instance.collection('chat_rooms').doc(widget.roomId).collection('messages').add({
      'text': text,
      'sender_phone': _myPhone,
      'created_at': FieldValue.serverTimestamp(),
      'is_read': false,
    });
    
    // Обновляем последнее сообщение в комнате
    await FirebaseFirestore.instance.collection('chat_rooms').doc(widget.roomId).update({
      'last_message': text,
      'last_message_time': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.targetName), backgroundColor: Colors.blueGrey[900], foregroundColor: Colors.white),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chat_rooms')
                  .doc(widget.roomId)
                  .collection('messages')
                  .orderBy('created_at', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                
                final messages = snapshot.data!.docs;
                
                return ListView.builder(
                  reverse: true,
                  padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 80),
                  itemCount: messages.length,
                  itemBuilder: (ctx, i) {
                    final data = messages[i].data() as Map<String, dynamic>;
                    final bool isMe = data['sender_phone'] == _myPhone;
                    final Timestamp? ts = data['created_at'] as Timestamp?;
                    final DateTime dt = ts?.toDate() ?? DateTime.now();
                    
                    // Логика разделителя даты
                    bool showDate = false;
                    if (i == messages.length - 1) {
                      showDate = true;
                    } else {
                      final prevData = messages[i+1].data() as Map<String, dynamic>;
                      final prevTs = prevData['created_at'] as Timestamp?;
                      if (prevTs != null && ts != null) {
                        if (prevTs.toDate().day != ts.toDate().day) showDate = true;
                      }
                    }

                    return Column(
                      children: [
                        if (showDate) Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(DateFormat('dd MMM yyyy').format(dt), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        ),
                        Align(
                          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isMe ? Colors.blue[100] : Colors.grey[200],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(data['text'], style: const TextStyle(fontSize: 16)),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(DateFormat('HH:mm').format(dt), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                    if (isMe) ...[
                                      const SizedBox(width: 4),
                                      Icon(Icons.done_all, size: 14, color: data['is_read'] == true ? Colors.blue : Colors.grey),
                                    ]
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 8, left: 8, right: 8, top: 8),
            child: Row(
              children: [
                Expanded(child: TextField(controller: _controller, decoration: const InputDecoration(hintText: 'Сообщение...'))),
                IconButton(icon: const Icon(Icons.send), onPressed: _sendMessage),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


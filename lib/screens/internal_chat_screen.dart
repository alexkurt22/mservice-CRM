import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../services/push_service.dart'; 

class InternalChatScreen extends StatefulWidget {
  const InternalChatScreen({super.key});

  @override
  State<InternalChatScreen> createState() => _InternalChatScreenState();
}

class _InternalChatScreenState extends State<InternalChatScreen> {
  final TextEditingController _msgController = TextEditingController();
  String _employeeName = "Сотрудник";
  String _employeePhone = "";

  // Для поиска
  bool _isSearching = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadEmployeeData();
  }

  @override
  void dispose() {
    _msgController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadEmployeeData() async {
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString('employee_phone') ?? "";
    setState(() => _employeePhone = phone);
    
    final doc = await FirebaseFirestore.instance.collection('employees').doc(phone).get();
    if (doc.exists) {
      setState(() => _employeeName = doc.data()?['name'] ?? "Сотрудник");
    }
  }

  Future<void> _sendMessage() async {
    if (_msgController.text.trim().isEmpty) return;

    final text = _msgController.text.trim();
    _msgController.clear();

    await FirebaseFirestore.instance.collection('internal_chat').add({
      'sender_name': _employeeName,
      'sender_phone': _employeePhone,
      'text': text,
      'created_at': FieldValue.serverTimestamp(),
    });

    try {
      // ИСПРАВЛЕНО: передаем только 2 аргумента, как ожидает функция sendPushToAdmins в push_service.dart
      await PushService.sendPushToAdmins('Чат сотрудников', '$_employeeName: $text');
    } catch (e) {
      debugPrint('Ошибка Push: $e');
    }
  }

  String _getFriendlyDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final targetDate = DateTime(date.year, date.month, date.day);

    if (targetDate == today) {
      return 'СЕГОДНЯ';
    } else if (targetDate == yesterday) {
      return 'ВЧЕРА';
    } else {
      return DateFormat('dd MMM yyyy').format(date).toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.grey[900] : Colors.grey[100],
      appBar: AppBar(
        backgroundColor: isDark ? Colors.black : Colors.blueGrey[900],
        foregroundColor: Colors.white,
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Поиск по сообщениям...',
                  hintStyle: TextStyle(color: Colors.white54),
                  border: InputBorder.none,
                ),
                onChanged: (val) {
                  setState(() => _searchQuery = val.trim().toLowerCase());
                },
              )
            : const Text('Общая Рация (Команда)'),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  _searchQuery = '';
                }
              });
            },
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('internal_chat').orderBy('created_at', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                
                var messages = snapshot.data!.docs.toList();

                if (_searchQuery.isNotEmpty) {
                  messages = messages.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final text = (data['text'] ?? '').toString().toLowerCase();
                    return text.contains(_searchQuery);
                  }).toList();
                }

                if (messages.isEmpty) {
                  return Center(child: Text(_searchQuery.isNotEmpty ? 'Ничего не найдено' : 'Нет сообщений', style: const TextStyle(color: Colors.grey)));
                }

                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.only(top: 10, bottom: 20),
                  itemCount: messages.length,
                  itemBuilder: (ctx, i) {
                    final data = messages[i].data() as Map<String, dynamic>;
                    final bool isMe = data['sender_phone'] == _employeePhone;
                    
                    final Timestamp? ts = data['created_at'] as Timestamp?;
                    final DateTime dt = ts?.toDate() ?? DateTime.now();
                    final bool isSending = ts == null; 
                    
                    bool showDate = false;
                    if (i == messages.length - 1) {
                      showDate = true;
                    } else if (!isSending) {
                      final prevData = messages[i+1].data() as Map<String, dynamic>;
                      final prevTs = prevData['created_at'] as Timestamp?;
                      if (prevTs != null) {
                        if (prevTs.toDate().day != dt.day) showDate = true;
                      }
                    }

                    return Column(
                      children: [
                        if (showDate && !_isSearching) 
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                            child: Row(
                              children: [
                                Expanded(child: Divider(color: isDark ? Colors.grey[800] : Colors.grey[300], thickness: 1)),
                                Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 12),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.grey[800] : Colors.blueGrey[50],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    _getFriendlyDate(dt), 
                                    style: TextStyle(color: isDark ? Colors.white70 : Colors.blueGrey[700], fontSize: 11, fontWeight: FontWeight.bold)
                                  ),
                                ),
                                Expanded(child: Divider(color: isDark ? Colors.grey[800] : Colors.grey[300], thickness: 1)),
                              ],
                            ),
                          ),
                        
                        Align(
                          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: EdgeInsets.only(
                              left: isMe ? 50 : 10, 
                              right: isMe ? 10 : 50, 
                              top: 4, 
                              bottom: 4
                            ),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isMe 
                                  ? (isDark ? Colors.orange[900] : Colors.orange[100]) 
                                  : (isDark ? Colors.grey[800] : Colors.white),
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(16),
                                topRight: const Radius.circular(16),
                                bottomLeft: Radius.circular(isMe ? 16 : 4),
                                bottomRight: Radius.circular(isMe ? 4 : 16),
                              ),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.05), blurRadius: 2, offset: const Offset(0, 1))
                              ]
                            ),
                            child: Column(
                              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                              children: [
                                if (!isMe)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Text(data['sender_name'] ?? 'Коллега', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue[700])),
                                  ),
                                Text(
                                  data['text'] ?? '', 
                                  style: TextStyle(fontSize: 16, color: isDark ? Colors.white : Colors.black87)
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  isSending ? 'Отправка...' : DateFormat('HH:mm').format(dt), 
                                  style: TextStyle(fontSize: 10, color: isDark ? Colors.white54 : Colors.grey[600])
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
          
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.05), blurRadius: 5, offset: const Offset(0, -2))],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _msgController, 
                      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                      decoration: InputDecoration(
                        hintText: 'Сообщение в общую рацию...',
                        hintStyle: TextStyle(color: isDark ? Colors.white54 : Colors.grey),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                        filled: true,
                        fillColor: isDark ? Colors.grey[800] : Colors.grey[200],
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      maxLines: 3,
                      minLines: 1,
                      textCapitalization: TextCapitalization.sentences,
                    )
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(color: Colors.orange[600], shape: BoxShape.circle),
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white), 
                      onPressed: _sendMessage
                    ),
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

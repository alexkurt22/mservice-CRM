import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart'; // Подключили плагин для звонков
import 'private_chat_screen.dart'; 
import 'import_clients_screen.dart';

class UsersScreen extends StatefulWidget {
  final int tabType;
  final String title;

  const UsersScreen({
    super.key, 
    required this.tabType,
    required this.title,
  });

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {

  // --- ЛОГИКА ЗВОНКА ---
  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Не удалось открыть звонилку на этом устройстве')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка вызова: $e')),
        );
      }
    }
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

  Future<void> _openPrivateChat(BuildContext context, String targetPhone, String targetName) async {
    final prefs = await SharedPreferences.getInstance();
    final myPhone = prefs.getString('employee_phone') ?? 'admin';

    List<String> participants = [myPhone, targetPhone];
    participants.sort();
    String roomId = 'private_${participants[0]}_${participants[1]}';

    final roomRef = FirebaseFirestore.instance.collection('chat_rooms').doc(roomId);
    final doc = await roomRef.get();

    if (!doc.exists) {
      await roomRef.set({
        'type': 'private',
        'participants': participants,
        'created_at': FieldValue.serverTimestamp(),
        'last_message': 'Чат создан',
        'last_message_time': FieldValue.serverTimestamp(),
      });
    }

    if (context.mounted) {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => PrivateChatScreen(roomId: roomId, targetName: targetName)
      ));
    }
  }

  // --- ЛОГИКА ДОБАВЛЕНИЯ ОФФЛАЙН КЛИЕНТА ---
  void _showAddOfflineClientDialog() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController(text: '+993');
    bool isSaving = false;
    bool isChecking = false;
    String warningMessage = '';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            
            void checkPhone(String currentPhone) async {
              if (currentPhone.length < 11) {
                setModalState(() => warningMessage = '');
                return;
              }
              setModalState(() { isChecking = true; warningMessage = ''; });
              
              final existingCheck = await FirebaseFirestore.instance
                  .collection('clients')
                  .where('phone', isEqualTo: currentPhone)
                  .get();

              setModalState(() {
                isChecking = false;
                if (existingCheck.docs.isNotEmpty) {
                  final clientName = existingCheck.docs.first.data()['name'] ?? 'Неизвестно';
                  warningMessage = 'Этот номер уже принадлежит клиенту: $clientName';
                }
              });
            }

            return AlertDialog(
              title: const Text('Новый клиент (Оффлайн)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: phoneController,
                    decoration: InputDecoration(
                      labelText: 'Номер телефона',
                      prefixIcon: const Icon(Icons.phone),
                      suffixIcon: isChecking ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2)) : null,
                    ),
                    keyboardType: TextInputType.phone,
                    onChanged: checkPhone, 
                  ),
                  
                  if (warningMessage.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(warningMessage, style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),

                  const SizedBox(height: 16),
                  
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Имя клиента',
                      prefixIcon: Icon(Icons.person),
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                ],
              ),
              actions: [
                if (!isSaving)
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Отмена', style: TextStyle(color: Colors.blueGrey)),
                  ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: warningMessage.isNotEmpty ? Colors.grey : Colors.blueGrey[900]),
                  onPressed: (isSaving || warningMessage.isNotEmpty) ? null : () async {
                    final name = nameController.text.trim();
                    final phone = phoneController.text.trim();

                    if (name.isEmpty || phone.isEmpty || phone.length < 8) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Заполните корректно Телефон и Имя')));
                      return;
                    }

                    setModalState(() => isSaving = true);

                    try {
                      await FirebaseFirestore.instance.collection('clients').add({
                        'name': name,
                        'phone': phone,
                        'is_offline': true, 
                        'is_approved': false,
                        'created_at': FieldValue.serverTimestamp(),
                      });

                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Оффлайн клиент успешно добавлен!'), backgroundColor: Colors.green));
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red));
                      setModalState(() => isSaving = false);
                    }
                  },
                  child: isSaving 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Сохранить', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      }
    );
  }

  Widget _buildUsersList() {
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

          if (widget.tabType == 0) return !isApproved && reason == null && !isOffline; 
          if (widget.tabType == 1) return isOffline; 
          if (widget.tabType == 2) return isApproved && !isOffline; 
          if (widget.tabType == 3) return !isApproved && reason != null; 
          return false;
        }).toList();

        docs.sort((a, b) {
          final aTime = (a.data() as Map<String, dynamic>)['created_at'] as Timestamp?;
          final bTime = (b.data() as Map<String, dynamic>)['created_at'] as Timestamp?;
          if (aTime == null || bTime == null) return 0;
          return bTime.compareTo(aTime);
        });

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.group_off_outlined, size: 64, color: Colors.blueGrey[200]),
                const SizedBox(height: 16),
                Text('В этой категории пока пусто', style: TextStyle(color: Colors.blueGrey[400], fontSize: 16)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 80, top: 12, left: 12, right: 12),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            
            final isPending = widget.tabType == 0;
            final isRejected = widget.tabType == 3;
            final isActive = widget.tabType == 2;
            final isOfflineTab = widget.tabType == 1;
            
            final phone = data['phone'] ?? '';
            final name = data['name'] ?? 'Без имени';

            // --- УМНОЕ ФОРМИРОВАНИЕ КНОПОК СПРАВА ---
            List<Widget> trailingActions = [];

            // 1. КНОПКА ЗВОНКА (Добавляется ВСЕМ, у кого есть номер телефона)
            if (phone.isNotEmpty) {
              trailingActions.add(
                IconButton(
                  icon: const Icon(Icons.phone_in_talk, color: Colors.teal),
                  onPressed: () => _makePhoneCall(phone),
                  tooltip: 'Позвонить',
                )
              );
            }

            // 2. КНОПКИ ДЕЙСТВИЙ В ЗАВИСИМОСТИ ОТ СТАТУСА
            if (isPending) {
              trailingActions.add(
                IconButton(
                  icon: const Icon(Icons.check_circle, color: Colors.green),
                  onPressed: () => _approveUser(doc.id),
                  tooltip: 'Одобрить',
                )
              );
              trailingActions.add(
                IconButton(
                  icon: const Icon(Icons.cancel, color: Colors.red),
                  onPressed: () => _rejectUser(context, doc.id),
                  tooltip: 'Отклонить',
                )
              );
            } else if (isActive && phone.isNotEmpty) {
              trailingActions.add(
                IconButton(
                  icon: const Icon(Icons.chat, color: Colors.blue),
                  onPressed: () => _openPrivateChat(context, phone, name),
                  tooltip: 'Написать сообщение',
                )
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
                    backgroundColor: isActive ? Colors.green[100] : (isRejected ? Colors.red[100] : (isOfflineTab ? Colors.grey[200] : Colors.orange[100])),
                    child: Icon(
                      isActive ? Icons.verified_user : (isRejected ? Icons.person_off : (isOfflineTab ? Icons.person_outline : Icons.person_add)),
                      color: isActive ? Colors.green[700] : (isRejected ? Colors.red[700] : (isOfflineTab ? Colors.grey[700] : Colors.orange[700])),
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
                        if (isOfflineTab)
                          Row(
                            children: [
                              const Icon(Icons.app_blocking, size: 16, color: Colors.grey),
                              const SizedBox(width: 6),
                              const Text('Добавлен вручную', style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                      ],
                    ),
                  ),
                  // Выводим все собранные кнопки в один ряд
                  trailing: trailingActions.isNotEmpty 
                      ? Row(mainAxisSize: MainAxisSize.min, children: trailingActions)
                      : null,
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
        title: Text(widget.title), 
        actions: [
          if (widget.tabType == 1)
            IconButton(
              icon: const Icon(Icons.upload_file),
              tooltip: 'Массовый импорт базы',
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ImportClientsScreen()));
              },
            ),
        ],
      ),
      floatingActionButton: widget.tabType == 1 
          ? FloatingActionButton.extended(
              onPressed: _showAddOfflineClientDialog,
              backgroundColor: Colors.blueGrey[800],
              icon: const Icon(Icons.person_add, color: Colors.white),
              label: const Text('Добавить', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          : null,
      body: _buildUsersList(), 
    );
  }
}

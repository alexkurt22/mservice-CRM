import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mservice_crm/services/fcm_service.dart';

class OrderDetailsScreen extends StatefulWidget {
  final String orderId;
  final Map<String, dynamic> orderData;

  const OrderDetailsScreen({
    super.key,
    required this.orderId,
    required this.orderData,
  });

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  final List<Map<String, TextEditingController>> _options = [
    {
      'description': TextEditingController(),
      'price': TextEditingController(),
    }
  ];
  bool _isLoading = false;

  @override
  void dispose() {
    for (var opt in _options) {
      opt['description']?.dispose();
      opt['price']?.dispose();
    }
    super.dispose();
  }

  void _addOption() {
    setState(() {
      _options.add({
        'description': TextEditingController(),
        'price': TextEditingController(),
      });
    });
  }

  void _removeOption(int index) {
    if (_options.length > 1) {
      setState(() {
        _options[index]['description']?.dispose();
        _options[index]['price']?.dispose();
        _options.removeAt(index);
      });
    }
  }

  Future<void> _updateStatus(String newStatus, {bool isAwaitingApproval = false}) async {
    setState(() => _isLoading = true);
    try {
      Map<String, dynamic> updateData = {
        'status': newStatus,
        'has_unread_update': true,
      };

      if (isAwaitingApproval) {
        bool isValid = true;
        List<Map<String, dynamic>> optionsData = [];

        for (var opt in _options) {
          String desc = opt['description']!.text.trim();
          String price = opt['price']!.text.trim();
          if (desc.isEmpty || price.isEmpty) {
            isValid = false;
            break;
          }
          optionsData.add({'description': desc, 'price': price});
        }

        if (!isValid) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Заполните все описания и цены в добавленных вариантах')),
          );
          setState(() => _isLoading = false);
          return;
        }

        updateData['options'] = optionsData;
      }

      await FirebaseFirestore.instance.collection('orders').doc(widget.orderId).update(updateData);

      if (isAwaitingApproval) {
        String? phone = widget.orderData['phone'];
        if (phone != null) {
          var clientDoc = await FirebaseFirestore.instance.collection('clients').doc(phone).get();
          if (clientDoc.exists && clientDoc.data() != null) {
            String? fcmToken = clientDoc.data()!['fcm_token'];
            if (fcmToken != null) {
              await FCMService.sendPushNotification(
                token: fcmToken,
                title: 'Заказ ожидает согласования',
                body: 'Мастер предложил варианты ремонта. Выберите подходящий.',
              );
            }
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Отправлено на согласование')));
      } else if (newStatus == 'completed') {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ремонт завершен')));
      } else if (newStatus == 'canceled') {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Заказ отозван')));
      }

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildAuditTrail(Map<String, dynamic> data) {
    final options = data.containsKey('options') ? data['options'] as List<dynamic> : null;
    final selectedIndex = data.containsKey('selected_option_index') ? data['selected_option_index'] as int? : null;

    if (options != null && selectedIndex != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          const Text(
            'История согласования вариантов:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ...options.asMap().entries.map((entry) {
            int idx = entry.key;
            var opt = entry.value;
            bool isSelected = idx == selectedIndex;

            return Card(
              color: isSelected ? Colors.green.shade50 : Colors.grey.shade50,
              elevation: isSelected ? 2 : 0,
              shape: RoundedRectangleBorder(
                side: BorderSide(
                  color: isSelected ? Colors.green : Colors.grey.shade300,
                  width: isSelected ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListTile(
                leading: Icon(
                  isSelected ? Icons.check_circle : Icons.close,
                  color: isSelected ? Colors.green : Colors.grey.shade400,
                  size: 32,
                ),
                title: Text(
                  opt['description'] ?? '',
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? Colors.black87 : Colors.grey.shade600,
                  ),
                ),
                subtitle: Text(
                  '${opt['price']} руб.',
                  style: TextStyle(
                    color: isSelected ? Colors.green.shade700 : Colors.grey.shade500,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 16,
                  ),
                ),
                trailing: isSelected
                    ? const Text(
                        'ВЫБРАНО КЛИЕНТОМ ✅',
                        style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12),
                      )
                    : null,
              ),
            );
          }),
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Text(
            'Диагноз/Комментарий: ${data['admin_comment'] ?? 'Нет'}',
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'Стоимость: ${data['price'] ?? 'Не указана'} руб.',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    String status = widget.orderData['status'] ?? 'unknown';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Детали заказа'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    elevation: 3,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Клиент: ${widget.orderData['client_name'] ?? 'Без имени'}',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Телефон: ${widget.orderData['phone'] ?? 'Не указан'}',
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Техника: ${widget.orderData['device_type'] ?? 'Не указана'}',
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Проблема: ${widget.orderData['problem'] ?? 'Не указана'}',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  if (status == 'new') ...[
                    const Text(
                      'Варианты ремонта (для клиента):',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _options.length,
                      itemBuilder: (context, index) {
                        return Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Вариант ${index + 1}',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    if (_options.length > 1)
                                      IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.red),
                                        onPressed: () => _removeOption(index),
                                      ),
                                  ],
                                ),
                                TextField(
                                  controller: _options[index]['description'],
                                  decoration: const InputDecoration(
                                    labelText: 'Описание варианта',
                                    border: OutlineInputBorder(),
                                  ),
                                  maxLines: 2,
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _options[index]['price'],
                                  decoration: const InputDecoration(
                                    labelText: 'Цена (руб.)',
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType: TextInputType.number,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    TextButton.icon(
                      onPressed: _addOption,
                      icon: const Icon(Icons.add),
                      label: const Text('Добавить вариант'),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => _updateStatus('awaiting_approval', isAwaitingApproval: true),
                      child: const Text('Отправить на согласование', style: TextStyle(fontSize: 16)),
                    ),
                  ],

                  if (status == 'awaiting_approval') ...[
                    const Text(
                      'Ожидаем ответа от клиента',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange),
                    ),
                    const SizedBox(height: 16),
                    if (widget.orderData.containsKey('options')) ...[
                      const Text(
                        'Были предложены варианты:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      ...(widget.orderData['options'] as List<dynamic>).map((opt) {
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(opt['description'] ?? ''),
                            subtitle: Text(
                              '${opt['price']} руб.',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            leading: const Icon(Icons.help_outline, color: Colors.orange),
                          ),
                        );
                      }),
                    ] else ...[
                      Text(
                        'Диагноз/Комментарий: ${widget.orderData['admin_comment'] ?? 'Нет'}',
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Стоимость: ${widget.orderData['price'] ?? 'Не указана'} руб.',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                    const SizedBox(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.all(16),
                      ),
                      onPressed: () => _updateStatus('canceled'),
                      child: const Text('Отозвать заказ', style: TextStyle(fontSize: 16, color: Colors.white)),
                    ),
                  ],

                  if (status == 'in_progress') ...[
                    const Text(
                      'Клиент согласен. В работе!',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                    ),
                    _buildAuditTrail(widget.orderData),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        padding: const EdgeInsets.all(16),
                      ),
                      onPressed: () => _updateStatus('completed'),
                      child: const Text('Завершить ремонт', style: TextStyle(fontSize: 16, color: Colors.white)),
                    ),
                  ],

                  if (status == 'completed') ...[
                    const Text(
                      'Ремонт успешно завершен 🎉',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal),
                    ),
                    _buildAuditTrail(widget.orderData),
                  ],

                  if (status == 'canceled') ...[
                    const Text(
                      'Заказ отменен',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red),
                    ),
                    const SizedBox(height: 16),
                    if (widget.orderData.containsKey('options')) ...[
                      const Text(
                        'Были предложены варианты:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      ...(widget.orderData['options'] as List<dynamic>).map((opt) {
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(
                              opt['description'] ?? '',
                              style: const TextStyle(color: Colors.grey),
                            ),
                            subtitle: Text(
                              '${opt['price']} руб.',
                              style: const TextStyle(color: Colors.grey),
                            ),
                            leading: const Icon(Icons.close, color: Colors.grey),
                          ),
                        );
                      }),
                    ]
                  ],
                ],
              ),
            ),
    );
  }
}

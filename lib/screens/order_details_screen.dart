import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mservice_crm/services/fcm_service.dart';

class OrderDetailsScreen extends StatefulWidget {
  final String orderId;
  final Map<String, dynamic> orderData;

  const OrderDetailsScreen({
    Key? key,
    required this.orderId,
    required this.orderData,
  }) : super(key: key);

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

  Future<void> _updateStatus(String newStatus, {bool sendingOptions = false}) async {
    try {
      Map<String, dynamic> updateData = {
        'status': newStatus,
        'has_unread_update': true,
      };

      if (sendingOptions) {
        for (var opt in _options) {
          if (opt['description']!.text.trim().isEmpty || opt['price']!.text.trim().isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Пожалуйста, заполните описания и цены для всех вариантов!'),
                backgroundColor: Colors.red,
              ),
            );
            return;
          }
        }

        List<Map<String, dynamic>> optionsData = _options.map((opt) => {
          'description': opt['description']!.text.trim(),
          'price': opt['price']!.text.trim(),
        }).toList();

        updateData['options'] = optionsData;
      }

      await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .update(updateData);

      if (sendingOptions) {
        try {
          final clientDoc = await FirebaseFirestore.instance
              .collection('clients')
              .doc(widget.orderData['phone'])
              .get();

          if (clientDoc.exists) {
            final fcmToken = clientDoc.data()?['fcm_token'];
            if (fcmToken != null) {
              await FCMService.sendPushNotification(
                token: fcmToken,
                title: 'Заказ ожидает согласования',
                body: 'Мастер предложил варианты ремонта. Выберите подходящий.',
              );
            }
          }
        } catch (e) {
          debugPrint('Ошибка отправки Push-уведомления: $e');
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Статус заказа успешно обновлен на: $newStatus')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка обновления: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.orderData['status'] ?? 'new';
    
    // Обратная совместимость и новые поля
    final legacyComment = widget.orderData['admin_comment'];
    final legacyPrice = widget.orderData['price']?.toString();
    final optionsList = widget.orderData['options'] as List<dynamic>?;
    
    final selectedDesc = widget.orderData['selected_description'] ?? legacyComment;
    final selectedPrice = widget.orderData['selected_price']?.toString() ?? legacyPrice;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Детали заказа'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Клиент: ${widget.orderData['client_name'] ?? 'Без имени'}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('Телефон: ${widget.orderData['phone'] ?? 'Нет номера'}',
                        style: const TextStyle(fontSize: 16)),
                    const SizedBox(height: 8),
                    Text('Техника: ${widget.orderData['device_type'] ?? 'Не указана'}',
                        style: const TextStyle(fontSize: 16, color: Colors.teal)),
                    const Divider(height: 24),
                    const Text('Проблема:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(widget.orderData['problem'] ?? 'Описание отсутствует',
                        style: const TextStyle(fontSize: 16)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // UI для статуса 'new'
            if (status == 'new') ...[
              const Text('Варианты ремонта:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ..._options.asMap().entries.map((entry) {
                int index = entry.key;
                Map<String, TextEditingController> opt = entry.value;
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Вариант ${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
                            if (_options.length > 1)
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                onPressed: () => _removeOption(index),
                                tooltip: 'Удалить вариант',
                              ),
                          ],
                        ),
                        TextField(
                          controller: opt['description'],
                          decoration: const InputDecoration(
                            labelText: 'Описание решения',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: opt['price'],
                          decoration: const InputDecoration(
                            labelText: 'Стоимость (руб.)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.attach_money),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
              
              OutlinedButton.icon(
                onPressed: _addOption,
                icon: const Icon(Icons.add),
                label: const Text('Добавить вариант'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  foregroundColor: Colors.teal,
                  side: const BorderSide(color: Colors.teal),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => _updateStatus('awaiting_approval', sendingOptions: true),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Отправить на согласование', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],

            // UI для статуса 'awaiting_approval'
            if (status == 'awaiting_approval') ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.access_time, color: Colors.orange),
                        SizedBox(width: 8),
                        Text('Ожидаем ответа от клиента', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orange)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (optionsList != null && optionsList.isNotEmpty) ...[
                      const Text('Предложенные варианты:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      ...optionsList.map((opt) => Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Text('• ${opt['description']} — ${opt['price']} руб.'),
                      )).toList(),
                    ] else ...[
                      // Для старых заказов без массива options
                      Text('Диагноз: ${legacyComment ?? 'Нет'}'),
                      Text('Предложенная цена: ${legacyPrice ?? '0'} руб.', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ]
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => _updateStatus('canceled'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Отозвать заказ (Отменить)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],

            // UI для статуса 'in_progress'
            if (status == 'in_progress') ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.build, color: Colors.blue),
                        SizedBox(width: 8),
                        Text('Клиент согласен. В работе!', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text('Выбранный вариант: ${selectedDesc ?? 'Не указан'}'),
                    const SizedBox(height: 4),
                    Text('Утвержденная стоимость: ${selectedPrice ?? '0'} руб.', 
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => _updateStatus('completed'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Завершить ремонт', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],

            // UI для статуса 'completed'
            if (status == 'completed') ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 48),
                    const SizedBox(height: 8),
                    const Text('Ремонт успешно завершен', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
                    const SizedBox(height: 8),
                    Text('Итоговая стоимость: ${selectedPrice ?? '0'} руб.', style: const TextStyle(fontSize: 16)),
                  ],
                ),
              ),
            ],

            // UI для статуса 'canceled'
            if (status == 'canceled') ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.cancel, color: Colors.red, size: 48),
                    SizedBox(height: 8),
                    Text('Заказ отменен', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

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
            const SnackBar(content: Text('Заполните все описания и цены в добавленных вариантах'), backgroundColor: Colors.red),
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Отправлено на согласование'), backgroundColor: Colors.green));
      } else if (newStatus == 'completed') {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ремонт завершен'), backgroundColor: Colors.green));
      } else if (newStatus == 'canceled') {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Заказ отозван')));
      }

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red));
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
          const Text('История согласования вариантов:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
          const SizedBox(height: 12),
          ...options.asMap().entries.map((entry) {
            int idx = entry.key;
            var opt = entry.value;
            bool isSelected = idx == selectedIndex;

            return Card(
              color: isSelected ? Colors.green.shade50 : Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                side: BorderSide(color: isSelected ? Colors.green : Colors.grey.shade300, width: isSelected ? 2 : 1),
                borderRadius: BorderRadius.circular(8),
              ),
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(
                  isSelected ? Icons.check_circle : Icons.cancel_outlined,
                  color: isSelected ? Colors.green[600] : Colors.grey[400],
                  size: 28,
                ),
                title: Text(
                  opt['description'] ?? '',
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? Colors.black87 : Colors.grey[500],
                    decoration: isSelected ? TextDecoration.none : TextDecoration.lineThrough,
                  ),
                ),
                subtitle: Text(
                  '${opt['price']} TMT',
                  style: TextStyle(
                    color: isSelected ? Colors.green[700] : Colors.grey[500],
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 16,
                  ),
                ),
                trailing: isSelected ? const Text('ВЫБРАНО ✅', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)) : null,
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
          Text('Диагноз/Комментарий: ${data['admin_comment'] ?? 'Нет'}', style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 8),
          Text('Стоимость: ${data['price'] ?? 'Не указана'} TMT', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
        ],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    String status = widget.orderData['status'] ?? 'unknown';

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.blueGrey[900],
        foregroundColor: Colors.white,
        title: const Text('Детали заказа', style: TextStyle(fontSize: 18)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // --- КАРТОЧКА КЛИЕНТА ---
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.person, color: Colors.blueGrey[400]),
                              const SizedBox(width: 8),
                              Text('${widget.orderData['client_name'] ?? 'Без имени'}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                            ],
                          ),
                          const Divider(height: 24),
                          Row(
                            children: [
                              const Icon(Icons.phone, size: 18, color: Colors.grey),
                              const SizedBox(width: 8),
                              Text('${widget.orderData['phone'] ?? 'Не указан'}', style: const TextStyle(fontSize: 16)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Icon(Icons.devices, size: 18, color: Colors.grey),
                              const SizedBox(width: 8),
                              Text('${widget.orderData['device_type'] ?? 'Не указана'}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.orange[200]!)),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.warning_amber_rounded, color: Colors.deepOrange, size: 20),
                                const SizedBox(width: 8),
                                Expanded(child: Text('${widget.orderData['problem'] ?? 'Не указана'}', style: const TextStyle(fontSize: 15, color: Colors.black87))),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // --- ЭКРАН НОВОГО ЗАКАЗА (ОЦЕНКА) ---
                  if (status == 'new') ...[
                    const Text('Оценка ремонта (Варианты для клиента):', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                    const SizedBox(height: 12),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _options.length,
                      itemBuilder: (context, index) {
                        return Card(
                          elevation: 1,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey[300]!)),
                          margin: const EdgeInsets.only(bottom: 16),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Вариант ${index + 1}', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey[800])),
                                    if (_options.length > 1)
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                                        onPressed: () => _removeOption(index),
                                        tooltip: 'Удалить вариант',
                                      ),
                                  ],
                                ),
                                TextField(
                                  controller: _options[index]['description'],
                                  decoration: InputDecoration(
                                    labelText: 'Диагноз / Что делаем',
                                    filled: true,
                                    fillColor: Colors.grey[100],
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                  ),
                                  maxLines: 2,
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _options[index]['price'],
                                  decoration: InputDecoration(
                                    labelText: 'Цена (TMT)',
                                    prefixIcon: const Icon(Icons.payments_outlined, color: Colors.green),
                                    filled: true,
                                    fillColor: Colors.grey[100],
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                  ),
                                  keyboardType: TextInputType.number,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: Colors.blueGrey[400]!),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _addOption,
                      icon: const Icon(Icons.add_circle_outline),
                      label: const Text('ДОБАВИТЬ ЕЩЕ ВАРИАНТ', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.orange[600],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => _updateStatus('awaiting_approval', isAwaitingApproval: true),
                      icon: const Icon(Icons.send),
                      label: const Text('ОТПРАВИТЬ КЛИЕНТУ НА ВЫБОР', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ],

                  // --- ЭКРАН ОЖИДАНИЯ КЛИЕНТА ---
                  if (status == 'awaiting_approval') ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.orange[100], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orange[300]!)),
                      child: Row(
                        children: [
                          const Icon(Icons.hourglass_bottom, color: Colors.deepOrange, size: 28),
                          const SizedBox(width: 12),
                          const Expanded(child: Text('Ожидаем решения клиента по предложенным вариантам', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange, fontSize: 16))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (widget.orderData.containsKey('options')) ...[
                      const Text('Предложенные варианты:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueGrey)),
                      const SizedBox(height: 12),
                      ...(widget.orderData['options'] as List<dynamic>).map((opt) {
                        return Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey[300]!)),
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(opt['description'] ?? ''),
                            subtitle: Text('${opt['price']} TMT', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                            leading: const Icon(Icons.help_outline, color: Colors.orange),
                          ),
                        );
                      }),
                    ],
                    const SizedBox(height: 24),
                    TextButton.icon(
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      onPressed: () => _updateStatus('canceled'),
                      icon: const Icon(Icons.cancel),
                      label: const Text('Принудительно отозвать заказ'),
                    ),
                  ],

                  // --- ЭКРАН В РАБОТЕ ---
                  if (status == 'in_progress') ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blue[200]!)),
                      child: Row(
                        children: [
                          const Icon(Icons.handyman, color: Colors.blue, size: 28),
                          const SizedBox(width: 12),
                          const Expanded(child: Text('Клиент дал согласие. Заказ в процессе ремонта.', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 16))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildAuditTrail(widget.orderData),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[600],
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => _updateStatus('completed'),
                      icon: const Icon(Icons.task_alt, color: Colors.white),
                      label: const Text('РЕМОНТ ЗАВЕРШЕН (ГОТОВО К ВЫДАЧИ)', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ],

                  // --- ЭКРАН ЗАВЕРШЕН ---
                  if (status == 'completed') ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green[300]!)),
                      child: Row(
                        children: [
                          const Icon(Icons.celebration, color: Colors.green, size: 28),
                          const SizedBox(width: 12),
                          const Expanded(child: Text('Ремонт успешно завершен и выдан клиенту!', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 16))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildAuditTrail(widget.orderData),
                  ],

                  // --- ЭКРАН ОТМЕНЕН ---
                  if (status == 'canceled') ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red[300]!)),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red, size: 28),
                          const SizedBox(width: 12),
                          const Expanded(child: Text('Заказ отменен (клиентом или администратором)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 16))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (widget.orderData.containsKey('options')) ...[
                      const Text('Были предложены варианты:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueGrey)),
                      const SizedBox(height: 8),
                      ...(widget.orderData['options'] as List<dynamic>).map((opt) {
                        return Card(
                          elevation: 0,
                          color: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey[200]!)),
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(opt['description'] ?? '', style: const TextStyle(color: Colors.grey, decoration: TextDecoration.lineThrough)),
                            subtitle: Text('${opt['price']} TMT', style: const TextStyle(color: Colors.grey)),
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


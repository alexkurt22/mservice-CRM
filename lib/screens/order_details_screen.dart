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
  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();

  Future<void> _updateStatus(String newStatus, {String? adminComment, String? price}) async {
    try {
      final updateData = <String, dynamic>{
        'status': newStatus,
        'has_unread_update': true,
      };

      if (adminComment != null) updateData['admin_comment'] = adminComment;
      if (price != null) updateData['price'] = price;

      await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .update(updateData);

      // --- НАЧАЛО БЛОКА УВЕДОМЛЕНИЙ ---
      if (newStatus == 'awaiting_approval') {
        final String? phone = widget.orderData['phone'];
        if (phone != null) {
          final clientDoc = await FirebaseFirestore.instance.collection('clients').doc(phone).get();
              
          if (clientDoc.exists) {
            final String? fcmToken = clientDoc.data()?['fcm_token'];
            if (fcmToken != null) {
              // Токен есть, пробуем отправить!
              await FCMService.sendPushNotification(
                token: fcmToken,
                title: 'Заказ ожидает согласования',
                body: 'Мы провели диагностику. Пожалуйста, проверьте цену и подтвердите ремонт.',
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('УСПЕХ: Пуш отправлен клиенту!'), backgroundColor: Colors.green),
                );
              }
            } else {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('ОШИБКА: У клиента нет fcm_token в базе'), backgroundColor: Colors.orange),
                );
              }
            }
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('ОШИБКА: Клиент $phone не найден в БД'), backgroundColor: Colors.orange),
              );
            }
          }
        }
      }
      // --- КОНЕЦ БЛОКА УВЕДОМЛЕНИЙ ---

      if (mounted && newStatus != 'awaiting_approval') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Статус заказа успешно обновлен')),
        );
      }
      
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('СИСТЕМНАЯ ОШИБКА: $e'), backgroundColor: Colors.red, duration: const Duration(seconds: 5)),
        );
      }
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.orderData['status'] ?? 'new';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Детали заказа'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Имя: ${widget.orderData['client_name'] ?? 'Не указано'}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    Text('Телефон: ${widget.orderData['phone'] ?? 'Не указано'}', style: const TextStyle(fontSize: 16)),
                    const SizedBox(height: 8),
                    Text('Техника: ${widget.orderData['device_type'] ?? 'Не указано'}', style: const TextStyle(fontSize: 16)),
                    const SizedBox(height: 8),
                    Text('Проблема: ${widget.orderData['problem'] ?? 'Не указано'}', style: const TextStyle(fontSize: 16)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (status == 'new') ...[
              TextField(
                controller: _commentController,
                decoration: const InputDecoration(
                  labelText: 'Диагноз / Комментарий мастера',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _priceController,
                decoration: const InputDecoration(
                  labelText: 'Предварительная стоимость',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (_commentController.text.isNotEmpty && _priceController.text.isNotEmpty) {
                      _updateStatus(
                        'awaiting_approval',
                        adminComment: _commentController.text,
                        price: _priceController.text,
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Заполните все поля')),
                      );
                    }
                  },
                  child: const Text('Отправить на согласование'),
                ),
              ),
            ] else if (status == 'awaiting_approval') ...[
              const Text('Ожидаем ответа от клиента', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange)),
              const SizedBox(height: 16),
              Text('Комментарий мастера: ${widget.orderData['admin_comment'] ?? ''}'),
              const SizedBox(height: 8),
              Text('Стоимость: ${widget.orderData['price'] ?? ''} руб.'),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: () => _updateStatus('canceled'),
                  child: const Text('Отозвать заказ', style: TextStyle(color: Colors.white)),
                ),
              ),
            ] else if (status == 'in_progress') ...[
              const Text('Клиент согласен. В работе!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _updateStatus('completed'),
                  child: const Text('Завершить ремонт'),
                ),
              ),
            ] else if (status == 'completed') ...[
              const Text('Ремонт успешно завершен', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
              const SizedBox(height: 16),
              Text('Итоговая стоимость: ${widget.orderData['price'] ?? ''} руб.', style: const TextStyle(fontSize: 16)),
            ] else if (status == 'canceled') ...[
              const Text('Заказ отменен', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red)),
            ],
          ],
        ),
      ),
    );
  }
}

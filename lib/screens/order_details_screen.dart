import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _sendForApproval() async {
    final comment = _commentController.text.trim();
    final price = _priceController.text.trim();

    if (comment.isEmpty || price.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заполните все поля')),
      );
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .update({
        'status': 'awaiting_approval',
        'admin_comment': comment,
        'price': price,
        'has_unread_update': true,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Заказ отправлен на согласование')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    }
  }

  void _cancelOrder() async {
    try {
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .update({
        'status': 'canceled',
        'has_unread_update': true,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Заказ отозван')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    }
  }

  void _completeOrder() async {
    try {
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .update({
        'status': 'completed',
        'has_unread_update': true,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ремонт завершен')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.orderData;
    final status = data['status'] ?? 'new';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Детали заказа'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Имя: ${data['client_name'] ?? 'Не указано'}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text('Телефон: ${data['phone'] ?? 'Не указан'}'),
                    const SizedBox(height: 8),
                    Text('Техника: ${data['device_type'] ?? 'Не указана'}'),
                    const SizedBox(height: 8),
                    Text('Проблема: ${data['problem'] ?? 'Не указана'}'),
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
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _sendForApproval,
                child: const Text('Отправить на согласование'),
              ),
            ] else if (status == 'awaiting_approval') ...[
              Card(
                color: Colors.orange.shade100,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Text(
                        'Ожидаем ответа от клиента',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Text('Диагноз: ${data['admin_comment'] ?? ''}'),
                      Text('Стоимость: ${data['price'] ?? ''}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _cancelOrder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Отозвать заказ'),
              ),
            ] else if (status == 'in_progress') ...[
              Card(
                color: Colors.green.shade100,
                child: const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Клиент согласен. В работе!',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _completeOrder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Завершить ремонт'),
              ),
            ] else if (status == 'completed') ...[
              Card(
                color: Colors.green.shade100,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Text(
                        'Ремонт успешно завершен',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('Итоговая цена: ${data['price'] ?? ''}'),
                    ],
                  ),
                ),
              ),
            ] else if (status == 'canceled') ...[
              Card(
                color: Colors.red.shade100,
                child: const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Заказ отменен',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

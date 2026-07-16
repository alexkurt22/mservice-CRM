import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OfflineOrderScreen extends StatefulWidget {
  const OfflineOrderScreen({super.key});

  @override
  State<OfflineOrderScreen> createState() => _OfflineOrderScreenState();
}

class _OfflineOrderScreenState extends State<OfflineOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _deviceController = TextEditingController();
  final TextEditingController _issueController = TextEditingController();
  final TextEditingController _otherSourceController = TextEditingController();

  // Вот наши варианты! Если нужно изменить названия, меняй их прямо тут в списке:
  final List<String> _sources = ['Instagram', 'TikTok', 'От друзей/знакомых', 'Другое'];
  String _selectedSource = 'Instagram';
  bool _isLoading = false;

  Future<void> _submitOrder() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    // Если выбрано "Другое", берем текст из поля ввода
    String finalSource = _selectedSource == 'Другое' 
        ? _otherSourceController.text.trim() 
        : _selectedSource;

    try {
      // 1. Создаем сам заказ
      await FirebaseFirestore.instance.collection('orders').add({
        'client_name': _nameController.text.trim(),
        'client_phone': _phoneController.text.trim(),
        'device': _deviceController.text.trim(),
        'issue': _issueController.text.trim(),
        'status': 'new', // Статус "Новый", чтобы он появился на дашборде
        'created_at': FieldValue.serverTimestamp(),
        'source': finalSource,
        'is_offline': true, // Специальная метка для аналитики
      });

      // 2. Проверяем, есть ли такой клиент в базе (ищем по номеру телефона)
      final clientQuery = await FirebaseFirestore.instance
          .collection('clients')
          .where('phone', isEqualTo: _phoneController.text.trim())
          .get();
      
      // Если клиента нет, создаем "заглушку". Когда он скачает приложение, он сразу увидит свой заказ!
      if (clientQuery.docs.isEmpty) {
         await FirebaseFirestore.instance.collection('clients').add({
            'name': _nameController.text.trim(),
            'phone': _phoneController.text.trim(),
            'is_approved': true, // Одобряем заранее
            'created_at': FieldValue.serverTimestamp(),
            'source': finalSource,
            'is_offline_stub': true, // Метка, что аккаунт создан админом
         });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Оффлайн-заказ успешно создан!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context); // Возвращаемся на Дашборд
      }
    } catch (e) {
       if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
          );
       }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.blueGrey[900],
        foregroundColor: Colors.white,
        title: const Text('Новый оффлайн-заказ', style: TextStyle(fontSize: 18)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 16.0,
                right: 16.0,
                top: 16.0,
                bottom: MediaQuery.of(context).padding.bottom + 24.0, // Защита от кнопок
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'ДАННЫЕ КЛИЕНТА',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 1.2),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Имя клиента',
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      validator: (val) => val == null || val.isEmpty ? 'Введите имя' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Номер телефона (с кодом)',
                        prefixIcon: Icon(Icons.phone),
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      validator: (val) => val == null || val.isEmpty ? 'Введите телефон' : null,
                    ),
                    
                    const SizedBox(height: 32),
                    const Text(
                      'ДЕТАЛИ ЗАКАЗА',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 1.2),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _deviceController,
                      decoration: const InputDecoration(
                        labelText: 'Устройство (например: Ноутбук Asus)',
                        prefixIcon: Icon(Icons.computer),
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      validator: (val) => val == null || val.isEmpty ? 'Введите устройство' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _issueController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Описание поломки / Заявка',
                        alignLabelWithHint: true,
                        prefixIcon: Padding(
                          padding: EdgeInsets.only(bottom: 32.0),
                          child: Icon(Icons.build),
                        ),
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      validator: (val) => val == null || val.isEmpty ? 'Введите описание поломки' : null,
                    ),

                    const SizedBox(height: 32),
                    const Text(
                      'МАРКЕТИНГ',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 1.2),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _selectedSource,
                      decoration: const InputDecoration(
                        labelText: 'Откуда узнали о нас?',
                        prefixIcon: Icon(Icons.campaign),
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      items: _sources.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                      onChanged: (val) => setState(() => _selectedSource = val!),
                    ),
                    
                    // Это поле появляется только если выбрано "Другое"
                    if (_selectedSource == 'Другое') ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _otherSourceController,
                        decoration: const InputDecoration(
                          labelText: 'Укажите источник вручную',
                          prefixIcon: Icon(Icons.edit),
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        validator: (val) => val == null || val.isEmpty ? 'Пожалуйста, укажите источник' : null,
                      ),
                    ],

                    const SizedBox(height: 40),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueGrey[900],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _submitOrder,
                      child: const Text('Создать заказ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}


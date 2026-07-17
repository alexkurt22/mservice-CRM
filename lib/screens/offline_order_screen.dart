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
  final TextEditingController _issueController = TextEditingController();
  final TextEditingController _otherSourceController = TextEditingController();

  final List<String> _sources = ['Instagram', 'TikTok', 'От друзей/знакомых', 'Другое'];
  String _selectedSource = 'Instagram';

  // --- ДИНАМИЧЕСКИЕ КАТЕГОРИИ ---
  List<String> _deviceTypes = []; 
  String? _selectedDeviceType; 
  bool _isLoadingCategories = true; // Загрузка списка категорий из базы
  bool _isLoading = false; // Загрузка отправки заказа

  @override
  void initState() {
    super.initState();
    _loadCategories(); // При открытии экрана сразу скачиваем список
  }

  // Функция скачивания списка категорий
  Future<void> _loadCategories() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('settings').doc('categories').get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        if (data['devices'] != null && (data['devices'] as List).isNotEmpty) {
          if (mounted) {
            setState(() {
              _deviceTypes = List<String>.from(data['devices']);
              _isLoadingCategories = false;
            });
          }
          return;
        }
      }
    } catch (e) {
      debugPrint('Ошибка загрузки категорий: $e');
    }
    
    // Подстраховка: если база пустая или нет интернета, даем базовый список
    if (mounted) {
      setState(() {
        _deviceTypes = ['Смартфон', 'Ноутбук', 'Компьютер (ПК)', 'Другое'];
        _isLoadingCategories = false;
      });
    }
  }

  Future<void> _submitOrder() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    String finalPhone = '+993${_phoneController.text.trim()}';
    String finalSource = _selectedSource == 'Другое' 
        ? _otherSourceController.text.trim() 
        : _selectedSource;

    try {
      await FirebaseFirestore.instance.collection('orders').add({
        'client_name': _nameController.text.trim(),
        'phone': finalPhone, 
        'device_type': _selectedDeviceType, 
        'problem': _issueController.text.trim(), 
        'status': 'new', 
        'created_at': FieldValue.serverTimestamp(),
        'source': finalSource,
        'is_offline': true, 
      });

      final clientQuery = await FirebaseFirestore.instance
          .collection('clients')
          .where('phone', isEqualTo: finalPhone)
          .get();
      
      if (clientQuery.docs.isEmpty) {
         await FirebaseFirestore.instance.collection('clients').add({
            'name': _nameController.text.trim(),
            'phone': finalPhone,
            'is_approved': true, 
            'created_at': FieldValue.serverTimestamp(),
            'source': finalSource,
            'is_offline_stub': true, 
         });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Оффлайн-заказ успешно создан!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context); 
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
      // Крутилка загрузки будет крутиться либо пока отправляется заказ, либо пока скачиваются категории
      body: _isLoading || _isLoadingCategories
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 16.0,
                right: 16.0,
                top: 16.0,
                bottom: MediaQuery.of(context).padding.bottom + 24.0, 
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
                      keyboardType: TextInputType.number,
                      maxLength: 8,
                      decoration: const InputDecoration(
                        labelText: 'Номер телефона',
                        prefixText: '+993 ', 
                        prefixStyle: TextStyle(fontSize: 16, color: Colors.black87, fontWeight: FontWeight.bold),
                        prefixIcon: Icon(Icons.phone),
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                        counterText: "", 
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) return 'Введите номер телефона';
                        if (val.length != 8) return 'Введите ровно 8 цифр (без +993)';
                        if (int.tryParse(val) == null) return 'Допускаются только цифры';
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 32),
                    const Text(
                      'ДЕТАЛИ ЗАКАЗА',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 1.2),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _selectedDeviceType,
                      decoration: const InputDecoration(
                        labelText: 'Тип устройства / Категория',
                        prefixIcon: Icon(Icons.devices),
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      hint: const Text('Выберите устройство'),
                      items: _deviceTypes.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                      onChanged: (val) => setState(() => _selectedDeviceType = val),
                      validator: (val) => val == null ? 'Пожалуйста, выберите тип устройства' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _issueController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Описание поломки',
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

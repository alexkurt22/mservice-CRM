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

  // --- ДИНАМИЧЕСКИЕ КАТЕГОРИИ (АРХИТЕКТУРА СУПЕР-ПРИЛОЖЕНИЯ) ---
  Map<String, List<String>> _categoriesMap = {}; // Словарь: Направление -> Список услуг
  String? _selectedDirection; // Выбранное главное направление
  String? _selectedSubCategory; // Выбранная конкретная услуга/устройство
  
  bool _isLoadingCategories = true; 
  bool _isLoading = false; 

  @override
  void initState() {
    super.initState();
    _loadCategories(); 
  }

  // Скачиваем структуру Супер-приложения из базы (categories_v2)
  Future<void> _loadCategories() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('settings').doc('categories_v2').get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        Map<String, List<String>> tempMap = {};
        
        data.forEach((key, value) {
          tempMap[key] = List<String>.from(value as List);
        });

        if (tempMap.isNotEmpty && mounted) {
          setState(() {
            _categoriesMap = tempMap;
            _isLoadingCategories = false;
          });
          return;
        }
      }
    } catch (e) {
      debugPrint('Ошибка загрузки категорий: $e');
    }
    
    // Подстраховка на случай отсутствия интернета или пустой базы
    if (mounted) {
      setState(() {
        _categoriesMap = {
          'Компьютерный сервис': ['Смартфон', 'Ноутбук', 'Компьютер (ПК)'],
          'Автосервис': ['Двигатель', 'Ходовая'],
        };
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
      // Сохраняем в заказ и Глобальное направление, и конкретную Услугу!
      await FirebaseFirestore.instance.collection('orders').add({
        'client_name': _nameController.text.trim(),
        'phone': finalPhone, 
        'category': _selectedDirection, // Глобальное направление (напр. Автосервис)
        'device_type': _selectedSubCategory, // Конкретная услуга/устройство (напр. Двигатель)
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
                    // --- УМНОЕ ПОЛЕ ТЕЛЕФОНА С ПРОВЕРКОЙ КОДА ОПЕРАТОРА ---
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
                        
                        // Строгая проверка кодов Туркменистана
                        final validCodes = ['60', '61', '62', '63', '64', '65', '71', '72'];
                        final code = val.substring(0, 2);
                        if (!validCodes.contains(code)) {
                          return 'Неверный код оператора (доступны: 60-65, 71,72)';
                        }
                        
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 32),
                    const Text(
                      'ДЕТАЛИ ЗАКАЗА',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 1.2),
                    ),
                    const SizedBox(height: 12),
                    // --- ВЫПАДАЮЩИЙ СПИСОК 1: ГЛОБАЛЬНОЕ НАПРАВЛЕНИЕ ---
                    DropdownButtonFormField<String>(
                      value: _selectedDirection,
                      decoration: const InputDecoration(
                        labelText: 'Глобальное направление',
                        prefixIcon: Icon(Icons.business_center),
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      hint: const Text('Напр.: Автосервис'),
                      items: _categoriesMap.keys.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedDirection = val;
                          _selectedSubCategory = null; // Сбрасываем подкатегорию при смене направления
                        });
                      },
                      validator: (val) => val == null ? 'Пожалуйста, выберите направление' : null,
                    ),
                    const SizedBox(height: 16),
                    
                    // --- ВЫПАДАЮЩИЙ СПИСОК 2: ПОДКАТЕГОРИЯ / УСЛУГА ---
                    DropdownButtonFormField<String>(
                      value: _selectedSubCategory,
                      decoration: InputDecoration(
                        labelText: 'Услуга / Устройство',
                        prefixIcon: const Icon(Icons.devices),
                        border: const OutlineInputBorder(),
                        filled: true,
                        fillColor: _selectedDirection == null ? Colors.grey[200] : Colors.white, // Серое, если заблокировано
                      ),
                      hint: const Text('Сначала выберите направление'),
                      items: (_selectedDirection != null ? _categoriesMap[_selectedDirection]! : [])
                          .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                          .toList(),
                      // Блокируем, пока не выбрано первое поле
                      onChanged: _selectedDirection == null ? null : (val) => setState(() => _selectedSubCategory = val),
                      validator: (val) => val == null ? 'Пожалуйста, выберите услугу' : null,
                    ),
                    const SizedBox(height: 16),
                    
                    TextFormField(
                      controller: _issueController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Дополнительное описание',
                        alignLabelWithHint: true,
                        prefixIcon: Padding(
                          padding: EdgeInsets.only(bottom: 32.0),
                          child: Icon(Icons.build),
                        ),
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      validator: (val) => val == null || val.isEmpty ? 'Введите описание поломки/услуги' : null,
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

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

  Map<String, List<String>> _categoriesMap = {}; 
  String? _selectedDirection; 
  String? _selectedSubCategory; 
  
  bool _isLoadingCategories = true; 
  bool _isLoading = false; 

  // Переменные для умного поиска клиента по номеру
  List<DocumentSnapshot> _suggestedClients = [];
  bool _isSearchingClient = false;
  bool _isClientSelectedFromDb = false;

  @override
  void initState() {
    super.initState();
    _loadCategories(); 
  }

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

  // Поиск клиентов по базе на лету при вводе телефона
  Future<void> _onPhoneChanged(String value) async {
    if (_isClientSelectedFromDb) return; // Если клиент уже выбран из базы, не ищем заново

    final cleanVal = value.trim();
    if (cleanVal.length < 3) {
      setState(() => _suggestedClients = []);
      return;
    }

    setState(() => _isSearchingClient = true);

    try {
      // Ищем совпадения по номеру телефона в коллекции clients
      final querySnapshot = await FirebaseFirestore.instance
          .collection('clients')
          .orderBy('phone')
          .startAt(['+993$cleanVal'])
          .endAt(['+993$cleanVal\uf8ff'])
          .limit(5)
          .get();

      setState(() {
        _suggestedClients = querySnapshot.docs;
        _isSearchingClient = false;
      });
    } catch (e) {
      setState(() => _isSearchingClient = false);
    }
  }

  // Выбор клиента из подсказок
  void _selectClient(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final fullPhone = data['phone'] ?? '';
    // Отрезаем префикс +993 для вывода в инпут (так как там стоит префикс)
    final shortPhone = fullPhone.startsWith('+993') ? fullPhone.substring(4) : fullPhone;

    setState(() {
      _phoneController.text = shortPhone;
      _nameController.text = data['name'] ?? '';
      _isClientSelectedFromDb = true;
      _suggestedClients = [];
    });
  }

  Future<void> _submitOrder() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    String finalPhone = '+993${_phoneController.text.trim()}';
    String finalSource = _selectedSource == 'Другое' 
        ? _otherSourceController.text.trim() 
        : _selectedSource;
    String clientName = _nameController.text.trim();

    try {
      // 1. Создаем сам заказ
      await FirebaseFirestore.instance.collection('orders').add({
        'client_name': clientName,
        'phone': finalPhone, 
        'category': _selectedDirection, 
        'device_type': _selectedSubCategory, 
        'problem': _issueController.text.trim(), 
        'status': 'new', 
        'created_at': FieldValue.serverTimestamp(),
        'source': finalSource,
        'is_offline': true, 
      });

      // 2. Проверяем, есть ли такой клиент в базе. Если нет — создаем автоматически
      final clientQuery = await FirebaseFirestore.instance
          .collection('clients')
          .where('phone', isEqualTo: finalPhone)
          .get();
      
      if (clientQuery.docs.isEmpty) {
         await FirebaseFirestore.instance.collection('clients').add({
            'name': clientName,
            'phone': finalPhone,
            'is_approved': true, 
            'is_offline': true,
            'created_at': FieldValue.serverTimestamp(),
            'source': finalSource,
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

                    // --- 1. СНАЧАЛА НОМЕР ТЕЛЕФОНА С УМНЫМ ПОИСКОМ ---
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.number,
                      maxLength: 8,
                      decoration: InputDecoration(
                        labelText: 'Номер телефона',
                        prefixText: '+993 ', 
                        prefixStyle: const TextStyle(fontSize: 16, color: Colors.black87, fontWeight: FontWeight.bold),
                        prefixIcon: const Icon(Icons.phone),
                        suffixIcon: _isClientSelectedFromDb 
                            ? IconButton(
                                icon: const Icon(Icons.clear, color: Colors.red),
                                onPressed: () {
                                  setState(() {
                                    _isClientSelectedFromDb = false;
                                    _nameController.clear();
                                    _phoneController.clear();
                                  });
                                },
                                tooltip: 'Сбросить выбор клиента',
                              )
                            : (_isSearchingClient ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2)) : null),
                        border: const OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                        counterText: "", 
                      ),
                      onChanged: _onPhoneChanged,
                      validator: (val) {
                        if (val == null || val.isEmpty) return 'Введите номер телефона';
                        if (val.length != 8) return 'Введите ровно 8 цифр (без +993)';
                        if (int.tryParse(val) == null) return 'Допускаются только цифры';
                        
                        final validCodes = ['61', '62', '63', '64', '65', '71'];
                        final code = val.substring(0, 2);
                        if (!validCodes.contains(code)) {
                          return 'Неверный код оператора (доступны: 61-65, 71)';
                        }
                        return null;
                      },
                    ),

                    // ВЫПАДАЮЩИЙ СПИСОК ПОДСКАЗОК КЛИЕНТОВ ИЗ БАЗЫ
                    if (_suggestedClients.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.blueGrey.shade200),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
                        ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _suggestedClients.length,
                          itemBuilder: (context, index) {
                            final doc = _suggestedClients[index];
                            final data = doc.data() as Map<String, dynamic>;
                            final name = data['name'] ?? 'Без имени';
                            final phone = data['phone'] ?? '';

                            return ListTile(
                              leading: const Icon(Icons.person_pin, color: Colors.blue),
                              title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(phone),
                              trailing: const Text('Выбрать', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                              onTap: () => _selectClient(doc),
                            );
                          },
                        ),
                      ),

                    const SizedBox(height: 16),

                    // --- 2. ЗАТЕМ ИМЯ КЛИЕНТА ---
                    TextFormField(
                      controller: _nameController,
                      readOnly: _isClientSelectedFromDb, // Блокируем, если выбрали из базы
                      decoration: InputDecoration(
                        labelText: _isClientSelectedFromDb ? 'Имя клиента (Из базы)' : 'Имя клиента',
                        prefixIcon: const Icon(Icons.person),
                        border: const OutlineInputBorder(),
                        filled: true,
                        fillColor: _isClientSelectedFromDb ? Colors.grey[200] : Colors.white,
                      ),
                      validator: (val) => val == null || val.isEmpty ? 'Введите имя' : null,
                    ),
                    const SizedBox(height: 32),

                    const Text(
                      'ДЕТАЛИ ЗАКАЗА',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 1.2),
                    ),
                    const SizedBox(height: 12),
                    
                    DropdownButtonFormField<String>(
                      value: _selectedDirection,
                      decoration: const InputDecoration(
                        labelText: 'Глобальное направление',
                        prefixIcon: Icon(Icons.business_center),
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      hint: const Text('Напр.: Компьютерный сервис'),
                      items: _categoriesMap.keys
                          .map<DropdownMenuItem<String>>((String d) => DropdownMenuItem<String>(value: d, child: Text(d)))
                          .toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedDirection = val;
                          _selectedSubCategory = null; 
                        });
                      },
                      validator: (val) => val == null ? 'Пожалуйста, выберите направление' : null,
                    ),
                    const SizedBox(height: 16),
                    
                    DropdownButtonFormField<String>(
                      value: _selectedSubCategory,
                      decoration: InputDecoration(
                        labelText: 'Услуга / Устройство',
                        prefixIcon: const Icon(Icons.devices),
                        border: const OutlineInputBorder(),
                        filled: true,
                        fillColor: _selectedDirection == null ? Colors.grey[200] : Colors.white, 
                      ),
                      hint: const Text('Сначала выберите направление'),
                      items: (_selectedDirection != null ? _categoriesMap[_selectedDirection]! : <String>[])
                          .map<DropdownMenuItem<String>>((String d) => DropdownMenuItem<String>(value: d, child: Text(d)))
                          .toList(),
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
                      items: _sources
                          .map<DropdownMenuItem<String>>((String s) => DropdownMenuItem<String>(value: s, child: Text(s)))
                          .toList(),
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


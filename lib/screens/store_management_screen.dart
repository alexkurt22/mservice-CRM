import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;

// --- ОТДЕЛЬНЫЙ ЭКРАН ДЛЯ СКАНЕРА (ЧТОБЫ НЕ БЫЛО ЧЕРНОГО ЭКРАНА) ---
class BarcodeScannerScreen extends StatelessWidget {
  const BarcodeScannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Наведите камеру на штрихкод'), backgroundColor: Colors.black, foregroundColor: Colors.white),
      body: MobileScanner(
        onDetect: (capture) {
          final List<Barcode> barcodes = capture.barcodes;
          if (barcodes.isNotEmpty) {
            final String? code = barcodes.first.rawValue;
            if (code != null) {
              Navigator.pop(context, code);
            }
          }
        },
      ),
    );
  }
}

class StoreManagementScreen extends StatefulWidget {
  const StoreManagementScreen({super.key});

  @override
  State<StoreManagementScreen> createState() => _StoreManagementScreenState();
}

class _StoreManagementScreenState extends State<StoreManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // =========================================================================
  // 🔐 ВСТАВЬ СВОИ КЛЮЧИ СЮДА:
  // =========================================================================
  final String _removeBgApiKey = 'uXvbPdpGGfrygCemepCx4Tg5'; 
  final String _geminiApiKey = 'AQ.Ab8RN6K7e2RvnnhmLv-rBAcTr_6r4qG9ifeiZQFWxcv4_TWPEw';
  // =========================================================================

  void _showAddProductDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    final stockController = TextEditingController(text: '1');
    final barcodeController = TextEditingController();
    final descController = TextEditingController();
    
    String condition = 'Новый'; 
    Uint8List? selectedImageBytes; // Храним байты, так как API возвращает байты
    bool isSaving = false;
    bool isProcessingImage = false;
    bool isGeneratingAI = false;

    // --- ФУНКЦИЯ МАГИЧЕСКОЙ ОБРАБОТКИ ФОТО ---
    Future<void> pickAndProcessImage(StateSetter setModalState) async {
      try {
        final picker = ImagePicker();
        final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70, maxWidth: 800);
        if (pickedFile == null) return;

        setModalState(() => isProcessingImage = true);

        // Если ключ не введен, просто сохраняем обычное фото
        if (_removeBgApiKey == 'ТВОЙ_КЛЮЧ_REMOVE_BG') {
          final bytes = await pickedFile.readAsBytes();
          setModalState(() {
            selectedImageBytes = bytes;
            isProcessingImage = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ключ Remove.bg не найден. Фото загружено без изменений.')));
          return;
        }

        // Отправляем ИИ на удаление фона и замену на белый
        var request = http.MultipartRequest('POST', Uri.parse('https://api.remove.bg/v1.0/removebg'));
        request.headers['X-Api-Key'] = _removeBgApiKey;
        request.fields['bg_color'] = 'white'; // Делаем идеальный белый фон магазина
        request.fields['size'] = 'regular'; 
        request.files.add(await http.MultipartFile.fromPath('image_file', pickedFile.path));

        var response = await request.send();
        if (response.statusCode == 200) {
          final bytes = await response.stream.toBytes();
          setModalState(() => selectedImageBytes = bytes);
        } else {
          // Если ИИ не распознал объект, оставляем оригинал
          final bytes = await pickedFile.readAsBytes();
          setModalState(() => selectedImageBytes = bytes);
          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Не удалось удалить фон. Оставлен оригинал.'), backgroundColor: Colors.orange));
        }
      } catch (e) {
        debugPrint('Ошибка обработки фото: $e');
      } finally {
        setModalState(() => isProcessingImage = false);
      }
    }

    // --- ФУНКЦИЯ ГЕНЕРАЦИИ ОПИСАНИЯ ---
    Future<void> generateDescriptionWithAI(StateSetter setModalState) async {
      if (_geminiApiKey == 'ТВОЙ_КЛЮЧ_GEMINI') {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Вставьте ключ Gemini в код!'), backgroundColor: Colors.red));
        return;
      }

      setModalState(() => isGeneratingAI = true);

      try {
        final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: _geminiApiKey);
        
        String prompt = 'Напиши красивое, короткое и продающее описание для этого товара. Укажи его преимущества для покупателя. Текст на русском языке, без воды, буквально 3-4 предложения для интернет-магазина.';
        
        if (nameController.text.trim().isNotEmpty) {
          prompt += ' Товар называется: "${nameController.text.trim()}".';
        } else {
          prompt += ' Также определи, что это за товар, и напиши его название в самом начале описания.';
        }

        List<Content> content = [];
        if (selectedImageBytes != null) {
           content.add(Content.multi([
             TextPart(prompt),
             DataPart('image/jpeg', selectedImageBytes!)
           ]));
        } else {
           content.add(Content.text(prompt));
        }
        
        final response = await model.generateContent(content);
        
        if (response.text != null) {
          setModalState(() {
            descController.text = response.text!.replaceAll(RegExp(r'\*+'), ''); // Убираем звездочки маркдауна
          });
        }
      } catch (e) {
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Сбой нейросети', style: TextStyle(color: Colors.red)),
              content: Text('Ошибка Gemini:\n\n$e'),
              actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ОК'))],
            )
          );
        }
      } finally {
        setModalState(() => isGeneratingAI = false);
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20, 
              left: 16, right: 16, top: 16
            ),
            child: FractionallySizedBox(
              heightFactor: 0.92,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(margin: const EdgeInsets.symmetric(horizontal: 140), height: 4, decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2))),
                    const SizedBox(height: 16),
                    Text('Добавление товара', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87), textAlign: TextAlign.center),
                    const SizedBox(height: 16),

                    // МАГИЧЕСКОЕ ФОТО ТОВАРА
                    GestureDetector(
                      onTap: () => pickAndProcessImage(setModalState),
                      child: Center(
                        child: Container(
                          height: 120,
                          width: 120, 
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey[800] : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: isDark ? Colors.grey[700]! : Colors.blueGrey[200]!, width: 2),
                            image: selectedImageBytes != null ? DecorationImage(image: MemoryImage(selectedImageBytes!), fit: BoxFit.cover) : null,
                          ),
                          child: isProcessingImage 
                              ? const CircularProgressIndicator(color: Colors.blue)
                              : selectedImageBytes == null 
                                  ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.auto_fix_high, size: 32, color: Colors.blueGrey[400]), const SizedBox(height: 4), Text('ИИ-Фон', style: TextStyle(color: Colors.blueGrey[400], fontSize: 12, fontWeight: FontWeight.bold))])
                                  : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextField(
                      controller: nameController,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(labelText: 'Название товара / запчасти', labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.grey[700]), border: const OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<String>(
                            value: condition,
                            dropdownColor: Theme.of(context).cardColor,
                            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                            decoration: InputDecoration(labelText: 'Состояние', labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.grey[700]), border: const OutlineInputBorder()),
                            items: ['Новый', 'Б/У'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                            onChanged: (val) { if (val != null) setModalState(() => condition = val); },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: priceController,
                            keyboardType: TextInputType.number,
                            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                            decoration: InputDecoration(labelText: 'Цена (TMT)', labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.grey[700]), border: const OutlineInputBorder(), prefixIcon: const Icon(Icons.sell, color: Colors.green)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: barcodeController,
                            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                            decoration: InputDecoration(
                              labelText: 'Штрихкод', 
                              labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.grey[700]), 
                              border: const OutlineInputBorder(),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.qr_code_scanner, color: Colors.blue),
                                onPressed: () async {
                                  // --- ЗАПУСК ПОЛНОЭКРАННОГО СКАНЕРА ---
                                  var res = await Navigator.push(context, MaterialPageRoute(builder: (context) => const BarcodeScannerScreen()));
                                  if (res is String && res.isNotEmpty) {
                                    setModalState(() {
                                      barcodeController.text = res;
                                    });
                                  }
                                }, 
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: stockController,
                            keyboardType: TextInputType.number,
                            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                            decoration: InputDecoration(labelText: 'В наличии (шт)', labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.grey[700]), border: const OutlineInputBorder()),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: descController,
                      maxLines: 4,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                      decoration: InputDecoration(
                        labelText: 'Описание характеристик', 
                        alignLabelWithHint: true,
                        labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.grey[700]), 
                        border: const OutlineInputBorder(),
                        suffixIcon: Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            isGeneratingAI 
                              ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.deepPurpleAccent)))
                              : IconButton(
                                  icon: const Icon(Icons.auto_awesome, color: Colors.deepPurpleAccent),
                                  tooltip: 'Распознать по фото и описать (ИИ)',
                                  onPressed: () => generateDescriptionWithAI(setModalState),
                                ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.blueGrey[800],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: isSaving ? null : () async {
                        final name = nameController.text.trim();
                        final price = double.tryParse(priceController.text) ?? 0;
                        final stock = int.tryParse(stockController.text) ?? 0;
                        
                        if (name.isEmpty || price <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Укажите название и цену больше нуля')));
                          return;
                        }

                        setModalState(() => isSaving = true);
                        try {
                          String? imageBase64;
                          if (selectedImageBytes != null) {
                            imageBase64 = base64Encode(selectedImageBytes!);
                          }

                          await FirebaseFirestore.instance.collection('products').add({
                            'name': name,
                            'price': price,
                            'stock': stock,
                            'condition': condition,
                            'barcode': barcodeController.text.trim(),
                            'description': descController.text.trim(),
                            'image_base64': imageBase64,
                            'created_at': FieldValue.serverTimestamp(),
                            'is_active': stock > 0, 
                          });

                          if (context.mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Товар добавлен в магазин!'), backgroundColor: Colors.green));
                          }
                        } catch (e) {
                          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red));
                        } finally {
                          setModalState(() => isSaving = false);
                        }
                      },
                      child: isSaving 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('ОПУБЛИКОВАТЬ В МАГАЗИН', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          );
        }
      )
    );
  }

  void _deleteProduct(String docId) {
    FirebaseFirestore.instance.collection('products').doc(docId).delete();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: isDark ? Colors.grey[900] : Colors.blueGrey[900],
        foregroundColor: Colors.white,
        title: const Text('Склад и Витрина', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddProductDialog,
        backgroundColor: Colors.blueGrey[800],
        icon: const Icon(Icons.add_shopping_cart, color: Colors.white),
        label: const Text('Добавить товар', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: Theme.of(context).cardColor, boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.05), blurRadius: 5, offset: const Offset(0, 2))]),
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
              decoration: InputDecoration(
                hintText: 'Поиск по названию или штрихкоду...',
                hintStyle: TextStyle(color: isDark ? Colors.white54 : Colors.grey),
                prefixIcon: Icon(Icons.search, color: isDark ? Colors.white54 : Colors.grey),
                filled: true,
                fillColor: isDark ? Colors.grey[800] : Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),
          
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('products').orderBy('created_at', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 64, color: isDark ? Colors.grey[700] : Colors.blueGrey[200]),
                        const SizedBox(height: 16),
                        Text('Склад пуст', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.blueGrey[400], fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  );
                }

                var docs = snapshot.data!.docs;

                if (_searchQuery.isNotEmpty) {
                  final q = _searchQuery.toLowerCase();
                  docs = docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final name = (data['name'] ?? '').toString().toLowerCase();
                    final barcode = (data['barcode'] ?? '').toString().toLowerCase();
                    return name.contains(q) || barcode.contains(q);
                  }).toList();
                }

                return ListView.builder(
                  padding: EdgeInsets.only(top: 12, left: 12, right: 12, bottom: MediaQuery.of(context).padding.bottom + 80),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final name = data['name'] ?? 'Без названия';
                    final price = data['price'] ?? 0;
                    final stock = data['stock'] ?? 0;
                    final condition = data['condition'] ?? 'Новый';
                    final imageBase64 = data['image_base64'];

                    bool outOfStock = stock <= 0;

                    return Card(
                      elevation: 1,
                      color: Theme.of(context).cardColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey.shade200)),
                      margin: const EdgeInsets.only(bottom: 12),
                      clipBehavior: Clip.antiAlias,
                      child: Row(
                        children: [
                          Container(
                            height: 90,
                            width: 90,
                            decoration: BoxDecoration(
                              color: isDark ? Colors.grey[800] : Colors.grey[200],
                              image: imageBase64 != null && imageBase64.toString().isNotEmpty
                                  ? DecorationImage(image: MemoryImage(base64Decode(imageBase64)), fit: BoxFit.cover)
                                  : null,
                            ),
                            child: imageBase64 == null || imageBase64.toString().isEmpty
                                ? Icon(Icons.image_not_supported, color: isDark ? Colors.grey[600] : Colors.grey[400])
                                : null,
                          ),
                          
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? Colors.white : Colors.black87)),
                                      ),
                                      IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                        onPressed: () => _deleteProduct(doc.id),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text('$price TMT', style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.green, fontSize: 16)),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(color: condition == 'Новый' ? Colors.blue[100] : Colors.orange[100], borderRadius: BorderRadius.circular(4)),
                                        child: Text(condition, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: condition == 'Новый' ? Colors.blue[800] : Colors.orange[800])),
                                      ),
                                      Text(
                                        outOfStock ? 'НЕТ В НАЛИЧИИ' : 'Остаток: $stock шт',
                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: outOfStock ? Colors.red : Colors.grey),
                                      ),
                                    ],
                                  )
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              }
            ),
          )
        ],
      ),
    );
  }
}

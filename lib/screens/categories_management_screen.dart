import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CategoriesManagementScreen extends StatelessWidget {
  const CategoriesManagementScreen({super.key});

  // Указываем путь к нашему списку в базе данных: коллекция 'settings', документ 'categories'
  DocumentReference get _categoriesDoc => 
      FirebaseFirestore.instance.collection('settings').doc('categories');

  Future<void> _addCategory(BuildContext context) async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Новая категория', style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Например: Игровые приставки',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey[900], foregroundColor: Colors.white),
            onPressed: () async {
              final val = controller.text.trim();
              if (val.isNotEmpty) {
                // Добавляем новое значение в массив Firebase (arrayUnion исключает дубликаты)
                await _categoriesDoc.set({
                  'devices': FieldValue.arrayUnion([val])
                }, SetOptions(merge: true));
              }
              Navigator.pop(ctx);
            },
            child: const Text('Добавить'),
          ),
        ],
      ),
    );
  }

  Future<void> _removeCategory(String category) async {
    // Удаляем значение из массива Firebase
    await _categoriesDoc.set({
      'devices': FieldValue.arrayRemove([category])
    }, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.blueGrey[900],
        foregroundColor: Colors.white,
        title: const Text('Управление категориями', style: TextStyle(fontSize: 16)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.orange[600],
        foregroundColor: Colors.white,
        onPressed: () => _addCategory(context),
        icon: const Icon(Icons.add),
        label: const Text('Добавить', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _categoriesDoc.snapshots(), // Слушаем изменения в реальном времени
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          List<dynamic> categories = [];
          if (snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>;
            categories = data['devices'] ?? [];
          }

          // Если база пока пустая
          if (categories.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.category_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  const Text('Список категорий пуст.\nДобавьте первую категорию.', 
                    textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 16)),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () async {
                      // Кнопка для быстрой заливки стандартного списка (чтобы не вбивать вручную)
                      await _categoriesDoc.set({
                        'devices': ['Смартфон', 'Ноутбук', 'Компьютер (ПК)', 'Планшет', 'Принтер', 'Другое']
                      }, SetOptions(merge: true));
                    },
                    child: const Text('Загрузить стандартный список'),
                  )
                ],
              ),
            );
          }

          return ListView.builder(
            padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.of(context).padding.bottom + 80),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index] as String;
              return Card(
                elevation: 1,
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: const Icon(Icons.devices, color: Colors.blueGrey),
                  title: Text(category, style: const TextStyle(fontWeight: FontWeight.bold)),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _removeCategory(category),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

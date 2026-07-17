import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CategoriesManagementScreen extends StatelessWidget {
  const CategoriesManagementScreen({super.key});

  // Указываем путь к нашему НОВОМУ словарю в базе данных
  DocumentReference get _categoriesDoc => 
      FirebaseFirestore.instance.collection('settings').doc('categories_v2');

  // --- 1. ДОБАВИТЬ НОВОЕ ГЛОБАЛЬНОЕ НАПРАВЛЕНИЕ ---
  Future<void> _addDirection(BuildContext context) async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Новое направление', style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Например: Автосервис',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey[900], foregroundColor: Colors.white),
            onPressed: () async {
              final val = controller.text.trim();
              if (val.isNotEmpty) {
                // Создаем пустой массив для нового направления
                await _categoriesDoc.set({val: []}, SetOptions(merge: true));
              }
              Navigator.pop(ctx);
            },
            child: const Text('Добавить'),
          ),
        ],
      ),
    );
  }

  // --- 2. ДОБАВИТЬ ПОДКАТЕГОРИЮ В НАПРАВЛЕНИЕ ---
  Future<void> _addSubCategory(BuildContext context, String direction) async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Новая подкатегория в\n"$direction"', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Например: Замена масла',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey[900], foregroundColor: Colors.white),
            onPressed: () async {
              final val = controller.text.trim();
              if (val.isNotEmpty) {
                await _categoriesDoc.set({
                  direction: FieldValue.arrayUnion([val])
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

  // --- 3. ПЕРЕИМЕНОВАТЬ ПОДКАТЕГОРИЮ ---
  Future<void> _editSubCategory(BuildContext context, String direction, String oldName) async {
    final controller = TextEditingController(text: oldName);
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Переименовать', style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey[900], foregroundColor: Colors.white),
            onPressed: () async {
              final val = controller.text.trim();
              if (val.isNotEmpty && val != oldName) {
                // Firebase не умеет переименовывать элементы массива напрямую.
                // Поэтому мы удаляем старое значение и добавляем новое за один запрос.
                await _categoriesDoc.update({
                  direction: FieldValue.arrayRemove([oldName])
                });
                await _categoriesDoc.update({
                  direction: FieldValue.arrayUnion([val])
                });
              }
              Navigator.pop(ctx);
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  // --- 4. УДАЛИТЬ ПОДКАТЕГОРИЮ ---
  Future<void> _removeSubCategory(String direction, String subCategory) async {
    await _categoriesDoc.set({
      direction: FieldValue.arrayRemove([subCategory])
    }, SetOptions(merge: true));
  }

  // --- 5. УДАЛИТЬ ЦЕЛОЕ НАПРАВЛЕНИЕ ---
  Future<void> _removeDirection(String direction) async {
    await _categoriesDoc.update({
      direction: FieldValue.delete()
    });
  }

  // --- ЗАГРУЗКА БАЗОВОГО СПИСКА СУПЕР-ПРИЛОЖЕНИЯ ---
  Future<void> _loadDefaultSuperAppList() async {
    await _categoriesDoc.set({
      'Компьютерный сервис': ['Смартфон', 'Ноутбук', 'Компьютер (ПК)', 'Планшет', 'Принтер', 'Монитор', 'Комплектующие'],
      'Автосервис': ['Двигатель', 'Ходовая', 'Электрика', 'Кузовной ремонт', 'Шиномонтаж', 'Замена масла'],
      'Сварочные работы и Мебель': ['Мангалы', 'Ворота и заборы', 'Навесы', 'Ремонт мебели', 'Сборка мебели'],
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
        onPressed: () => _addDirection(context),
        icon: const Icon(Icons.add),
        label: const Text('Создать направление', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _categoriesDoc.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          Map<String, dynamic> data = {};
          if (snapshot.hasData && snapshot.data!.exists && snapshot.data!.data() != null) {
            data = snapshot.data!.data() as Map<String, dynamic>;
          }

          if (data.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.account_tree_outlined, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    const Text('Вы перешли на архитектуру Супер-приложения!\nДобавьте первое глобальное направление (например, "Компьютеры").', 
                      textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 15)),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _loadDefaultSuperAppList,
                      icon: const Icon(Icons.download),
                      label: const Text('Загрузить базовые направления'),
                    )
                  ],
                ),
              ),
            );
          }

          // Сортируем ключи (направления) по алфавиту для красоты
          final directions = data.keys.toList()..sort();

          return ListView.builder(
            padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.of(context).padding.bottom + 80),
            itemCount: directions.length,
            itemBuilder: (context, index) {
              final dirName = directions[index];
              final subCategories = List<String>.from(data[dirName] ?? [])..sort();

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                clipBehavior: Clip.antiAlias,
                child: ExpansionTile(
                  backgroundColor: Colors.blueGrey[50],
                  leading: const Icon(Icons.business_center, color: Colors.blueGrey),
                  title: Text(dirName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  childrenPadding: const EdgeInsets.only(bottom: 8),
                  children: [
                    const Divider(height: 1),
                    // Список подкатегорий
                    ...subCategories.map((sub) => ListTile(
                          contentPadding: const EdgeInsets.only(left: 32, right: 16),
                          leading: const Icon(Icons.subdirectory_arrow_right, size: 20, color: Colors.grey),
                          title: Text(sub, style: const TextStyle(fontSize: 14)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                                onPressed: () => _editSubCategory(context, dirName, sub),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                onPressed: () => _removeSubCategory(dirName, sub),
                              ),
                            ],
                          ),
                        )),
                    // Кнопка добавления подкатегории и удаления всего направления
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton.icon(
                            style: TextButton.styleFrom(foregroundColor: Colors.red),
                            onPressed: () => _removeDirection(dirName),
                            icon: const Icon(Icons.delete_forever, size: 18),
                            label: const Text('Удалить направление'),
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueGrey[100],
                              foregroundColor: Colors.blueGrey[900],
                              elevation: 0,
                            ),
                            onPressed: () => _addSubCategory(context, dirName),
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Добавить пункт'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

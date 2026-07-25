import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
// Если у тебя еще не добавлены эти пакеты, добавь их потом в pubspec.yaml:
// image_picker: ^1.0.4
// firebase_storage: ^11.6.0

class ContentManagerScreen extends StatefulWidget {
  const ContentManagerScreen({super.key});

  @override
  State<ContentManagerScreen> createState() => _ContentManagerScreenState();
}

class _ContentManagerScreenState extends State<ContentManagerScreen> {
  
  // --- ОКНО СОЗДАНИЯ КОНТЕНТА (ПОСТА) ---
  void _showCreatePostDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    String selectedType = 'Акция'; // 'Акция' или 'Новость'
    bool isUploading = false;

    // Функция-помощник для вставки тегов форматирования
    void insertFormatting(String prefix, String suffix) {
      final text = contentController.text;
      final selection = contentController.selection;
      if (selection.isValid && selection.start >= 0 && selection.end >= 0) {
        final newText = text.replaceRange(selection.start, selection.end, '$prefix${text.substring(selection.start, selection.end)}$suffix');
        contentController.text = newText;
        contentController.selection = TextSelection.collapsed(offset: selection.start + prefix.length);
      } else {
        contentController.text = text + prefix + suffix;
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
              left: 16, right: 16, top: 16
            ),
            child: FractionallySizedBox(
              heightFactor: 0.85, // Занимает 85% экрана для удобного ввода
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 140),
                    height: 4,
                    decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(height: 16),
                  Text('Создание публикации', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87), textAlign: TextAlign.center),
                  const SizedBox(height: 16),

                  // Выбор типа: Новость или Акция
                  Row(
                    children: [
                      Expanded(
                        child: RadioListTile<String>(
                          title: Text('Акция (Скидки)', style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14)),
                          value: 'Акция',
                          groupValue: selectedType,
                          activeColor: Colors.orange,
                          contentPadding: EdgeInsets.zero,
                          onChanged: (val) => setSheetState(() => selectedType = val!),
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<String>(
                          title: Text('Новость (Инфо)', style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14)),
                          value: 'Новость',
                          groupValue: selectedType,
                          activeColor: Colors.blue,
                          contentPadding: EdgeInsets.zero,
                          onChanged: (val) => setSheetState(() => selectedType = val!),
                        ),
                      ),
                    ],
                  ),

                  TextField(
                    controller: titleController,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      labelText: 'Броский заголовок',
                      labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.grey[700]),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // --- ПАНЕЛЬ ФОРМАТИРОВАНИЯ ---
                  Container(
                    decoration: BoxDecoration(color: isDark ? Colors.grey[800] : Colors.blueGrey[50], borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    child: Row(
                      children: [
                        IconButton(icon: const Icon(Icons.format_bold), tooltip: 'Жирный', onPressed: () => insertFormatting('**', '**')),
                        IconButton(icon: const Icon(Icons.format_italic), tooltip: 'Курсив', onPressed: () => insertFormatting('_', '_')),
                        IconButton(icon: const Icon(Icons.title), tooltip: 'Заголовок', onPressed: () => insertFormatting('### ', '\n')),
                        IconButton(icon: const Icon(Icons.format_list_bulleted), tooltip: 'Список', onPressed: () => insertFormatting('• ', '\n')),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  Expanded(
                    child: TextField(
                      controller: contentController,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                      decoration: InputDecoration(
                        labelText: 'Основной текст',
                        alignLabelWithHint: true,
                        labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.grey[700]),
                        border: const OutlineInputBorder(),
                        helperText: 'Используйте панель выше для красоты',
                      ),
                      maxLines: 15,
                      keyboardType: TextInputType.multiline,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // --- КНОПКИ ЗАГРУЗКИ МЕДИА ---
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Тут будет вызов ImagePicker(imageQuality: 70)')));
                          }, 
                          icon: const Icon(Icons.image, color: Colors.green), 
                          label: const Text('ФОТО', style: TextStyle(color: Colors.green))
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Тут будет выбор видео и сжатие (до 15 сек)')));
                          }, 
                          icon: const Icon(Icons.videocam, color: Colors.blue), 
                          label: const Text('ВИДЕО', style: TextStyle(color: Colors.blue))
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: selectedType == 'Акция' ? Colors.orange[600] : Colors.blue[600],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: isUploading ? null : () async {
                      final title = titleController.text.trim();
                      final content = contentController.text.trim();

                      if (title.isEmpty || content.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Заполните заголовок и текст')));
                        return;
                      }

                      setSheetState(() => isUploading = true);

                      try {
                        await FirebaseFirestore.instance.collection('news_feed').add({
                          'title': title,
                          'content': content,
                          'type': selectedType,
                          'image_url': null, // Сюда потом пойдет ссылка из Storage
                          'video_url': null, // Сюда ссылка на видео
                          'created_at': FieldValue.serverTimestamp(),
                          'is_active': true,
                        });

                        if (context.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Публикация успешно создана!'), backgroundColor: Colors.green));
                        }
                      } catch (e) {
                        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red));
                      } finally {
                        setSheetState(() => isUploading = false);
                      }
                    },
                    child: isUploading 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('ОПУБЛИКОВАТЬ КОНТЕНТ', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _deletePost(String docId) {
    FirebaseFirestore.instance.collection('news_feed').doc(docId).delete();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: isDark ? Colors.grey[900] : Colors.blueGrey[900],
        foregroundColor: Colors.white,
        title: const Text('Контент-Менеджер (Лента)', style: TextStyle(fontSize: 18)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreatePostDialog,
        backgroundColor: Colors.pink[600],
        icon: const Icon(Icons.add_photo_alternate, color: Colors.white),
        label: const Text('Создать пост', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('news_feed').orderBy('created_at', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.newspaper, size: 64, color: isDark ? Colors.grey[700] : Colors.blueGrey[200]),
                  const SizedBox(height: 16),
                  Text('Лента пуста', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.blueGrey[400], fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Создайте первую акцию или новость!', style: TextStyle(color: isDark ? Colors.grey[600] : Colors.blueGrey[300], fontSize: 14)),
                ],
              ),
            );
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            padding: EdgeInsets.only(top: 16, left: 16, right: 16, bottom: MediaQuery.of(context).padding.bottom + 80),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              
              final type = data['type'] ?? 'Новость';
              final title = data['title'] ?? 'Без заголовка';
              final content = data['content'] ?? '';
              final isActive = data['is_active'] ?? true;
              
              String dateStr = '';
              if (data['created_at'] != null) {
                final dt = (data['created_at'] as Timestamp).toDate();
                dateStr = DateFormat('dd.MM.yy в HH:mm').format(dt);
              }

              return Card(
                elevation: 2,
                color: Theme.of(context).cardColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: isDark ? Colors.grey[800]! : Colors.transparent)
                ),
                margin: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Шапка поста
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: type == 'Акция' ? (isDark ? Colors.orange[900]!.withOpacity(0.4) : Colors.orange[50]) : (isDark ? Colors.blue[900]!.withOpacity(0.4) : Colors.blue[50]),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(type == 'Акция' ? Icons.local_fire_department : Icons.info, color: type == 'Акция' ? Colors.deepOrange : Colors.blue, size: 20),
                              const SizedBox(width: 8),
                              Text(type.toUpperCase(), style: TextStyle(fontWeight: FontWeight.bold, color: type == 'Акция' ? Colors.deepOrange : Colors.blue, fontSize: 12, letterSpacing: 1.2)),
                            ],
                          ),
                          Text(dateStr, style: TextStyle(color: isDark ? Colors.white54 : Colors.blueGrey, fontSize: 12)),
                        ],
                      ),
                    ),
                    
                    // Контент поста
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: isDark ? Colors.white : Colors.black87)),
                          const SizedBox(height: 8),
                          Text(
                            content, 
                            maxLines: 4, 
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: isDark ? Colors.white70 : Colors.grey[800], fontSize: 14, height: 1.4)
                          ),
                        ],
                      ),
                    ),

                    // Кнопки управления (Удалить / Скрыть)
                    Divider(height: 1, color: isDark ? Colors.grey[800] : Colors.grey[200]),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Switch(
                                value: isActive,
                                activeColor: Colors.green,
                                onChanged: (val) {
                                  FirebaseFirestore.instance.collection('news_feed').doc(doc.id).update({'is_active': val});
                                },
                              ),
                              Text(isActive ? 'Активен' : 'Скрыт', style: TextStyle(color: isActive ? Colors.green : Colors.grey, fontWeight: FontWeight.bold, fontSize: 12)),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () => _deletePost(doc.id),
                            tooltip: 'Удалить навсегда',
                          ),
                        ],
                      ),
                    )
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


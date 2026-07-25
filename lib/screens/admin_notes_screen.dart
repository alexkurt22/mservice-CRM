import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AdminNotesScreen extends StatefulWidget {
  const AdminNotesScreen({super.key});

  @override
  State<AdminNotesScreen> createState() => _AdminNotesScreenState();
}

class _AdminNotesScreenState extends State<AdminNotesScreen> {
  
  // --- ОКНО СОЗДАНИЯ И РЕДАКТИРОВАНИЯ ЗАМЕТКИ ---
  void _showNoteDialog({String? docId, String? initialTitle, String? initialContent}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleController = TextEditingController(text: initialTitle);
    final contentController = TextEditingController(text: initialContent);
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom, 
          left: 16, right: 16, top: 16
        ),
        child: StatefulBuilder(
          builder: (context, setSheetState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Ползунок сверху
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 140),
                  height: 4,
                  decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(height: 16),
                Text(
                  docId == null ? 'Новая заметка' : 'Редактировать', 
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87), 
                  textAlign: TextAlign.center
                ),
                const SizedBox(height: 24),
                
                TextField(
                  controller: titleController,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    labelText: 'Заголовок',
                    labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.grey[700]),
                    border: const OutlineInputBorder(),
                    prefixIcon: Icon(Icons.title, color: isDark ? Colors.blue[300] : Colors.blue),
                  ),
                ),
                const SizedBox(height: 16),
                
                TextField(
                  controller: contentController,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    labelText: 'Текст заметки',
                    labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.grey[700]),
                    border: const OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 8, // Делаем поле большим для удобного ввода
                  keyboardType: TextInputType.multiline,
                ),
                const SizedBox(height: 24),
                
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.blueGrey[900],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: isSaving ? null : () async {
                    final title = titleController.text.trim();
                    final content = contentController.text.trim();

                    if (title.isEmpty || content.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Заполните заголовок и текст')));
                      return;
                    }

                    setSheetState(() => isSaving = true);

                    try {
                      if (docId == null) {
                        // Создаем новую
                        await FirebaseFirestore.instance.collection('admin_notes').add({
                          'title': title,
                          'content': content,
                          'created_at': FieldValue.serverTimestamp(),
                          'updated_at': FieldValue.serverTimestamp(),
                        });
                      } else {
                        // Обновляем существующую
                        await FirebaseFirestore.instance.collection('admin_notes').doc(docId).update({
                          'title': title,
                          'content': content,
                          'updated_at': FieldValue.serverTimestamp(),
                        });
                      }

                      if (context.mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(docId == null ? 'Заметка сохранена!' : 'Заметка обновлена!'), backgroundColor: Colors.green));
                      }
                    } catch (e) {
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red));
                    } finally {
                      setSheetState(() => isSaving = false);
                    }
                  },
                  child: isSaving 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('СОХРАНИТЬ', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                ),
                const SizedBox(height: 24),
              ],
            );
          },
        ),
      ),
    );
  }

  // --- БЕЗОПАСНОЕ УДАЛЕНИЕ ---
  Future<void> _deleteNote(String docId, String title) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: const Text('Удаление', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: Text('Вы уверены, что хотите удалить заметку "$title"?', style: TextStyle(color: isDark ? Colors.white70 : Colors.black87)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена', style: TextStyle(color: Colors.grey))),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700]),
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.delete, color: Colors.white, size: 18),
            label: const Text('Удалить', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance.collection('admin_notes').doc(docId).delete();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Заметка удалена')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: isDark ? Colors.grey[900] : Colors.blueGrey[900],
        foregroundColor: Colors.white,
        title: const Text('База знаний', style: TextStyle(fontSize: 18)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showNoteDialog(),
        backgroundColor: Colors.blue[700],
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Заметка', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('admin_notes').orderBy('updated_at', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.menu_book, size: 64, color: isDark ? Colors.grey[700] : Colors.blueGrey[200]),
                  const SizedBox(height: 16),
                  Text('Здесь пока нет заметок', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.blueGrey[400], fontSize: 16)),
                  const SizedBox(height: 8),
                  Text('Сохраняйте пароли, ссылки и инструкции', style: TextStyle(color: isDark ? Colors.grey[600] : Colors.blueGrey[300], fontSize: 13)),
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
              final title = data['title'] ?? 'Без заголовка';
              final content = data['content'] ?? '';
              
              String dateStr = '';
              if (data['updated_at'] != null) {
                final dt = (data['updated_at'] as Timestamp).toDate();
                dateStr = DateFormat('dd.MM.yy HH:mm').format(dt);
              }

              return Card(
                elevation: 1,
                color: Theme.of(context).cardColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: isDark ? Colors.grey[800]! : Colors.transparent)
                ),
                margin: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _showNoteDialog(docId: doc.id, initialTitle: title, initialContent: content),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                title, 
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.blue[300] : Colors.blue[800])
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                              onPressed: () => _deleteNote(doc.id, title),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          content,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 14),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(Icons.access_time, size: 14, color: isDark ? Colors.grey[500] : Colors.grey),
                            const SizedBox(width: 4),
                            Text('Обновлено: $dateStr', style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey, fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
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

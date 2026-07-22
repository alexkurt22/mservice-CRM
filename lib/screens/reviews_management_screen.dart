import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ReviewsManagementScreen extends StatelessWidget {
  const ReviewsManagementScreen({super.key});

  // --- 1. ОПУБЛИКОВАТЬ ---
  void _approveReview(BuildContext context, String docId) async {
    await FirebaseFirestore.instance.collection('reviews').doc(docId).update({
      'is_approved': true,
      'needs_edit': false, // Снимаем флаг доработки, если он был
    });
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Отзыв опубликован!'), backgroundColor: Colors.green));
    }
  }

  // --- 2. ОТПРАВИТЬ НА РЕДАКТИРОВАНИЕ ---
  void _sendForEditDialog(BuildContext context, String docId) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [Icon(Icons.edit_note, color: Colors.orange), SizedBox(width: 8), Text('На доработку')]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Укажите причину для клиента:', style: TextStyle(fontSize: 13, color: Colors.blueGrey)),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Например: Пожалуйста, уберите мат из текста...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[700], foregroundColor: Colors.white),
            onPressed: () async {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Укажите причину!'), backgroundColor: Colors.red));
                return;
              }
              
              await FirebaseFirestore.instance.collection('reviews').doc(docId).update({
                'needs_edit': true,
                'admin_message': reason,
                'is_approved': false,
              });
              
              if (context.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Отправлено клиенту на доработку!'), backgroundColor: Colors.orange));
              }
            },
            child: const Text('Отправить'),
          ),
        ],
      ),
    );
  }

  // --- 3. УДАЛИТЬ ---
  void _deleteReview(BuildContext context, String docId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удаление'),
        content: const Text('Точно удалить этот отзыв навсегда?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Удалить', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance.collection('reviews').doc(docId).delete();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Отзыв удален.')));
      }
    }
  }

  Widget _buildReviewsList(bool isApproved) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('reviews')
          .where('is_approved', isEqualTo: isApproved)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(isApproved ? Icons.verified : Icons.hourglass_empty, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text(isApproved ? 'Нет опубликованных отзывов' : 'Новых отзывов нет', style: const TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        var docs = snapshot.data!.docs.toList();
        docs.sort((a, b) {
          final aTime = (a.data() as Map<String, dynamic>)['created_at'] as Timestamp?;
          final bTime = (b.data() as Map<String, dynamic>)['created_at'] as Timestamp?;
          if (aTime == null || bTime == null) return 0;
          return bTime.compareTo(aTime);
        });

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final rating = data['rating'] ?? 5;
            final text = data['text'] ?? '';
            final author = data['author_name'] ?? 'Клиент';
            final device = data['device_type'] ?? '';
            final bool needsEdit = data['needs_edit'] ?? false;
            final String adminMessage = data['admin_message'] ?? '';

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: isApproved ? Colors.green.shade200 : (needsEdit ? Colors.orange.shade400 : Colors.blue.shade200), width: 1.5),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(author, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Row(children: List.generate(5, (i) => Icon(i < rating ? Icons.star_rounded : Icons.star_border_rounded, color: Colors.orange, size: 20))),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(device, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                    const Divider(height: 24),
                    
                    Text(
                      text.isEmpty ? 'Пользователь не оставил комментарий, только оценку.' : text, 
                      style: TextStyle(fontStyle: text.isEmpty ? FontStyle.italic : FontStyle.normal, color: text.isEmpty ? Colors.grey : Colors.black87, fontSize: 15)
                    ),
                    const SizedBox(height: 16),

                    // Показываем плашку, если отзыв уже был отправлен на доработку
                    if (needsEdit) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.orange.shade200)),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.info_outline, color: Colors.orange, size: 20),
                            const SizedBox(width: 8),
                            Expanded(child: Text('Ждет исправления от клиента:\n"$adminMessage"', style: TextStyle(color: Colors.orange[800], fontSize: 13, fontWeight: FontWeight.bold))),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Кнопки управления (Используем Wrap, чтобы кнопки не вылезали за экран на узких телефонах)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.end,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        IconButton(
                          onPressed: () => _deleteReview(context, doc.id),
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          tooltip: 'Удалить',
                        ),
                        if (!isApproved) ...[
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(foregroundColor: Colors.orange[800], side: BorderSide(color: Colors.orange.shade300)),
                            onPressed: () => _sendForEditDialog(context, doc.id),
                            icon: const Icon(Icons.edit),
                            label: const Text('На доработку'),
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green[600], foregroundColor: Colors.white),
                            onPressed: () => _approveReview(context, doc.id),
                            icon: const Icon(Icons.check),
                            label: const Text('Одобрить'),
                          )
                        ]
                      ],
                    )
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          backgroundColor: Colors.blueGrey[900],
          foregroundColor: Colors.white,
          title: const Text('Отзывы клиентов', style: TextStyle(fontWeight: FontWeight.bold)),
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.orange,
            tabs: [
              Tab(text: 'На проверке'),
              Tab(text: 'Опубликованы'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildReviewsList(false), // Неодобренные
            _buildReviewsList(true),  // Одобренные
          ],
        ),
      ),
    );
  }
}

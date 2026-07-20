import 'dart:io';
import 'dart:convert'; // ВАЖНО: Добавлено для расшифровки русских имен
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart'; 
import 'package:file_picker/file_picker.dart'; 

class ParsedContact {
  String phone;
  TextEditingController nameController;
  bool isSelected = false; 

  ParsedContact({required this.phone, required String name}) 
    : nameController = TextEditingController(text: name);
}

class ImportClientsScreen extends StatefulWidget {
  const ImportClientsScreen({super.key});

  @override
  State<ImportClientsScreen> createState() => _ImportClientsScreenState();
}

class _ImportClientsScreenState extends State<ImportClientsScreen> {
  final TextEditingController _pasteController = TextEditingController();
  
  bool _isProcessing = false;
  int _step = 1; 
  
  List<ParsedContact> _readyContacts = [];
  int _totalFound = 0;
  int _duplicatesInText = 0;
  int _alreadyInDb = 0;

  // --- ФУНКЦИЯ ДЕКОДИРОВАНИЯ (ПРЕВРАЩАЕТ =D0=9C В НОРМАЛЬНЫЕ БУКВЫ) ---
  String _decodeQuotedPrintable(String input) {
    try {
      // Убираем переносы
      input = input.replaceAll('=\n', '').replaceAll('=\r\n', '');
      
      List<int> bytes = [];
      int i = 0;
      while (i < input.length) {
        if (input[i] == '=' && i + 2 < input.length) {
          String hex = input.substring(i + 1, i + 3);
          int? byteValue = int.tryParse(hex, radix: 16);
          if (byteValue != null) {
            bytes.add(byteValue);
            i += 3;
            continue;
          }
        }
        bytes.add(input.codeUnitAt(i));
        i++;
      }
      return utf8.decode(bytes, allowMalformed: true);
    } catch (e) {
      return input; // Если не получилось, отдаем как есть
    }
  }

  // --- ЛОГИКА ЧТЕНИЯ .VCF ФАЙЛОВ ---
  Future<void> _pickVcfFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any, 
      );

      if (result != null && result.files.single.path != null) {
        setState(() => _isProcessing = true);
        File file = File(result.files.single.path!);
        String content = await file.readAsString();

        // Склеиваем разорванные строки (стандарт формата VCF)
        content = content.replaceAll(RegExp(r'\n[ \t]'), '');

        String extractedText = '';
        String currentName = 'Без имени';

        // Парсим VCF построчно
        for (String line in content.split('\n')) {
          line = line.trim();
          if (line.startsWith('BEGIN:VCARD')) {
            currentName = 'Без имени';
          } else if (line.startsWith('FN')) {
            // Вытаскиваем имя
            int colonIdx = line.indexOf(':');
            if (colonIdx != -1) {
              String rawName = line.substring(colonIdx + 1).trim();
              
              // Проверяем, нужно ли расшифровать имя (если оно выглядит как =D0=9C...)
              if (line.substring(0, colonIdx).toUpperCase().contains('QUOTED-PRINTABLE') || rawName.contains('=')) {
                currentName = _decodeQuotedPrintable(rawName);
              } else {
                currentName = rawName;
              }
            }
          } else if (line.startsWith('TEL')) {
            // Вытаскиваем телефон
            int colonIdx = line.indexOf(':');
            if (colonIdx != -1) {
              String rawPhone = line.substring(colonIdx + 1).trim();
              extractedText += '$currentName $rawPhone\n';
            }
          }
        }

        if (extractedText.isNotEmpty) {
          setState(() {
            _pasteController.text = extractedText; 
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Файл успешно прочитан и расшифрован!'), backgroundColor: Colors.green)
          );
        } else {
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Не удалось найти контакты в файле'), backgroundColor: Colors.orange)
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка чтения файла: $e'), backgroundColor: Colors.red)
      );
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _analyzeText() async {
    final text = _pasteController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isProcessing = true;
      _readyContacts.clear();
      _totalFound = 0;
      _duplicatesInText = 0;
      _alreadyInDb = 0;
    });

    try {
      final snap = await FirebaseFirestore.instance.collection('clients').get();
      final Set<String> existingDbPhones = snap.docs
          .map((doc) => (doc.data()['phone'] ?? '').toString())
          .toSet();

      final Set<String> seenPhonesInText = {};
      final lines = text.split('\n');

      final phoneExp = RegExp(r'(\+?993|8)?[\s\-]?\(?(6\d)\)?[\s\-]?(\d{2})[\s\-]?(\d{2})[\s\-]?(\d{2})');

      for (String line in lines) {
        if (line.trim().isEmpty) continue;

        final match = phoneExp.firstMatch(line);
        if (match != null) {
          _totalFound++;
          String rawMatched = match.group(0)!;
          
          String digits = rawMatched.replaceAll(RegExp(r'\D'), '');
          String cleanPhone = '';
          if (digits.length == 8) cleanPhone = '+993$digits';
          else if (digits.length == 9 && digits.startsWith('8')) cleanPhone = '+993${digits.substring(1)}';
          else if (digits.length == 11 && digits.startsWith('993')) cleanPhone = '+$digits';
          else cleanPhone = '+$digits';

          if (seenPhonesInText.contains(cleanPhone)) {
            _duplicatesInText++;
            continue;
          }
          if (existingDbPhones.contains(cleanPhone)) {
            _alreadyInDb++;
            continue;
          }

          seenPhonesInText.add(cleanPhone);

          String name = line.replaceAll(rawMatched, '').trim();
          name = name.replaceAll(RegExp(r'^[^a-zA-Zа-яА-Я0-9]+|[^a-zA-Zа-яА-Я0-9]+$'), '').trim();
          if (name.isEmpty) name = 'Без имени';

          _readyContacts.add(ParsedContact(phone: cleanPhone, name: name));
        }
      }

      setState(() {
        _step = 2;
        _isProcessing = false;
      });

    } catch (e) {
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка анализа: $e')));
    }
  }

  Future<void> _copyUnselectedToClipboard(List<ParsedContact> unselected) async {
    if (unselected.isEmpty) return;
    String textToCopy = unselected.map((c) => '${c.phone} ${c.nameController.text.trim()}').join('\n');
    await Clipboard.setData(ClipboardData(text: textToCopy));
  }

  Future<void> _importSelected() async {
    final toImport = _readyContacts.where((c) => c.isSelected).toList();
    final toDelay = _readyContacts.where((c) => !c.isSelected).toList();

    if (toImport.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Сначала отметьте галочками тех, кого хотите импортировать!')));
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final batch = FirebaseFirestore.instance.batch();
      final collection = FirebaseFirestore.instance.collection('clients');

      for (var contact in toImport) {
        final docRef = collection.doc();
        batch.set(docRef, {
          'name': contact.nameController.text.trim(),
          'phone': contact.phone,
          'is_offline': true,
          'is_approved': false,
          'created_at': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      setState(() => _isProcessing = false);

      if (toDelay.isNotEmpty && context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Успешный импорт! 🎉'),
            content: Text('Импортировано в базу: ${toImport.length}\n\nОсталось неотмеченных: ${toDelay.length}\n\nСкопировать оставшиеся контакты в буфер обмена?'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); 
                  Navigator.pop(context); 
                },
                child: const Text('Просто выйти', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey[900]),
                icon: const Icon(Icons.copy, color: Colors.white),
                label: const Text('Скопировать и выйти', style: TextStyle(color: Colors.white)),
                onPressed: () async {
                  await _copyUnselectedToClipboard(toDelay);
                  if (context.mounted) {
                    Navigator.pop(context);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Отложенные контакты скопированы!'), backgroundColor: Colors.blue));
                  }
                },
              )
            ],
          )
        );
      } else if (context.mounted) {
         Navigator.pop(context);
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Все ${toImport.length} клиентов импортированы!'), backgroundColor: Colors.green)
         );
      }

    } catch (e) {
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка сохранения: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Массовый импорт базы'),
        backgroundColor: Colors.blueGrey[900],
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: _step == 1 ? _buildStep1Input() : _buildStep2Review(),
      ),
    );
  }

  Widget _buildStep1Input() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(8)),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue),
                SizedBox(width: 12),
                Expanded(child: Text('Загрузите файл с контактами (.vcf) или вставьте текст скопированный из Заметок.', style: TextStyle(color: Colors.blue))),
              ],
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: const BorderSide(color: Colors.blueGrey, width: 2),
            ),
            onPressed: _isProcessing ? null : _pickVcfFile,
            icon: const Icon(Icons.contact_phone, color: Colors.blueGrey),
            label: const Text('ВЫБРАТЬ ФАЙЛ КОНТАКТОВ (.vcf)', style: TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 16),
          const Text('Или вставьте текст вручную:', style: TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Expanded(
            child: TextField(
              controller: _pasteController,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              decoration: const InputDecoration(
                hintText: 'Иван +99365112233\nМердан 864 12-34-56...',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey[900], padding: const EdgeInsets.symmetric(vertical: 16)),
            onPressed: _isProcessing ? null : _analyzeText,
            child: _isProcessing 
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Анализировать', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2Review() {
    int selectedCount = _readyContacts.where((c) => c.isSelected).length;
    int unselectedCount = _readyContacts.length - selectedCount;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey[100],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('📊 Результаты анализа:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey[900])),
              const SizedBox(height: 8),
              Text('Найдено номеров: $_totalFound', style: const TextStyle(fontSize: 14)),
              Text('Дубликатов в тексте (проигнорировано): $_duplicatesInText', style: const TextStyle(fontSize: 14, color: Colors.orange)),
              Text('Уже есть в базе CRM (проигнорировано): $_alreadyInDb', style: const TextStyle(fontSize: 14, color: Colors.red)),
              const Divider(),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('К импорту: $selectedCount / ${_readyContacts.length}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green)),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        bool allSelected = selectedCount == _readyContacts.length;
                        for (var c in _readyContacts) {
                          c.isSelected = !allSelected; 
                        }
                      });
                    },
                    icon: const Icon(Icons.checklist, size: 18),
                    label: Text(selectedCount == _readyContacts.length ? 'Снять все' : 'Выбрать все'),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: _readyContacts.isEmpty 
          ? const Center(child: Text('Новых уникальных контактов не найдено.'))
          : ListView.builder(
              itemCount: _readyContacts.length,
              itemBuilder: (context, index) {
                final contact = _readyContacts[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Checkbox(
                          value: contact.isSelected,
                          onChanged: (val) {
                            setState(() => contact.isSelected = val ?? false);
                          },
                        ),
                        SizedBox(
                          width: 105,
                          child: Text(contact.phone, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                        Expanded(
                          child: TextField(
                            controller: contact.nameController,
                            decoration: const InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                              hintText: 'Имя',
                            ),
                            style: TextStyle(fontSize: 14, color: contact.isSelected ? Colors.black : Colors.grey),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ),
        Container(
          padding: const EdgeInsets.only(bottom: 12, top: 12, left: 16, right: 16),
          decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, -2))]),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (unselectedCount > 0)
                OutlinedButton.icon(
                  onPressed: () async {
                    await _copyUnselectedToClipboard(_readyContacts.where((c) => !c.isSelected).toList());
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Отложенные контакты скопированы!')));
                  },
                  icon: const Icon(Icons.copy),
                  label: Text('Скопировать отложенные ($unselectedCount)'),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                ),
              if (unselectedCount > 0) const SizedBox(height: 8),
              
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700], padding: const EdgeInsets.symmetric(vertical: 16)),
                onPressed: _isProcessing || selectedCount == 0 ? null : _importSelected,
                child: _isProcessing 
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text('СОХРАНИТЬ В БАЗУ ($selectedCount)', style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

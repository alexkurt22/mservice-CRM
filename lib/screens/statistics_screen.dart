import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  String _selectedPeriod = 'За 30 дней';
  final List<String> _periods = ['Сегодня', 'За 7 дней', 'За 30 дней', 'За всё время'];

  // Фильтрация дат 
  bool _isWithinPeriod(Timestamp? timestamp) {
    if (timestamp == null) return false;
    if (_selectedPeriod == 'За всё время') return true;

    final date = timestamp.toDate();
    final now = DateTime.now();

    if (_selectedPeriod == 'Сегодня') {
      return date.year == now.year && date.month == now.month && date.day == now.day;
    } else if (_selectedPeriod == 'За 7 дней') {
      final weekAgo = now.subtract(const Duration(days: 7));
      return date.isAfter(weekAgo);
    } else if (_selectedPeriod == 'За 30 дней') {
      final monthAgo = now.subtract(const Duration(days: 30));
      return date.isAfter(monthAgo);
    }
    return true;
  }

  // --- МОДАЛЬНОЕ ОКНО ДОБАВЛЕНИЯ ТРАНЗАКЦИИ (РАСХОД ИЛИ ДОЛГ) ---
  void _showAddTransactionDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String transactionType = 'Расход'; 
    String selectedRegister = 'Выездная касса (Мастер)';
    final List<String> registers = ['Дневная касса (Офис)', 'Выездная касса (Мастер)', 'Глобальная (Безнал/Счет)'];
    
    final amountController = TextEditingController();
    final descController = TextEditingController();
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            backgroundColor: Theme.of(context).cardColor,
            title: Text('Новая операция', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    decoration: BoxDecoration(color: isDark ? Colors.grey[800] : Colors.grey[200], borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setModalState(() => transactionType = 'Расход'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(color: transactionType == 'Расход' ? Colors.red[400] : Colors.transparent, borderRadius: BorderRadius.circular(8)),
                              child: Text('ТРАТА ИЗ КАССЫ', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: transactionType == 'Расход' ? Colors.white : Colors.grey)),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setModalState(() => transactionType = 'Реализация'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(color: transactionType == 'Реализация' ? Colors.deepPurple[400] : Colors.transparent, borderRadius: BorderRadius.circular(8)),
                              child: Text('ВЗЯЛИ В ДОЛГ', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: transactionType == 'Реализация' ? Colors.white : Colors.grey)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      labelText: 'Сумма (TMT)',
                      labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.grey[700]),
                      prefixIcon: Icon(Icons.money_off, color: transactionType == 'Расход' ? Colors.red : Colors.deepPurple),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: descController,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      labelText: 'Описание (Напр., Тонер)',
                      labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.grey[700]),
                      prefixIcon: const Icon(Icons.edit_note, color: Colors.blueGrey),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  
                  if (transactionType == 'Расход') ...[
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedRegister,
                      dropdownColor: Theme.of(context).cardColor,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                      decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Из какой кассы минус?'),
                      items: registers.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                      onChanged: (val) {
                        if (val != null) setModalState(() => selectedRegister = val);
                      },
                    ),
                  ]
                ],
              ),
            ),
            actions: [
              if (!isSaving)
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена', style: TextStyle(color: Colors.grey))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: transactionType == 'Расход' ? Colors.red[600] : Colors.deepPurple[600]),
                onPressed: isSaving ? null : () async {
                  final amount = double.tryParse(amountController.text.trim());
                  final desc = descController.text.trim();
                  
                  if (amount == null || amount <= 0 || desc.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Укажите корректную сумму и описание')));
                    return;
                  }

                  setModalState(() => isSaving = true);
                  
                  try {
                    final prefs = await SharedPreferences.getInstance();
                    final myPhone = prefs.getString('employee_phone') ?? 'admin';

                    await FirebaseFirestore.instance.collection('financial_transactions').add({
                      'type': transactionType == 'Расход' ? 'expense' : 'liability',
                      'amount': amount,
                      'description': desc,
                      'register': transactionType == 'Расход' ? selectedRegister : 'Долг поставщикам',
                      'created_at': FieldValue.serverTimestamp(),
                      'added_by': myPhone,
                    });

                    if (mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Операция сохранена!'), backgroundColor: Colors.green));
                    }
                  } catch (e) {
                    setModalState(() => isSaving = false);
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red));
                  }
                },
                child: isSaving 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('СОХРАНИТЬ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        }
      ),
    );
  }

  // --- НОВОЕ: ОКНО КАЛЬКУЛЯЦИИ ДИВИДЕНДОВ И ОБНУЛЕНИЯ КАССЫ ---
  void _showCalculateDividendsDialog(double currentCashBalance) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final partner1Controller = TextEditingController();
    final partner2Controller = TextEditingController();
    final reserveController = TextEditingController();
    
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          
          double p1 = double.tryParse(partner1Controller.text) ?? 0;
          double p2 = double.tryParse(partner2Controller.text) ?? 0;
          double res = double.tryParse(reserveController.text) ?? 0;
          double totalToWithdraw = p1 + p2 + res;
          double remainder = currentCashBalance - totalToWithdraw;

          return AlertDialog(
            backgroundColor: Theme.of(context).cardColor,
            title: Text('Снятие и Обнуление Кассы', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: isDark ? Colors.green[900]?.withOpacity(0.3) : Colors.green[50], borderRadius: BorderRadius.circular(8)),
                    child: Column(
                      children: [
                        const Text('Доступно Наличных (Офис + Выезд):', style: TextStyle(color: Colors.grey, fontSize: 12)),
                        Text('${currentCashBalance.toStringAsFixed(0)} TMT', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.green)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Как делим наличные?', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                  const SizedBox(height: 12),
                  
                  TextField(
                    controller: partner1Controller,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    decoration: const InputDecoration(labelText: 'Доля Партнера 1 (TMT)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person)),
                    onChanged: (val) => setModalState((){}),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: partner2Controller,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    decoration: const InputDecoration(labelText: 'Доля Партнера 2 (TMT)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person)),
                    onChanged: (val) => setModalState((){}),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: reserveController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    decoration: const InputDecoration(labelText: 'В главный сейф/Резерв (TMT)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.account_balance)),
                    onChanged: (val) => setModalState((){}),
                  ),
                  
                  const SizedBox(height: 16),
                  if (remainder < 0)
                    const Text('ОШИБКА: Вы пытаетесь снять больше, чем есть в кассе!', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12))
                  else if (remainder > 0)
                    Text('Останется в кассе на завтра: ${remainder.toStringAsFixed(0)} TMT', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 13))
                  else
                    const Text('Касса будет полностью обнулена', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
            ),
            actions: [
              if (!isSaving)
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена', style: TextStyle(color: Colors.grey))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
                onPressed: (isSaving || remainder < 0 || totalToWithdraw <= 0) ? null : () async {
                  setModalState(() => isSaving = true);
                  try {
                    final prefs = await SharedPreferences.getInstance();
                    final myPhone = prefs.getString('employee_phone') ?? 'admin';
                    final batch = FirebaseFirestore.instance.batch();

                    // Записываем снятие как "расходы" из касс, чтобы обнулить их
                    if (p1 > 0) {
                      batch.set(FirebaseFirestore.instance.collection('financial_transactions').doc(), {
                        'type': 'expense', 'amount': p1, 'description': 'Дивиденды: Партнер 1', 'register': 'Дневная касса (Офис)', 'created_at': FieldValue.serverTimestamp(), 'added_by': myPhone,
                      });
                    }
                    if (p2 > 0) {
                      batch.set(FirebaseFirestore.instance.collection('financial_transactions').doc(), {
                        'type': 'expense', 'amount': p2, 'description': 'Дивиденды: Партнер 2', 'register': 'Дневная касса (Офис)', 'created_at': FieldValue.serverTimestamp(), 'added_by': myPhone,
                      });
                    }
                    if (res > 0) {
                      batch.set(FirebaseFirestore.instance.collection('financial_transactions').doc(), {
                        'type': 'expense', 'amount': res, 'description': 'Перенос в Главный Сейф', 'register': 'Дневная касса (Офис)', 'created_at': FieldValue.serverTimestamp(), 'added_by': myPhone,
                      });
                    }

                    await batch.commit();

                    if (mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Касса успешно распределена и обнулена!'), backgroundColor: Colors.green));
                    }
                  } catch (e) {
                    setModalState(() => isSaving = false);
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red));
                  }
                },
                child: isSaving 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('СНЯТЬ И ОБНУЛИТЬ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: isDark ? Colors.grey[900] : Colors.blueGrey[900],
        foregroundColor: Colors.white,
        title: const Text('Статистика и Финансы', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        actions: [
           IconButton(
             icon: const Icon(Icons.add_shopping_cart, color: Colors.orangeAccent),
             tooltip: 'Быстрый расход',
             onPressed: _showAddTransactionDialog,
           )
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.05), blurRadius: 5, offset: const Offset(0, 2))],
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_month, color: isDark ? Colors.white54 : Colors.blueGrey),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedPeriod,
                      dropdownColor: Theme.of(context).cardColor,
                      isExpanded: true,
                      icon: Icon(Icons.keyboard_arrow_down, color: isDark ? Colors.white : Colors.black87),
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
                      items: _periods.map((String p) => DropdownMenuItem<String>(value: p, child: Text(p))).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedPeriod = val);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('orders').where('status', isEqualTo: 'completed').snapshots(),
              builder: (context, ordersSnapshot) {
                
                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('financial_transactions').snapshots(),
                  builder: (context, transSnapshot) {

                    if (ordersSnapshot.connectionState == ConnectionState.waiting || transSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    // --- ДОХОДЫ ---
                    double totalRevenue = 0;
                    double totalPaid = 0; // Все деньги (и нал и безнал)
                    double totalDebt = 0;
                    
                    double cashTotal = 0; // Только НАЛИЧНЫЕ (доходы)
                    double nonCashTotal = 0; // Карта, Безнал, Бонусы (их снять нельзя)

                    int ordersCount = 0;
                    int refillsCount = 0;

                    // --- РАСХОДЫ И ДОЛГИ ---
                    double expensesCash = 0; // Траты из дневной и выездной кассы (НАЛИЧНЫМИ)
                    double expensesGlobal = 0; // Траты безналом
                    double totalLiabilities = 0; // Взято под реализацию

                    if (ordersSnapshot.hasData) {
                      for (var doc in ordersSnapshot.data!.docs) {
                        final data = doc.data() as Map<String, dynamic>;
                        final completedAt = data['completed_at'] as Timestamp?;
                        
                        if (_isWithinPeriod(completedAt)) {
                          ordersCount++;

                          double price = double.tryParse(data['price']?.toString() ?? '0') ?? 0;
                          double paid = double.tryParse(data['paid_amount']?.toString() ?? price.toString()) ?? 0;
                          double debt = double.tryParse(data['debt_amount']?.toString() ?? '0') ?? 0;
                          
                          int refills = data['added_refills'] ?? 0;

                          totalRevenue += price;
                          totalPaid += paid;
                          totalDebt += debt;
                          refillsCount += refills;

                          // РАЗДЕЛЕНИЕ НАЛА И БЕЗНАЛА
                          String method = (data['payment_method'] ?? 'Наличные').toString().toLowerCase();
                          if (method.contains('карта') || method.contains('терминал') || method.contains('перечисл') || method.contains('бонус')) {
                            nonCashTotal += paid;
                          } else {
                            cashTotal += paid; // Это наличка
                          }
                        }
                      }
                    }

                    if (transSnapshot.hasData) {
                      for (var doc in transSnapshot.data!.docs) {
                        final data = doc.data() as Map<String, dynamic>;
                        final createdAt = data['created_at'] as Timestamp?;
                        
                        if (_isWithinPeriod(createdAt)) {
                          double amount = double.tryParse(data['amount']?.toString() ?? '0') ?? 0;
                          String type = data['type'] ?? 'expense';
                          String register = data['register'] ?? '';

                          if (type == 'expense') {
                            if (register.contains('Глобальная')) {
                              expensesGlobal += amount;
                            } else {
                              // Траты из Дневной и Выездной - это траты НАЛИЧКИ
                              expensesCash += amount; 
                            }
                          } else if (type == 'liability') {
                            totalLiabilities += amount; 
                          }
                        }
                      }
                    }

                    // --- ФАКТИЧЕСКАЯ КАССА (ТОЛЬКО НАЛ) ДЛЯ ДЕЛЕЖКИ ---
                    double actualCashOnHand = cashTotal - expensesCash;

                    return ListView(
                      padding: EdgeInsets.only(left: 16.0, right: 16.0, top: 16.0, bottom: MediaQuery.of(context).padding.bottom + 80),
                      children: [
                        // БЛОК 1: ОБЩАЯ СВОДКА ВСЕХ ДЕНЕГ
                        const Text('СВОДКА (НАЛ + БЕЗНАЛ)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(child: _buildMetricCard(title: 'ФАКТ. ПОЛУЧЕНО', amount: totalPaid, icon: Icons.account_balance_wallet, color: Colors.blue, isDark: isDark)),
                            const SizedBox(width: 12),
                            Expanded(child: _buildMetricCard(title: 'Долги клиентов', amount: totalDebt, icon: Icons.warning_amber_rounded, color: Colors.orange, isDark: isDark)),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // БЛОК 2: ЖИВЫЕ НАЛИЧНЫЕ ДЛЯ РАСЧЕТА
                        const Text('ЖИВАЯ КАССА (НАЛИЧНЫЕ)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green, letterSpacing: 1.2)),
                        const SizedBox(height: 8),
                        Card(
                          elevation: 1,
                          color: Theme.of(context).cardColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.green.withOpacity(0.5))),
                          child: Column(
                            children: [
                              _buildPaymentRow('Пришло наличными', cashTotal, Icons.monetization_on, Colors.green, isDark),
                              Divider(height: 1, color: isDark ? Colors.grey[800] : Colors.grey.shade200),
                              _buildPaymentRow('Расходы (Офис+Выезд)', expensesCash, Icons.money_off, Colors.red[400]!, isDark, isMinus: true),
                              Container(
                                decoration: BoxDecoration(color: isDark ? Colors.green[900]?.withOpacity(0.3) : Colors.green[50], borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16))),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      Text('ОСТАТОК КАССЫ СЕЙЧАС', style: TextStyle(color: isDark ? Colors.white70 : Colors.blueGrey, fontWeight: FontWeight.bold, fontSize: 12)),
                                      const SizedBox(height: 4),
                                      Text('${actualCashOnHand.toStringAsFixed(0)} TMT', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.green[800])),
                                      const SizedBox(height: 16),
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.deepPurple,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                                        ),
                                        onPressed: () => _showCalculateDividendsDialog(actualCashOnHand), 
                                        icon: const Icon(Icons.calculate), 
                                        label: const Text('РАССЧИТАТЬ И ОБНУЛИТЬ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15))
                                      )
                                    ],
                                  ),
                                ),
                              )
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // БЛОК 3: БЕЗНАЛ И СЧЕТА
                        const Text('ВИРТУАЛЬНЫЕ СЧЕТА (БЕЗНАЛ)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
                        const SizedBox(height: 8),
                        Card(
                          elevation: 1,
                          color: Theme.of(context).cardColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey.shade200)),
                          child: Column(
                            children: [
                              _buildPaymentRow('Карта / Перечисление / Бонусы', nonCashTotal, Icons.credit_card, Colors.blue, isDark),
                              Divider(height: 1, color: isDark ? Colors.grey[800] : Colors.grey.shade200),
                              _buildPaymentRow('Расходы по безналу', expensesGlobal, Icons.credit_card_off, Colors.red[400]!, isDark, isMinus: true),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // БЛОК 4: НАШИ ДОЛГИ 
                        const Text('ОБЯЗАТЕЛЬСТВА', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
                        const SizedBox(height: 8),
                        _buildMetricCard(title: 'НАШИ ДОЛГИ (ПОД РЕАЛИЗАЦИЮ)', amount: totalLiabilities, icon: Icons.inventory, color: Colors.deepPurple, isDark: isDark, isLarge: true),

                      ],
                    );
                  }
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({required String title, required double amount, required IconData icon, required Color color, required bool isDark, bool isLarge = false}) {
    return Card(
      elevation: isLarge ? 2 : 1,
      color: isLarge ? (isDark ? color.withOpacity(0.2) : color.withOpacity(0.1)) : Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: isLarge ? color.withOpacity(0.5) : (isDark ? Colors.grey[800]! : Colors.grey.shade200))),
      child: Padding(
        padding: EdgeInsets.all(isLarge ? 20.0 : 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: isDark && !isLarge ? color.withOpacity(0.8) : color, size: isLarge ? 28 : 20),
                const SizedBox(width: 8),
                Expanded(child: Text(title, style: TextStyle(color: isDark ? Colors.white70 : Colors.blueGrey, fontWeight: FontWeight.bold, fontSize: isLarge ? 14 : 12))),
              ],
            ),
            SizedBox(height: isLarge ? 12 : 8),
            Text(
              '${amount.toStringAsFixed(0)} TMT', 
              style: TextStyle(fontSize: isLarge ? 28 : 20, fontWeight: FontWeight.w900, color: isLarge ? (isDark ? Colors.white : color) : (isDark ? Colors.white : Colors.black87))
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentRow(String title, double amount, IconData icon, Color color, bool isDark, {bool isMinus = false}) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: isDark ? color.withOpacity(0.2) : color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : Colors.black87)),
      trailing: Text(
        '${isMinus && amount > 0 ? '-' : ''}${amount.toStringAsFixed(0)} TMT', 
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white70 : Colors.black87)
      ),
    );
  }
}

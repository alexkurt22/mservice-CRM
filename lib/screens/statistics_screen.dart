import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  String _selectedPeriod = 'За 30 дней';
  final List<String> _periods = ['Сегодня', 'За 7 дней', 'За 30 дней', 'За всё время'];

  // Фильтрация дат (чтобы не требовать сложных индексов в Firebase, фильтруем локально)
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: isDark ? Colors.grey[900] : Colors.blueGrey[900],
        foregroundColor: Colors.white,
        title: const Text('Статистика и Финансы', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          // --- ПАНЕЛЬ ВЫБОРА ПЕРИОДА ---
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

          // --- ОСНОВНОЙ КОНТЕНТ (СТАТИСТИКА) ---
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              // Берем только завершенные заказы
              stream: FirebaseFirestore.instance.collection('orders').where('status', isEqualTo: 'completed').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Text('Нет данных за этот период', style: TextStyle(color: isDark ? Colors.white54 : Colors.grey)),
                  );
                }

                // Переменные для подсчета
                double totalRevenue = 0;
                double totalPaid = 0;
                double totalDebt = 0;
                
                double cashTotal = 0;
                double cardTotal = 0;
                double transferTotal = 0;
                double bonusTotal = 0;

                int ordersCount = 0;
                int refillsCount = 0;

                // Обработка документов
                for (var doc in snapshot.data!.docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final completedAt = data['completed_at'] as Timestamp?;
                  
                  if (_isWithinPeriod(completedAt)) {
                    ordersCount++;

                    // Парсим суммы
                    double price = double.tryParse(data['price']?.toString() ?? '0') ?? 0;
                    double paid = double.tryParse(data['paid_amount']?.toString() ?? price.toString()) ?? 0;
                    double debt = double.tryParse(data['debt_amount']?.toString() ?? '0') ?? 0;
                    
                    int refills = data['added_refills'] ?? 0;

                    totalRevenue += price;
                    totalPaid += paid;
                    totalDebt += debt;
                    refillsCount += refills;

                    // Разбивка по кассам (смотрим на payment_method)
                    String method = (data['payment_method'] ?? 'Наличные').toString().toLowerCase();
                    if (method.contains('карта') || method.contains('терминал')) {
                      cardTotal += paid;
                    } else if (method.contains('перечисл')) {
                      transferTotal += paid;
                    } else if (method.contains('бонус')) {
                      bonusTotal += paid;
                    } else {
                      cashTotal += paid; // По умолчанию наличные
                    }
                  }
                }

                if (ordersCount == 0) {
                  return Center(
                    child: Text('Нет завершенных заказов за выбранный период', style: TextStyle(color: isDark ? Colors.white54 : Colors.grey)),
                  );
                }

                return ListView(
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    // БЛОК 1: ГЛАВНЫЕ ФИНАНСЫ
                    const Text('ОБЩИЕ ПОКАЗАТЕЛИ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricCard(
                            title: 'Общая сумма',
                            amount: totalRevenue,
                            icon: Icons.account_balance_wallet,
                            color: Colors.blue,
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildMetricCard(
                            title: 'Долги клиентов',
                            amount: totalDebt,
                            icon: Icons.warning_amber_rounded,
                            color: Colors.red,
                            isDark: isDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildMetricCard(
                      title: 'ФАКТИЧЕСКИ ПОЛУЧЕНО',
                      amount: totalPaid,
                      icon: Icons.payments,
                      color: Colors.green,
                      isDark: isDark,
                      isLarge: true,
                    ),

                    const SizedBox(height: 24),

                    // БЛОК 2: РАЗБИВКА ПО ТИПАМ ОПЛАТ (КАССЫ)
                    const Text('РАЗБИВКА ПО ТИПАМ ОПЛАТ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
                    const SizedBox(height: 8),
                    Card(
                      elevation: 1,
                      color: Theme.of(context).cardColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey.shade200)),
                      child: Column(
                        children: [
                          _buildPaymentRow('Наличные', cashTotal, Icons.money, Colors.green, isDark),
                          Divider(height: 1, color: isDark ? Colors.grey[800] : Colors.grey.shade200),
                          _buildPaymentRow('Банковская карта', cardTotal, Icons.credit_card, Colors.blue, isDark),
                          Divider(height: 1, color: isDark ? Colors.grey[800] : Colors.grey.shade200),
                          _buildPaymentRow('Перечисление (Юр. лица)', transferTotal, Icons.account_balance, Colors.purple, isDark),
                          Divider(height: 1, color: isDark ? Colors.grey[800] : Colors.grey.shade200),
                          _buildPaymentRow('Оплачено Бонусами', bonusTotal, Icons.stars_rounded, Colors.orange, isDark),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // БЛОК 3: ПРОИЗВОДИТЕЛЬНОСТЬ
                    const Text('ПРОИЗВОДИТЕЛЬНОСТЬ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Card(
                            color: isDark ? Colors.grey[800] : Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey.shade200)),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                children: [
                                  Icon(Icons.check_circle, color: isDark ? Colors.teal[300] : Colors.teal, size: 32),
                                  const SizedBox(height: 8),
                                  Text('$ordersCount', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                                  Text('Закрыто заказов', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.blueGrey)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Card(
                            color: isDark ? Colors.grey[800] : Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey.shade200)),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                children: [
                                  Icon(Icons.print, color: isDark ? Colors.orange[300] : Colors.orange, size: 32),
                                  const SizedBox(height: 8),
                                  Text('$refillsCount', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                                  Text('Заправлено картр.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.blueGrey)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Вспомогательный виджет карточки
  Widget _buildMetricCard({required String title, required double amount, required IconData icon, required Color color, required bool isDark, bool isLarge = false}) {
    return Card(
      elevation: isLarge ? 2 : 1,
      color: isLarge ? (isDark ? color.withOpacity(0.2) : color.withOpacity(0.1)) : Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16), 
        side: BorderSide(color: isLarge ? color.withOpacity(0.5) : (isDark ? Colors.grey[800]! : Colors.grey.shade200))
      ),
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
              style: TextStyle(
                fontSize: isLarge ? 28 : 20, 
                fontWeight: FontWeight.w900, 
                color: isLarge ? (isDark ? Colors.white : color) : (isDark ? Colors.white : Colors.black87)
              )
            ),
          ],
        ),
      ),
    );
  }

  // Вспомогательный виджет строчки с кассой
  Widget _buildPaymentRow(String title, double amount, IconData icon, Color color, bool isDark) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: isDark ? color.withOpacity(0.2) : color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : Colors.black87)),
      trailing: Text(
        '${amount.toStringAsFixed(0)} TMT', 
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white70 : Colors.black87)
      ),
    );
  }
}

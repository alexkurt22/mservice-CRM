import 'package:flutter/material.dart';
import '../services/monitoring_service.dart';

class StatsScreen extends StatefulWidget {
  @override
  _StatsScreenState createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  Map<String, int>? _stats;
  bool _isLoading = true;

  final int freeReadsLimit = 50000;
  final int freeWritesLimit = 20000;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    final stats = await MonitoringService.getTodayUsage();
    setState(() {
      _stats = stats;
      _isLoading = false;
    });
  }

  Widget _buildStatCard(String title, int current, int limit, IconData icon) {
    if (current == -1) {
      return ListTile(
        leading: Icon(icon, color: Colors.grey),
        title: Text(title),
        subtitle: Text('Данные недоступны (Проверьте IAM права)'),
      );
    }

    double percent = current / limit;
    Color progressColor = Colors.green;
    if (percent > 0.7) progressColor = Colors.orange;
    if (percent > 0.9) progressColor = Colors.red;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: progressColor),
                SizedBox(width: 10),
                Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Spacer(),
                Text('$current / $limit', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            SizedBox(height: 12),
            LinearProgressIndicator(
              value: percent > 1.0 ? 1.0 : percent,
              backgroundColor: Colors.grey[300],
              color: progressColor,
              minHeight: 10,
            ),
            SizedBox(height: 8),
            Text(
              'Осталось бесплатных: ${limit - current > 0 ? limit - current : 0}',
              style: TextStyle(color: Colors.grey[700], fontSize: 12),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Здоровье БД (Лимиты)'),
        backgroundColor: Colors.blueGrey[900],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadStats,
          )
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.only(top: 16),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    'Статистика за сегодня (UTC)',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ),
                _buildStatCard('Чтения (Reads)', _stats!['reads'] ?? 0, freeReadsLimit, Icons.chrome_reader_mode),
                _buildStatCard('Записи (Writes)', _stats!['writes'] ?? 0, freeWritesLimit, Icons.edit_document),
                _buildStatCard('Удаления (Deletes)', _stats!['deletes'] ?? 0, freeWritesLimit, Icons.delete_outline),
                
                SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200)
                    ),
                    child: Text(
                      '💡 Эти данные запрашиваются напрямую у серверов Google Cloud и не расходуют ваши лимиты базы данных.',
                      style: TextStyle(color: Colors.blue[800], fontSize: 13),
                    ),
                  ),
                )
              ],
            ),
    );
  }
}


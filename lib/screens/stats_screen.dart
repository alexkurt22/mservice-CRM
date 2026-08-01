import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:googleapis/monitoring/v3.dart' as monitoring;

class StatsScreen extends StatefulWidget {
  const StatsScreen({Key? key}) : super(key: key);

  @override
  _StatsScreenState createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  Map<String, int>? _stats;
  bool _isLoading = true;

  // Firebase Spark (Бесплатный тариф) Лимиты в день
  final int freeReadsLimit = 50000;
  final int freeWritesLimit = 20000;
  final int freeDeletesLimit = 20000;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    final stats = await MonitoringService.getTodayUsage();
    if (mounted) {
      setState(() {
        _stats = stats;
        _isLoading = false;
      });
    }
  }

  Widget _buildStatCard(String title, int current, int limit, IconData icon) {
    if (current == -1) {
      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          leading: Icon(icon, color: Colors.grey),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: const Text('Ошибка подключения к API мониторинга'),
        ),
      );
    }

    double percent = limit > 0 ? (current / limit) : 0.0;
    Color progressColor = Colors.green;
    if (percent > 0.7) progressColor = Colors.orange;
    if (percent > 0.9) progressColor = Colors.red;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: progressColor),
                const SizedBox(width: 10),
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                Text('$current / $limit', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: percent > 1.0 ? 1.0 : percent,
              backgroundColor: Colors.grey[300],
              color: progressColor,
              minHeight: 10,
            ),
            const SizedBox(height: 8),
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
        title: const Text('Лимиты и Расходы БД', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.teal[800],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStats,
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.teal))
          : ListView(
              padding: const EdgeInsets.only(top: 16, bottom: 40),
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    'Статистика базы данных за сегодня (UTC)',
                    style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.bold),
                  ),
                ),
                _buildStatCard('Чтения (Reads)', _stats!['reads'] ?? 0, freeReadsLimit, Icons.chrome_reader_mode),
                _buildStatCard('Записи (Writes)', _stats!['writes'] ?? 0, freeWritesLimit, Icons.edit_document),
                _buildStatCard('Удаления (Deletes)', _stats!['deletes'] ?? 0, freeDeletesLimit, Icons.delete_outline),
                
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.teal[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.teal.shade200)
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.lightbulb_outline, color: Colors.teal[700]),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Эти данные запрашиваются напрямую у серверов Google Cloud API и не расходуют ваши лимиты базы данных.',
                            style: TextStyle(color: Colors.teal[800], fontSize: 13, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              ],
            ),
    );
  }
}

/// Сервисный класс
class MonitoringService {
  static const String projectId = 'mserviceapp-79557'; 

  static Future<Map<String, int>> getTodayUsage() async {
    try {
      // 1. Загружаем сервисный аккаунт
      final String response = await rootBundle.loadString('assets/firebase_credentials.json');
      final Map<String, dynamic> credentialsJson = json.decode(response);
      final credentials = ServiceAccountCredentials.fromJson(credentialsJson);

      // 2. Получаем доступ к Cloud Monitoring
      final client = await clientViaServiceAccount(
          credentials, [monitoring.MonitoringApi.monitoringReadScope]);
      final monitoringApi = monitoring.MonitoringApi(client);

      // 3. Высчитываем интервал с начала сегодняшнего дня по UTC
      final now = DateTime.now().toUtc();
      final startOfDay = DateTime.utc(now.year, now.month, now.day);
      
      final startTime = '${startOfDay.toIso8601String()}Z';
      final endTime = '${now.toIso8601String()}Z';

      // 4. Безопасная функция запроса метрик (без сервеной агрегации)
      Future<int> fetchMetric(String metricType) async {
        try {
          final response = await monitoringApi.projects.timeSeries.list(
            'projects/$projectId',
            filter: 'metric.type="firestore.googleapis.com/document/$metricType"',
            interval_startTime: startTime,
            interval_endTime: endTime,
          );

          int totalCount = 0;
          if (response.timeSeries != null && response.timeSeries!.isNotEmpty) {
            for (var series in response.timeSeries!) {
              if (series.points != null) {
                for (var point in series.points!) {
                  if (point.value?.int64Value != null) {
                    totalCount += int.parse(point.value!.int64Value!);
                  }
                }
              }
            }
          }
          return totalCount;
        } catch (e) {
          debugPrint("Ошибка сбора метрики $metricType: $e");
          return 0; // Если метрик за сегодня еще нет, возвращаем 0
        }
      }

      // 5. Собираем данные
      int reads = await fetchMetric('read_count');
      int writes = await fetchMetric('write_count');
      int deletes = await fetchMetric('delete_count');

      client.close();
      return {'reads': reads, 'writes': writes, 'deletes': deletes};

    } catch (e) {
      debugPrint("Ошибка при получении метрик: $e");
      return {'reads': -1, 'writes': -1, 'deletes': -1};
    }
  }
}



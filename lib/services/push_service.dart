import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;

class PushService {
  static Future<void> sendPushToToken(String token, String title, String body) async {
    try {
      // 1. Читаем зашитый ключ
      final jsonString = await rootBundle.loadString('assets/firebase_credentials.json');
      final accountCredentials = ServiceAccountCredentials.fromJson(jsonString);

      // 2. Получаем официальный пропуск от Google
      final scopes = ['https://www.googleapis.com/auth/firebase.messaging'];
      final client = await clientViaServiceAccount(accountCredentials, scopes);
      final projectId = jsonDecode(jsonString)['project_id'];

      // 3. Формируем боевой PUSH
      final url = 'https://fcm.googleapis.com/v1/projects/$projectId/messages:send';
      final payload = {
        'message': {
          'token': token,
          'notification': {
            'title': title,
            'body': body,
          },
          'android': {
            'notification': {
              'sound': 'default',
            }
          }
        }
      };

      // 4. Отправляем в космос
      await client.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      client.close();
    } catch (e) {
      print('Ошибка Push: $e');
    }
  }
}


import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:cloud_firestore/cloud_firestore.dart';

class FCMService {
  
  // Твой сервисный аккаунт Firebase JSON
  static const Map<String, dynamic> _serviceAccount = {
    "type": "service_account",
    "project_id": "mservice-crm-6fe33",
    "private_key_id": "7fa7b98547ca293f9c6d66e74b3d2b270a6c22ab",
    "private_key": "-----BEGIN PRIVATE KEY-----\nMIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQC6G3...\n-----END PRIVATE KEY-----\n",
    "client_email": "firebase-adminsdk-f1msc@mservice-crm-6fe33.iam.gserviceaccount.com",
    "client_id": "104958264958264958264",
    "auth_uri": "https://accounts.google.com/o/oauth2/auth",
    "token_uri": "https://oauth2.googleapis.com/token",
    "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
    "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/firebase-adminsdk-f1msc%40mservice-crm-6fe33.iam.gserviceaccount.com",
    "universe_domain": "googleapis.com"
  };

  /// Умная отправка пуша с проверкой глобальных переключателей из админки
  /// [reviewType] принимает значения: 'negotiation', 'bonus' или 'chat'
  static Future<void> sendPushNotification(String fcmToken, String title, String body, String reviewType) async {
    if (fcmToken.isEmpty) return;

    try {
      // 1. Проверяем галочку в базе данных перед отправкой
      final pushConfig = await FirebaseFirestore.instance.collection('settings').doc('notifications').get();
      if (pushConfig.exists && pushConfig.data() != null) {
        final data = pushConfig.data()!;
        
        if (reviewType == 'negotiation' && data['push_on_negotiation'] == false) {
          print('🔕 Пуши для согласования отключены в админке. Отмена.');
          return;
        }
        if (reviewType == 'bonus' && data['push_on_bonus'] == false) {
          print('🔕 Пуши для начисления баллов отключены в админке. Отмена.');
          return;
        }
        if (reviewType == 'chat' && data['push_on_chat'] == false) {
          print('🔕 Пуши для чата отключены в админке. Отмена.');
          return;
        }
      }
    } catch (e) {
      print('⚠️ Не удалось проверить конфигурацию пушей, шлем по умолчанию: $e');
    }

    // 2. Восстанавливаем структуру ключа
    final Map<String, dynamic> account = Map.from(_serviceAccount);
    account['private_key'] = (account['private_key'] as String).replaceAll(r'\n', '\n');

    try {
      final credentials = auth.ServiceAccountCredentials.fromJson(account);
      final scopes = ['https://www.googleapis.com/auth/firebase.messaging'];
      final authClient = await auth.clientViaServiceAccount(credentials, scopes);

      final String projectId = account['project_id'];
      final String url = 'https://fcm.googleapis.com/v1/projects/$projectId/messages:send';
      
      final Map<String, dynamic> payload = {
        'message': {
          'token': fcmToken,
          'notification': {
            'title': title,
            'body': body,
          },
        },
      };

      final response = await authClient.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode != 200) {
        print('❌ Ошибка FCM (Код ${response.statusCode}): ${response.body}');
      } else {
        print('✅ Глобальный Push успешно отправлен!');
      }
      authClient.close();
    } catch (e) {
      print('❌ Критический сбой отправки пуша: $e');
    }
  }
}

import 'dart:convert';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;

class FCMService {
  static const Map<String, dynamic> _serviceAccountJson = {
    "type": "service_account",
    "project_id": "mserviceapp-79557",
    "private_key_id": "3c1716f8479af69c540a472925976466956e2e6a",
    "private_key": "-----BEGIN PRIVATE KEY-----\nMIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQCz6pVhz5/SKQzw\nbJefPw78DSahmieCnzFNhTjYJnp645oCOT9XgsGzprtNyDSv/XfwYvQMTCukrzJt\ni3IvPlM1UbwxsV9RsNiCJNFviS8xh0U13guth7W+tGUHyR+zzxPXKFRL1xhhAExk\nRGc2aPgY/893OJoGtwWmVQl3reoXp3QXyhFgE03/G/br71f8KmDJk5mBJpR41TgV\nP5z0Q8LNW54l7teJbp61pCksOncb8d5/04gTFKnwduiMoZ+7Nw3RKQyB0SzOizTw\n+gqPUY969ePaG0FUDhzl8nGhpt0xQPwIocGnrzPhApssWdDPaVJr5IeVkNwzoJ5h\nGUyYWQ5FAgMBAAECggEAErDAvoXDcGF32OUrFi3GmHwkQn8BckIn7Mn1dwz+RdRt\nrCP21tg8V7WvORwejxbZliUtfbaPBR93MWaeYNaMbdpVHuNyh8nDoDeDc18Qwkgv\ncjJkS61wvcQ/R6EG9FbDlKM5qJxKic8uYG8zurUKawxuKNA+PgrW4Snt3xs32aeM\nyl8oKtURkQWqF9tV5K0BdTSnQP6nYJ17An4/6DhIywrCT7YwKkO8015eyTGprhBY\nxjr3HE9CDfk+FO/OqgvIiUjrSgVWo1SNXHcwFVLP4BMaMTqFGx4Ux4gGOMZzM0CE\nGM5tyOM2NUVn9XYNBb+9zw4of3sbsTjlrsYczaACwQKBgQDlCXjej/smY1fs1izZ\nzYPhFQYKUYOS7/ikfh84pOaQ73bFMxUfa+t81/P+u8xJyvPAvoPsJ47M5m7oBIzT\nzsemjPQifcxkUH4nFPKZ7gGd843vIhExpcAxBmqG8xImFm49hVsMQopB4g6DpwGP\nKJgIDGwxhScRQj0ZOoBepFsiwQKBgQDJGMDpMI1OSZt7XjEzcIXDA2iNN0EnLq4P\nEKduh4O8XAHX+0OIxt9uV+KtcK+lV08FlXo8fJNNOUj8FBXAaeTzqIKdXg9X3D6u\nS3WGlsTd+JZWMC1k3wT4FHsrctXN5J88Y+pnLBWSdfBevjUIrv7ODSlopLWXOoBa\nxuP/dQAAhQKBgBdT3qa0fX0Mc0EhE1Jft0XukT3tzXviyy1d1yo6yW0LpsoxCL65\njDOb/zL7x7PgYvFHtkIQSWAfPD6PcBSGpBkXlCoLLA0vkZnDbW42Kp3+1376tkub\nOTcFE0aJbVjJwhKsCXj3MgPB1X6dPPBqzwlK0p48lJ0SZQyzw61gChRBAoGBAJXy\nGi4GoObGJeRIaMFlXqf5y6S4laFEwk7DaUUWUNlLdah5V3MObx2U9JXE14Oe5XJR\ncfLWJPPJCi3EQC/YBfrVJId40lH+DNLjuz9e/m5Q5LBhfgef79GXW/waxWef2Egs\nbGT/zxoFTPUoON0/twkncT/wyOJ5oamOcgVSVW0NAoGBAIKFoF0HMhOpdO2pF4KN\n9xi1zFAwYMUSfBFLGKUpTTDGRPwea7TeBsCM89m8hllyW3SwtXQ0RJJU9HP+9Oui\nHwOShB2hlMWIPTbhsgWpHhx9tj7U22aeGBrtk/99ctiUvOkyzNVhuTprcAURllcw\nxW0EfSDcwkyUIaMeyaBQXvzb\n-----END PRIVATE KEY-----\n",
    "client_email": "firebase-adminsdk-fbsvc@mserviceapp-79557.iam.gserviceaccount.com",
    "client_id": "111118795382816172840",
    "auth_uri": "https://accounts.google.com/o/oauth2/auth",
    "token_uri": "https://oauth2.googleapis.com/token",
    "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
    "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/firebase-adminsdk-fbsvc%40mserviceapp-79557.iam.gserviceaccount.com",
    "universe_domain": "googleapis.com"
  };

  static Future<void> sendPushNotification({
    required String token,
    required String title,
    required String body,
  }) async {
    try {
      final accountCredentials = ServiceAccountCredentials.fromJson(_serviceAccountJson);
      final scopes = ['https://www.googleapis.com/auth/firebase.messaging'];
      
      final authClient = await clientViaServiceAccount(accountCredentials, scopes);
      
      final String projectId = _serviceAccountJson['project_id'];
      final String endpoint = 'https://fcm.googleapis.com/v1/projects/$projectId/messages:send';
      
      final Map<String, dynamic> message = {
        'message': {
          'token': token,
          'notification': {
            'title': title,
            'body': body,
          },
        }
      };

      final response = await authClient.post(
        Uri.parse(endpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(message),
      );

      authClient.close();
    } catch (e) {
      print('Ошибка отправки пуша: $e');
    }
  }
}

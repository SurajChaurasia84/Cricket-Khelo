import 'dart:convert';
import 'package:http/http.dart' as http;

class FCMService {
  // IMPORTANT: For production, sending notifications should be handled by a backend (Cloud Functions).
  // Directly using the Server Key in the app is not secure, but works for prototypes.
  static const String _serverKey = 'YOUR_SERVER_KEY_HERE'; 
  static const String _fcmUrl = 'https://fcm.googleapis.com/fcm/send';

  static Future<void> sendNotification({
    required String toToken,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    if (_serverKey == 'YOUR_SERVER_KEY_HERE') {
      print("FCM Error: Server Key not set. Please add your FCM Server Key.");
      return;
    }

    try {
      final response = await http.post(
        Uri.parse(_fcmUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'key=$_serverKey',
        },
        body: jsonEncode({
          'notification': {
            'title': title,
            'body': body,
            'click_action': 'FLUTTER_NOTIFICATION_CLICK',
            'android_channel_id': 'high_importance_channel',
          },
          'priority': 'high',
          'data': data ?? {},
          'to': toToken,
        }),
      );

      if (response.statusCode == 200) {
        print("FCM Success: Notification sent to $toToken");
      } else {
        print("FCM Error: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      print("FCM Exception: $e");
    }
  }

  // Helper to send to a list of tokens (e.g. for regional invites)
  static Future<void> sendToMultiple({
    required List<String> tokens,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    for (String token in tokens) {
      if (token.isNotEmpty) {
        await sendNotification(toToken: token, title: title, body: body, data: data);
      }
    }
  }
}

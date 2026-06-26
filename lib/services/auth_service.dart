import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'api_service.dart';

class AuthExchangeResult {
  const AuthExchangeResult._({required this.success, this.message});

  const AuthExchangeResult.success() : this._(success: true);

  const AuthExchangeResult.failure(String message)
      : this._(success: false, message: message);

  final bool success;
  final String? message;
}

class AuthService {
  /// เรียกหลัง Firebase login/signup สำเร็จ
  /// แลก Firebase ID Token เป็น JWT ของระบบเรา
  static Future<AuthExchangeResult> exchangeToken(User user) async {
    try {
      final idToken = await user.getIdToken(true);
      if (idToken == null) {
        return const AuthExchangeResult.failure('ไม่สามารถรับ Firebase token ได้');
      }

      final response = await ApiService.postPublic(
        '/auth/token',
        {'firebase_token': idToken},
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        await ApiService.setToken(json['access_token'] as String);
        return const AuthExchangeResult.success();
      }

      if (response.statusCode == 401) {
        return const AuthExchangeResult.failure(
          'ยืนยันตัวตนกับเซิร์ฟเวอร์ไม่สำเร็จ กรุณาลองใหม่หรือติดต่อผู้ดูแลระบบ',
        );
      }

      return AuthExchangeResult.failure(
        'เซิร์ฟเวอร์ตอบกลับผิดพลาด (${response.statusCode})',
      );
    } catch (_) {
      return const AuthExchangeResult.failure('ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้');
    }
  }

  static Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
    await ApiService.clearToken();
    try {
      final googleSignIn = GoogleSignIn();
      if (await googleSignIn.isSignedIn()) {
        await googleSignIn.disconnect();
      }
    } catch (_) {}
  }
}

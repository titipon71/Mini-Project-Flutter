import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'api_service.dart';

class AuthService {
  /// เรียกหลัง Firebase login/signup สำเร็จ
  /// แลก Firebase ID Token เป็น JWT ของระบบเรา
  static Future<bool> exchangeToken(User user) async {
    try {
      final idToken = await user.getIdToken(true);
      final response = await ApiService.postPublic(
        '/auth/token',
        {'firebase_token': idToken!},
      );
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        await ApiService.setToken(json['access_token'] as String);
        return true;
      }
      return false;
    } catch (_) {
      return false;
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

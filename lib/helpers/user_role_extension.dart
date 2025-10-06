import 'package:firebase_auth/firebase_auth.dart';

/// ฟังก์ชันอ่าน claims (vip, admin) ของผู้ใช้ปัจจุบัน
Future<Map<String, dynamic>> readClaims() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return {}; // ถ้ายังไม่ล็อกอิน

  // 🔄 รีเฟรช token เพื่อให้ได้ claims ล่าสุด
  final idTokenResult = await user.getIdTokenResult(true);

  // 🔍 ดึงค่าออกมาจาก claims
  final claims = idTokenResult.claims ?? {};

  return {
    'isVIP': claims['vip'] == true,
    'isAdmin': claims['admin'] == true,
  };
}

/// Extension เพิ่ม method isAdmin() และ isVIP() ให้กับ User ของ Firebase
extension UserX on User {
  /// ตรวจว่า user เป็น Admin หรือไม่
  Future<bool> isAdmin({bool refresh = true}) async {
    final token = await getIdTokenResult(refresh);
    return token.claims?['admin'] == true;
  }

  /// ตรวจว่า user เป็น VIP หรือไม่
  Future<bool> isVIP({bool refresh = true}) async {
    final token = await getIdTokenResult(refresh);
    return token.claims?['vip'] == true;
  }
}

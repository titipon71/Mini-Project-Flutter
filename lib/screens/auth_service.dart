import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final _auth = FirebaseAuth.instance;

  Future<Map<String, dynamic>> getUserClaims({bool forceRefresh = false}) async {
    final user = _auth.currentUser;
    if (user == null) return {};
    if (forceRefresh) await user.getIdTokenResult(true);
    final result = await user.getIdTokenResult();
    return result.claims ?? {};
  }

  Future<bool> isAdmin() async {
    final claims = await getUserClaims();
    return claims['admin'] == true;
  }

  Future<bool> isVIP() async {
    final claims = await getUserClaims();
    return claims['vip'] == true || claims['admin'] == true;
  }
}

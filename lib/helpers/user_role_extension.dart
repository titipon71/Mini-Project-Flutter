import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:Twebtoon/services/api_service.dart';

/// Fetch VIP and admin status from the backend API.
Future<Map<String, dynamic>> readRoles() async {
  try {
    final response = await ApiService.get('/api/v1/me/roles');
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return {
        'isVIP': json['vip'] == true,
        'isAdmin': json['admin'] == true,
      };
    }
  } catch (_) {}
  return {'isVIP': false, 'isAdmin': false};
}

extension UserX on User {
  Future<bool> isAdmin({bool refresh = true}) async {
    final roles = await readRoles();
    return roles['isAdmin'] == true;
  }

  Future<bool> isVIP({bool refresh = true}) async {
    final roles = await readRoles();
    return roles['isVIP'] == true;
  }
}

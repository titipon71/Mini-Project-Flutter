import 'dart:convert';
import 'api_service.dart';

/// ดึงสถานะ VIP จาก backend (ครั้งเดียว)
Future<bool> isVip() async {
  try {
    final response = await ApiService.get('/api/v1/me/roles');
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final vip = json['vip'] == true;
      final vipUntil = json['vipUntil'] as String?;
      if (!vip) return false;
      if (vipUntil == null) return true;
      return DateTime.tryParse(vipUntil)?.isAfter(DateTime.now()) ?? false;
    }
  } catch (_) {}
  return false;
}

/// Stream ที่ poll สถานะ VIP ทุก 30 วินาที
Stream<bool> vipStream() async* {
  while (true) {
    yield await isVip();
    await Future.delayed(const Duration(seconds: 30));
  }
}

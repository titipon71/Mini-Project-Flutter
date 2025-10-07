import 'package:cloud_firestore/cloud_firestore.dart';

/// คืนค่า stream ที่แจ้งสถานะ VIP แบบ realtime
Stream<bool> vipStream(String uid) {
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .snapshots()
      .map((s) => (s.data()?['roles']?['vip'] ?? false) as bool);
}

/// คืนค่า VIP แบบครั้งเดียว (future)
Future<bool> isVip(String uid) async {
  final snap =
      await FirebaseFirestore.instance.collection('users').doc(uid).get();
  return (snap.data()?['roles']?['vip'] ?? false) as bool;
}

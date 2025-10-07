// lib/widgets/vip_status_widget.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class VipStatusWidget extends StatelessWidget {
  final String uid;

  const VipStatusWidget({
    Key? key,
    required this.uid,
  }) : super(key: key);

  Stream<bool> _vipStream(String uid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((s) => (s.data()?['roles']?['vip'] ?? false) as bool);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: _vipStream(uid),
      builder: (context, snap) {
        // กำหนดค่าตั้งต้น
        final isVip = snap.data == true;

        // กำลังโหลด
        if (snap.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Chip(
              label: Text(
                isVip ? 'สถานะ: VIP ✅' : 'สถานะ: ยังไม่เป็น VIP',
                style: const TextStyle(color: Colors.white),
              ),
              backgroundColor:
                  isVip ? Colors.green.shade700 : Colors.grey.shade800,
            ),
          ),
        );
      },
    );
  }
}

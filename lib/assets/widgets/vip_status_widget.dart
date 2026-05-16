import 'package:flutter/material.dart';
import 'package:Twebtoon/services/vip_service.dart';

class VipStatusWidget extends StatelessWidget {
  final String uid;

  const VipStatusWidget({
    Key? key,
    required this.uid,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: vipStream(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        final isVipActive = snap.data == true;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Chip(
              label: Text(
                isVipActive ? 'สถานะ: VIP ✅' : 'สถานะ: ยังไม่เป็น VIP',
                style: const TextStyle(color: Colors.white),
              ),
              backgroundColor:
                  isVipActive ? Colors.green.shade700 : Colors.grey.shade800,
            ),
          ),
        );
      },
    );
  }
}

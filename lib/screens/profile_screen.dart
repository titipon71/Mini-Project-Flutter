import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfileScreen extends StatelessWidget {
  // ===== Sign Out Function =====
  Future<void> _signOut(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
      // กลับไปหน้าแรกหรือหน้า login
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      _showSheet(
        context,
        title: 'เกิดข้อผิดพลาด',
        message: 'ไม่สามารถออกจากระบบได้:\n\n${e.toString()}',
      );
    }
  }
  const ProfileScreen({super.key});

  // ===== Helpers: Popups =====
  Future<void> _showSheet(
    BuildContext context, {
    required String title,
    required String message,
    List<Widget> actions = const [],
  }) {
    final cs = Theme.of(context).colorScheme;
    return showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: cs.primary.withOpacity(.12),
                child: Icon(Icons.info_outline, color: cs.primary),
              ),
              title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text(message),
            ),
            const SizedBox(height: 12),
            if (actions.isNotEmpty)
              Row(
                children: [
                  for (int i = 0; i < actions.length; i++) ...[
                    if (i > 0) const SizedBox(width: 12),
                    Expanded(child: actions[i]),
                  ],
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('ปิด'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditDialog(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final nameCtrl = TextEditingController(text: user?.displayName);
    final emailCtrl = TextEditingController(text: user?.email);
    return showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('แก้ไขโปรไฟล์'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'ชื่อ')),
            TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'อีเมล')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('ยกเลิก')),
          FilledButton(onPressed: () => Navigator.pop(context), child: const Text('บันทึก')),
        ],
      ),
    );
  }

  void _onSettingTap(BuildContext context, _SettingItem e) {
    switch (e.title) {
      case 'ความเป็นส่วนตัว':
        _showSheet(context,
          title: 'ความเป็นส่วนตัว',
          message: 'จัดการบัญชีสาธารณะ การค้นพบ และการบล็อก',
          actions: [
            OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('ปิด')),
            FilledButton(onPressed: () {/* ไปหน้า privacy */}, child: const Text('เปิดการตั้งค่า')),
          ],
        );
        break;
      case 'การแจ้งเตือน':
        _showSheet(context,
          title: 'การแจ้งเตือน',
          message: 'เปิด/ปิด Push, Email และสรุปรายวัน',
          actions: [
            OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('ปิด')),
            FilledButton(onPressed: () {/* ไปหน้า notifications */}, child: const Text('จัดการ')),
          ],
        );
        break;
      case 'ธีม':
        _showSheet(context,
          title: 'ธีม',
          message: 'เลือกสว่าง/มืด หรือให้ตามระบบ',
          actions: [
            FilledButton.tonal(onPressed: () {}, child: const Text('สว่าง')),
            FilledButton.tonal(onPressed: () {}, child: const Text('มืด')),
            FilledButton(onPressed: () {}, child: const Text('ตามระบบ')),
          ],
        );
        break;
      case 'ช่วยเหลือ':
        _showSheet(context, title: 'ศูนย์ช่วยเหลือ', message: 'FAQ, คู่มือ และติดต่อทีมงาน');
        break;
      case 'เกี่ยวกับ':
        _showSheet(context, title: 'เกี่ยวกับแอป', message: 'เวอร์ชัน 1.0.0 • © 2025 Your Company');
        break;
      case 'ออกจากระบบ':
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('ยืนยันการออกจากระบบ'),
            content: const Text('คุณแน่ใจหรือไม่ว่าต้องการออกจากระบบ'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('ยกเลิก')),
              FilledButton(
                onPressed: () {
                  Navigator.pop(context); // ปิด dialog ก่อน
                  _signOut(context);
                },
                child: const Text('ออกจากระบบ'),
              ),
            ],
          ),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final user = FirebaseAuth.instance.currentUser;
    return SingleChildScrollView(
      key: const PageStorageKey('profile'),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            children: [
              // Cover
              Container(
                height: 200,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [cs.primary, cs.secondary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                alignment: Alignment.bottomLeft,
                padding: const EdgeInsets.symmetric(vertical: 52.0 ,horizontal: 19),
                child: Text(
                  'โปรไฟล์',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(height: 56),

              // Content
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    Text(user?.displayName ?? "No Name",
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(user?.email ?? "No Email",
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FilledButton.icon(
                          onPressed: () => _showEditDialog(context),
                          icon: const Icon(Icons.edit),
                          label: const Text('แก้ไขโปรไฟล์'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.tonalIcon(
                          onPressed: () => _showSheet(
                            context,
                            title: 'แชร์โปรไฟล์',
                            message: 'คัดลอกลิงก์หรือแชร์ไปยังโซเชียล',
                            actions: [
                              OutlinedButton.icon(
                                onPressed: () {},
                                icon: const Icon(Icons.link),
                                label: const Text('คัดลอกลิงก์'),
                              ),
                              FilledButton.icon(
                                onPressed: () {},
                                icon: const Icon(Icons.share),
                                label: const Text('แชร์เลย'),
                              ),
                            ],
                          ),
                          icon: const Icon(Icons.share),
                          label: const Text('แชร์'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Stats (แตะแล้วมี popup)
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x0D000000),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          _StatTile(
                            value: '128',
                            label: 'โพสต์',
                            onTap: () => _showSheet(
                              context,
                              title: 'โพสต์',
                              message: 'คุณมีโพสต์ทั้งหมด 128 รายการ',
                            ),
                          ),
                          const _DividerY(),
                          _StatTile(
                            value: '2.3K',
                            label: 'ผู้ติดตาม',
                            onTap: () => _showSheet(
                              context,
                              title: 'ผู้ติดตาม',
                              message: 'มีผู้ติดตามล่าสุด +35 ในสัปดาห์นี้',
                            ),
                          ),
                          const _DividerY(),
                          _StatTile(
                            value: '540',
                            label: 'กำลังติดตาม',
                            onTap: () => _showSheet(
                              context,
                              title: 'กำลังติดตาม',
                              message: 'คุณติดตาม 540 บัญชี',
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    _SettingCard(
                      items: const [
                        _SettingItem(icon: Icons.lock, title: 'ความเป็นส่วนตัว'),
                        _SettingItem(icon: Icons.notifications, title: 'การแจ้งเตือน'),
                        _SettingItem(icon: Icons.palette, title: 'ธีม'),
                      ],
                      onItemTap: (e) => _onSettingTap(context, e),
                    ),
                    const SizedBox(height: 12),
                    _SettingCard(
                      items: const [
                        _SettingItem(icon: Icons.help_outline, title: 'ช่วยเหลือ'),
                        _SettingItem(icon: Icons.info_outline, title: 'เกี่ยวกับ'),
                        _SettingItem(icon: Icons.logout, title: 'ออกจากระบบ'),
                      ],
                      onItemTap: (e) => _onSettingTap(context, e),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),

          // Avatar: แตะเพื่อแก้ไขรูป
          Positioned(
            top: 160,
            left: 16,
            child: Material(
              color: Colors.white,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => _showSheet(
                  context,
                  title: 'รูปโปรไฟล์',
                  message: 'เลือกรูปจากแกลเลอรี่หรือถ่ายใหม่',
                  actions: [
                    OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.photo_library),
                      label: const Text('แกลเลอรี่'),
                    ),
                    FilledButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.photo_camera),
                      label: const Text('ถ่ายรูป'),
                    ),
                  ],
                ),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.white,
                    child: CircleAvatar(
                      radius: 36,
                      backgroundImage: NetworkImage(
                        'https://t4.ftcdn.net/jpg/03/64/21/11/360_F_364211147_1qgLVxv1Tcq0Ohz3FawUfrtONzz8nq3e.jpg',
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.value, required this.label, this.onTap});
  final String value;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(color: Colors.grey.shade700)),
            ],
          ),
        ),
      ),
    );
  }
}

class _DividerY extends StatelessWidget {
  const _DividerY();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 40, color: const Color(0x11000000));
  }
}

class _SettingCard extends StatelessWidget {
  const _SettingCard({required this.items, required this.onItemTap});
  final List<_SettingItem> items;
  final void Function(_SettingItem) onItemTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: items
            .map(
              (e) => Column(
                children: [
                  ListTile(
                    leading: Icon(e.icon),
                    title: Text(e.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => onItemTap(e),
                  ),
                  if (e != items.last) const Divider(height: 1),
                ],
              ),
            )
            .toList(),
      ),
    );
  }
}

class _SettingItem {
  final IconData icon;
  final String title;
  const _SettingItem({required this.icon, required this.title});
}

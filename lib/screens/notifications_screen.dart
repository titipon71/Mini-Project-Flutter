import 'package:flutter/material.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final List<_Notif> _items = List.generate(
    10,
    (i) => _Notif(
      id: i.toString(),
      title: 'แจ้งเตือน #${i + 1}',
      timeText: i < 3 ? 'ใหม่เมื่อสักครู่' : 'เมื่อ 2 ชม. ที่แล้ว',
      unread: i < 3,
    ),
  );

  void _markAllRead() {
    setState(() {
      for (final n in _items) {
        n.unread = false;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('ทำเครื่องหมายว่าอ่านทั้งหมดแล้ว')),
    );
  }

  void _toggleRead(_Notif n) {
    setState(() => n.unread = !n.unread);
  }

  void _delete(_Notif n) {
    setState(() => _items.remove(n));
  }

  Future<void> _showDetailSheet(_Notif n) async {
    final cs = Theme.of(context).colorScheme;
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: cs.primary.withOpacity(.12),
                  child: Icon(Icons.notifications, color: cs.primary),
                ),
                title: Text(n.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text(n.timeText),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'รายละเอียดแจ้งเตือนแบบตัวอย่าง\nคุณสามารถใส่ข้อความยาว ๆ หรือ action เฉพาะเคสได้ที่นี่',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _toggleRead(n);
                      },
                      icon: Icon(n.unread ? Icons.mark_email_read : Icons.mark_email_unread),
                      label: Text(n.unread ? 'ทำเป็นอ่านแล้ว' : 'ทำเป็นยังไม่ได้อ่าน'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _delete(n);
                      },
                      icon: const Icon(Icons.delete),
                      label: const Text('ลบแจ้งเตือน'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Text('การแจ้งเตือน',
                  style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const Spacer(),
              FilledButton.tonalIcon(
                onPressed: _markAllRead,
                icon: const Icon(Icons.done_all),
                label: const Text('อ่านทั้งหมด'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              itemCount: _items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final n = _items[index];

                // ปัดขวา -> ทำเป็นอ่านแล้ว, ปัดซ้าย -> ลบ
                return Dismissible(
                  key: ValueKey('notif-${n.id}'),
                  background: _SwipeBg(
                    icon: Icons.done,
                    text: 'อ่านแล้ว',
                    alignment: Alignment.centerLeft,
                  ),
                  secondaryBackground: _SwipeBg(
                    icon: Icons.delete,
                    text: 'ลบ',
                    alignment: Alignment.centerRight,
                  ),
                  confirmDismiss: (direction) async {
                    if (direction == DismissDirection.startToEnd) {
                      _toggleRead(n);
                      return false; // ไม่ลบ แค่อัปเดตสถานะ
                    } else {
                      return await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('ยืนยันการลบ'),
                              content: Text('ต้องการลบ "${n.title}" ใช่ไหม'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ยกเลิก')),
                                FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('ลบ')),
                              ],
                            ),
                          ) ??
                          false;
                    }
                  },
                  onDismissed: (_) => _delete(n),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor, // เข้ากับ Light/Dark
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0D000000),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      leading: Stack(
                        children: [
                          CircleAvatar(
                            backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(.12),
                            child: const Icon(Icons.notification_important),
                          ),
                          if (n.unread)
                            const Positioned(
                              right: 0,
                              top: 0,
                              child: CircleAvatar(radius: 6, backgroundColor: Colors.red),
                            ),
                        ],
                      ),
                      title: Text(
                        n.title,
                        style: TextStyle(fontWeight: n.unread ? FontWeight.w800 : FontWeight.w600),
                      ),
                      subtitle: Text(n.timeText),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _showDetailSheet(n),
                      onLongPress: () => _toggleRead(n), // กดค้างสลับสถานะเร็ว ๆ
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SwipeBg extends StatelessWidget {
  const _SwipeBg({required this.icon, required this.text, required this.alignment});
  final IconData icon;
  final String text;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: alignment == Alignment.centerLeft
            ? Colors.green.withOpacity(.15)
            : Colors.red.withOpacity(.15),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon),
          const SizedBox(width: 8),
          Text(text),
        ],
      ),
    );
  }
}

class _Notif {
  _Notif({
    required this.id,
    required this.title,
    required this.timeText,
    this.unread = true,
  });

  final String id;
  final String title;
  final String timeText;
  bool unread;
}

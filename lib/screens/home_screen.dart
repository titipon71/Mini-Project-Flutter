import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  // ===== Helpers: Popup ทั้งสองแบบ =====
  Future<void> _showSheet(
    BuildContext context, {
    required String title,
    required String message,
    List<Widget> actions = const [],
    String? imageUrl, // <— เพิ่มพารามิเตอร์รูป
  }) {
    final cs = Theme.of(context).colorScheme;

    void _openImageViewer() {
      if (imageUrl == null) return;
      showDialog(
        context: context,
        builder: (_) => Dialog(
          insetPadding: const EdgeInsets.all(12),
          backgroundColor: Colors.black,
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: InteractiveViewer(
              maxScale: 4,
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(imageUrl, fit: BoxFit.contain),
              ),
            ),
          ),
        ),
      );
    }

    return showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true, // เผื่อรูปใหญ่
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: cs.primary.withOpacity(.12),
                child: Icon(Icons.touch_app, color: cs.primary),
              ),
              title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(message),
            ),

            // รูปภาพ (ถ้ามี)
            if (imageUrl != null) ...[
              const SizedBox(height: 12),
              GestureDetector(
                onTap: _openImageViewer,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      // แสดง progress ตอนโหลด
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            Container(color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(.3)),
                            Center(
                              child: CircularProgressIndicator(
                                value: progress.expectedTotalBytes != null
                                    ? progress.cumulativeBytesLoaded /
                                        (progress.expectedTotalBytes ?? 1)
                                    : null,
                              ),
                            ),
                          ],
                        );
                      },
                      // กันลิงก์พัง
                      errorBuilder: (context, _, __) => Container(
                        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(.3),
                        alignment: Alignment.center,
                        child: const Icon(Icons.broken_image),
                      ),
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('ปิด'),
                  ),
                ),
                const SizedBox(width: 12),
                ...actions.isEmpty
                    ? []
                    : [
                        Expanded(
                          child: FilledButton(
                            onPressed: () {
                              Navigator.pop(context);
                              // ทำอย่างอื่นต่อได้…
                            },
                            child: const Text('ตกลง'),
                          ),
                        ),
                      ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDialog(BuildContext context,
      {required String title, required String message}) {
    return showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('ปิด')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return CustomScrollView(
      key: const PageStorageKey('home'),
      slivers: [
        SliverAppBar(
          pinned: true,
          expandedHeight: 180,
          elevation: 0,
          flexibleSpace: FlexibleSpaceBar(
            titlePadding: const EdgeInsetsDirectional.only(start: 16, bottom: 12),
            title: const Text('สวัสดี 👋', style: TextStyle(color: Colors.white)),
            background: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [cs.primary.withOpacity(.95), cs.secondary.withOpacity(.9)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 56, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ยินดีต้อนรับกลับมา',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white, fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text('นี่คือสรุปคร่าว ๆ ของวันนี้',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Featured cards (PageView)
                SizedBox(
                  height: 160,
                  child: PageView.builder(
                    controller: PageController(viewportFraction: .9),
                    itemCount: 3,
                    itemBuilder: (context, i) => _FeatureCard(
                      index: i,
                      onTap: () => _showSheet(
                        context,
                        title: 'ไฮไลต์ #${i + 1}',
                        message: 'นี่คือรายละเอียดสั้น ๆ ของไฮไลต์หมายเลข ${i + 1}',
                        actions: const [SizedBox()], // โชว์ปุ่ม "ตกลง"
                        // imageUrl: 'https://img5.pic.in.th/file/secure-sv1/x10196c7831286c646.jpg', // <— ใส่ URL ของคุณแทน
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Quick actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('ทางลัด', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    TextButton(
                      onPressed: () => _showDialog(
                        context,
                        title: 'ดูทั้งหมด',
                        message: 'กำลังจะแสดงทางลัดทั้งหมด',
                      ),
                      child: const Text('ดูทั้งหมด'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                GridView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4, mainAxisSpacing: 12, crossAxisSpacing: 12,
                  ),
                  children: [
                    _ActionIcon(icon: Icons.event, label: 'ปฏิทิน',
                      onTap: () => _showSheet(context, title: 'ปฏิทิน', message: 'เปิดดูปฏิทินวันนี้หรือสร้างนัดหมายใหม่?')),
                    _ActionIcon(icon: Icons.task_alt, label: 'งาน',
                      onTap: () => _showSheet(context, title: 'งาน', message: 'ดูงานที่ต้องทำหรือเพิ่มงานใหม่')),
                    _ActionIcon(icon: Icons.insert_chart_outlined, label: 'สถิติ',
                      onTap: () => _showSheet(context, title: 'สถิติ', message: 'ภาพรวมสถิติประจำวัน/สัปดาห์')),
                    _ActionIcon(icon: Icons.settings, label: 'ตั้งค่า',
                      onTap: () => _showSheet(context, title: 'ตั้งค่า', message: 'ปรับธีม การแจ้งเตือน และความเป็นส่วนตัว')),
                  ],
                ),
                const SizedBox(height: 16),

                // List cards
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('อัปเดตล่าสุด', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 8),
                ...List.generate(5, (i) => _UpdateTile(
                      index: i,
                      onTap: () => _showSheet(
                        context,
                        title: 'อัปเดตที่ ${i + 1}',
                        message: 'รายละเอียดสั้น ๆ ของอัปเดตล่าสุด (id: ${i + 1})',
                        imageUrl: 'https://picsum.photos/seed/update_$i/1200/675', // <— ใส่ URL ของคุณแทน
                      ),
                    )),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.index, this.onTap});
  final int index;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(right: 12),
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Ink(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.primaryContainer,
              Theme.of(context).colorScheme.tertiaryContainer,
            ],
          ),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.bolt, size: 48),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ไฮไลต์ #${index + 1}',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Text('เนื้อหาแนะนำสำหรับคุณวันนี้',
                          style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({required this.icon, required this.label, this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 26, color: cs.primary),
              const SizedBox(height: 6),
              Text(label, style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

class _UpdateTile extends StatelessWidget {
  const _UpdateTile({required this.index, this.onTap});
  final int index;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(.12),
          child: const Icon(Icons.notifications),
        ),
        title: Text('อัพเดตที่ ${index + 1}', style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: const Text('รายละเอียดสั้น ๆ ของอัปเดตล่าสุด'),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

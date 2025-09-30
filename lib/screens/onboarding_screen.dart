// /lib/onboarding_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'navbar_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _page = PageController();
  int _index = 0;
  bool _saving = false;

  final _pages = const [
    _OnboardPageData(
      title: 'ยินดีต้อนรับ',
      description: 'แอปของคุณพร้อมแล้ว! ปัดไปเพื่อดูความสามารถหลักแบบย่อ ๆ',
      icon: Icons.rocket_launch,
      assetPath: 'lib/assets/images/Rocket-Animation2.gif',
    ),
    _OnboardPageData(
      title: 'แจ้งเตือนอัจฉริยะ',
      description:
          'ไม่พลาดเหตุการณ์สำคัญ ตั้งค่าการแจ้งเตือนและจัดลำดับความสำคัญได้',
      assetPath: 'lib/assets/images/notifications_active.gif',
      icon: Icons.notifications_active,
    ),
    _OnboardPageData(
      title: 'ค้นหาไวมาก',
      description: 'ค้นหาคอนเทนต์ของคุณแบบเรียลไทม์ พร้อมแนะนำคำค้น',
      assetPath: 'lib/assets/images/search.gif',
      icon: Icons.search,
    ),
    _OnboardPageData(
      title: 'โปรไฟล์ส่วนตัว',
      description: 'จัดการข้อมูลส่วนตัวและการตั้งค่าธีมได้ในที่เดียว',
      assetPath: 'lib/assets/images/personal.gif',
      icon: Icons.person,
      scale: 0.9,
    ),
  ];

  Future<void> _finish() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_done', true);
    } catch (_) {
    } finally {
      if (!mounted) return;
      setState(() => _saving = false);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const NavbarScreen()),
      );
    }
  }

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isLast = _index == _pages.length - 1;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Column(
          children: [
            // ปุ่ม Skip มุมขวาบน
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 12, top: 8),
                child: OutlinedButton.icon(
                  onPressed: _finish,
                  icon: const Icon(Icons.skip_next, size: 18),
                  label: const Text('ข้าม'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: cs.primary,
                    side: BorderSide(color: cs.primary, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    textStyle: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),

            // เนื้อหา (PageView)
            Expanded(
              child: PageView.builder(
                controller: _page,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (_, i) => _OnboardSlide(data: _pages[i]),
              ),
            ),
            const SizedBox(height: 12),

            // จุดบอกหน้า
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pages.length,
                (i) => _Dot(active: i == _index),
              ),
            ),
            const SizedBox(height: 20),

            // ปุ่มควบคุมล่าง
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _index == 0
                          ? null
                          : () => _page.previousPage(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOut,
                            ),
                      child: const Text('ย้อนกลับ'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saving
                          ? null
                          : () {
                              if (isLast) {
                                _finish();
                              } else {
                                _page.nextPage(
                                  duration: const Duration(milliseconds: 250),
                                  curve: Curves.easeOut,
                                );
                              }
                            },
                      child: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(isLast ? 'เริ่มต้นใช้งาน' : 'ถัดไป'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardSlide extends StatelessWidget {
  const _OnboardSlide({required this.data});
  final _OnboardPageData data;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              color: cs.primaryContainer.withOpacity(0.4),
              shape: BoxShape.circle,
              border: Border.all(color: cs.primaryContainer, width: 4),
            ),
            child: Center(
              child: data.assetPath != null
                  ? ClipOval(
                      child: Image.asset(
                        data.assetPath!,
                        width: 220 * data.scale,
                        height: 220 * data.scale,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                      ),
                    )
                  : Icon(data.icon, size: 120, color: cs.primary),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            data.title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            data.description,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.active});
  final bool active;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      height: 8,
      width: active ? 22 : 8,
      decoration: BoxDecoration(
        color: active ? cs.primary : cs.outlineVariant,
        borderRadius: BorderRadius.circular(99),
      ),
    );
  }
}

class _OnboardPageData {
  final String title;
  final String description;
  final IconData icon;
  final String? assetPath;
  final double scale;

  const _OnboardPageData({
    required this.title,
    required this.description,
    required this.icon,
    this.assetPath,
    this.scale = 1.0, // default = เต็ม 220
  });
}

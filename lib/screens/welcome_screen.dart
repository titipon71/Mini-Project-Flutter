import 'package:flutter/material.dart';
import 'package:my_app/screens/sign_in_screen.dart';
import 'package:my_app/screens/sign_up_screen.dart';
import 'dart:math';
import 'static_blobs.dart';

// ---------- Shared Background & UI Atoms ----------
class AbstractBackground extends StatelessWidget {
  const AbstractBackground({super.key, this.child});
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // soft page gradient
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.fromARGB(255, 0, 0, 0),
                Color.fromARGB(255, 0, 0, 0),
                Color.fromARGB(255, 166, 122, 1),
                Color.fromARGB(255, 26, 13, 0),
                Color.fromARGB(255, 26, 13, 0),
              ],
            ),
          ),
        ),
        // curved header
        Positioned(
          left: -40,
          right: -40,
          top: -120,
          child: Container(
            height: 340,
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(48),
                bottomRight: Radius.circular(48),
              ),
            ),
          ),
        ),

        // ------ BLOBS ที่ลอยขึ้น ------
        // FloatingBlobs ถูกคอมเมนต์ไว้ตามคำขอ
        // FloatingBlobs(
        //   count: 24,
        //   areaHeight: 1000,
        //   minSize: 30,
        //   maxSize: 110,
        //   baseDurationMs: 10000,
        //   colors: const [ ... ],
        // ),
        StaticBlobs(
          count: 30,
          areaHeight: 1000,
          minSize: 30,
          maxSize: 110,
          colors: const [
            Color(0xFFFFF176), // เหลืองอ่อน
            Color(0xFFFFEB3B), // เหลืองสด
            Color(0xFFFFD54F), // เหลืองทอง
            Color(0xFFFFC107), // เหลืองอำพัน
            Color(0xFFFFB300), // เหลืองเข้ม
            Color(0xFFFFA726), // ส้มอ่อน
            Color(0xFFFF9800), // ส้มสด
            Color(0xFFFB8C00), // ส้มเข้ม
            Color(0xFFF57C00), // ส้มโทนลึก
            Color(0xFFEF6C00), // ส้มอมแดง
            Color(0xFFE65100), // ส้มไหม้เข้ม
          ],
        ),

        if (child != null) child!,
      ],
    );
  }
}

class FloatingBlobs extends StatefulWidget {
  const FloatingBlobs({
    super.key,
    this.count = 40, // จำนวน blob
    this.areaWidth, // ความกว้างพื้นที่ (ถ้าไม่ใส่ จะใช้จาก LayoutBuilder)
    this.areaHeight = 1, // ความสูงพื้นที่ที่ใช้สุ่มจุดเริ่ม
    this.minSize = 28,
    this.maxSize = 110,
    this.baseDurationMs = 24000,
    this.travel, // ระยะลอยขึ้น (ค่าเริ่มต้น = areaHeight + 200)
    required this.colors, // โทนสีที่จะสุ่มใช้
  });

  final int count;
  final double? areaWidth;
  final double areaHeight;
  final double minSize;
  final double maxSize;
  final int baseDurationMs;
  final double? travel;
  final List<Color> colors;

  @override
  State<FloatingBlobs> createState() => _FloatingBlobsState();
}

class _FloatingBlobsState extends State<FloatingBlobs>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _t; // 0..1
  List<_BlobSpec>? _specs;
  double? _lastWidth;
  final _rnd = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.baseDurationMs),
    )..repeat();

    _t = CurvedAnimation(parent: _controller, curve: Curves.linear);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<_BlobSpec> _buildSpecs(double width) {
    final travel = widget.travel ?? (widget.areaHeight + 200);
    return List.generate(widget.count, (i) {
      final size =
          _rnd.nextDouble() * (widget.maxSize - widget.minSize) +
          widget.minSize;
      final left = _rnd.nextDouble() * (max(0.0, width - size));
      final top = _rnd.nextDouble() * widget.areaHeight;
      final color = widget.colors[_rnd.nextInt(widget.colors.length)];

      // ให้ blob แต่ละก้อนมีความเร็ว/เฟสไม่เท่ากัน
      final speed = 0.65 + _rnd.nextDouble() * 0.9; // 0.65x..1.55x
      final phase = _rnd.nextDouble(); // 0..1

      // เพิ่ม drift ซ้าย-ขวาเล็กน้อยให้ดูมีชีวิต
      final driftAmp = size * (0.06 + _rnd.nextDouble() * 0.12); // แอมป์ตามขนาด
      final driftFreq = 0.5 + _rnd.nextDouble() * 1.2; // Hz-ish

      return _BlobSpec(
        top: top,
        left: left,
        size: size,
        color: color,
        speed: speed,
        phase: phase,
        travel: travel,
        driftAmp: driftAmp,
        driftFreq: driftFreq,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        final w = widget.areaWidth ?? constraints.maxWidth;
        if (_specs == null || _lastWidth != w) {
          _specs = _buildSpecs(w);
          _lastWidth = w;
        }

        return AnimatedBuilder(
          animation: _t,
          builder: (context, child) {
            final children = <Widget>[];
            for (final s in _specs!) {
              // progress ของแต่ละก้อน (วน 0..1 ด้วย speed และ phase)
              final p = ((_t.value * s.speed) + s.phase) % 1.0;

              // ====== NEW: wrap ให้ลอยวนไม่สิ้นสุด ======
              // ระยะช่วงรวมที่ใช้วน (ยาวกว่าหน้าจอหน่อยเพื่อให้โผล่ล่างแบบเนียน)
              final span = s.travel + widget.areaHeight + s.size;

              // ค่าตำแหน่งตามเดิม (ลอยขึ้น)
              double y = s.top - s.travel * p;

              // โมดูลัสให้ค่าอยู่ในช่วง [-s.size, span - s.size)
              // เคล็ดลับ: เพิ่ม span ก่อน % เพื่อกันค่าเป็นลบ แล้วลบ s.size ให้ออกจากหน้าจอเล็กน้อยตอนวน
              y = ((y + span) % span) - s.size;

              // drift ซ้าย-ขวาแบบ sine
              final driftX = sin(2 * pi * (p * s.driftFreq)) * s.driftAmp;

              children.add(
                Positioned(
                  top: y,
                  left: s.left + driftX,
                  child: RepaintBoundary(
                    child: _blobCircle(size: s.size, color: s.color),
                  ),
                ),
              );
            }
            return Stack(clipBehavior: Clip.none, children: children);
          },
        );
      },
    );
  }

  Widget _blobCircle({required double size, required Color color}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [Colors.white.withOpacity(.85), color],
          center: Alignment.topLeft,
          radius: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(.25),
            blurRadius: 24,
            spreadRadius: 4,
            offset: const Offset(0, 10),
          ),
        ],
      ),
    );
  }
}

class _BlobSpec {
  _BlobSpec({
    required this.top,
    required this.left,
    required this.size,
    required this.color,
    required this.speed,
    required this.phase,
    required this.travel,
    required this.driftAmp,
    required this.driftFreq,
  });

  final double top;
  final double left;
  final double size;
  final Color color;

  final double speed; // ตัวคูณความเร็ว
  final double phase; // 0..1
  final double travel; // ระยะทางที่ลอยขึ้น
  final double driftAmp;
  final double driftFreq;
}

class BackButtonBar extends StatelessWidget {
  const BackButtonBar({super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
    child: Row(
      children: [
        IconButton.filledTonal(
          style: IconButton.styleFrom(
            backgroundColor: const Color.fromARGB(
              0,
              255,
              255,
              255,
            ).withOpacity(.9),
          ),
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_ios_new),
        ),
      ],
    ),
  );
}

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.suffix,
    this.validator,
    this.onFieldSubmitted,
  });
  final String label;
  final String hint;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final Widget? suffix;
  final String? Function(String?)? validator;
  final void Function(String)? onFieldSubmitted;
  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFE6E8EF)),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          obscureText: obscureText,
          validator: validator,
          onFieldSubmitted: onFieldSubmitted,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            enabledBorder: border,
            focusedBorder: border.copyWith(
              borderSide: const BorderSide(color: Color(0xFFBFCBFF)),
            ),
            suffixIcon: suffix,
          ),
        ),
      ],
    );
  }
}

class DividerWithText extends StatelessWidget {
  const DividerWithText(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Expanded(child: Divider()),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(text, style: const TextStyle(color: Color(0xFF6B7280))),
      ),
      const Expanded(child: Divider()),
    ],
  );
}

class SocialRow extends StatelessWidget {
  const SocialRow({super.key});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      _socialIcon(Icons.facebook),
      const SizedBox(width: 18),
      _socialIcon(Icons.alternate_email),
      const SizedBox(width: 18),
      _socialIcon(Icons.g_mobiledata),
      const SizedBox(width: 18),
      _socialIcon(Icons.apple),
    ],
  );
  Widget _socialIcon(IconData icon) => InkResponse(
    onTap: () {},
    radius: 28,
    child: Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.06),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Icon(icon, size: 22, color: const Color(0xFF374151)),
    ),
  );
}

class LinkText extends StatelessWidget {
  const LinkText(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      color: const Color(0xFFF6B606),
      fontWeight: FontWeight.w600,
    ),
  );
}

// ------------------------- Welcome Screen -------------------------
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: AbstractBackground(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const SizedBox(height: 40),
                const Text(
                  'Welcome Back!',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 28,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter personal details to your\nemployee account',
                  style: TextStyle(color: Colors.white.withOpacity(.9)),
                ),
                const SizedBox(height: 48),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(.08),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SignInScreen(),
                            ),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(30),
                                bottomLeft: Radius.circular(30),
                              ),
                            ),
                            foregroundColor: const Color.fromARGB(255, 0, 0, 0),
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          child: const Text('Sign in'),
                        ),
                      ),
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SignUpScreen(),
                            ),
                          ),
                          style: TextButton.styleFrom(
                            backgroundColor: Color.fromARGB(255, 10, 47, 138),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.only(
                                topRight: Radius.circular(30),
                                bottomRight: Radius.circular(30),
                              ),
                              side: BorderSide(
                                // เพิ่มขอบ
                                color: Colors.white, // สีขอบ
                                width: 2, // ความหนาขอบ
                              ),
                            ),
                          ),
                          child: const Text('Sign up'),
                        ),
                      ),
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

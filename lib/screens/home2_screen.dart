import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:my_app/assets/widgets/example_sidebarx.dart';
import 'package:my_app/screens/MangaDetail_screen.dart';
import 'package:my_app/screens/navbar2_screen.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:sidebarx/sidebarx.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:convert'; // เพิ่ม import นี้

// imgInformationList จะถูกโหลดจาก Firebase แทน

final MyColor = Color(0xFFF6B606);

// หน้าจอหลักที่มี AppBar เป็นรูปภาพและเลื่อนภาพไปทางขวาแบบอัตโนมัติ
class Home2Screen extends StatefulWidget {
  const Home2Screen({super.key});

  @override
  State<Home2Screen> createState() => _Home2ScreenState();
}

class _Home2ScreenState extends State<Home2Screen>
    with SingleTickerProviderStateMixin {
  int _current = 0;
  int _currentPopular = 0;

  // เพิ่มตัวแปรที่หายไป
  List mangas = [];
  List latestUpdatedMangas = []; // เพิ่มตัวแปรสำหรับมังงะที่อัปเดตล่าสุด
  List<String> imgInformationList = []; // รายการรูปภาพสำหรับ carousel
  bool isLoading = true;

  late final AnimationController _AnimationController;
  late final Animation<double> _alignmentAnim;

  final CarouselSliderController _carouselCtrl = CarouselSliderController();
  final CarouselSliderController _carouselCtrlmangapop =
      CarouselSliderController();
  final _controller = SidebarXController(selectedIndex: 0, extended: true);

  @override
  void initState() {
    super.initState();
    _AnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 50),
    )..repeat();

    _alignmentAnim = Tween<double>(begin: -1.0, end: 1.0).animate(
      CurvedAnimation(parent: _AnimationController, curve: Curves.linear),
    );

    // เรียกใช้ function เมื่อเริ่มต้น
    fetchMangaDB();
    fetchCarouselImages();
  }

  // โหลดรูปภาพสำหรับ carousel จาก Firebase
  Future<void> fetchCarouselImages() async {
    try {
      final ref = FirebaseDatabase.instance.ref('website_info/carousel_images');

      final snapshot = await ref.get();
      List<String> imagesList = [];

      if (snapshot.exists) {
        final value = snapshot.value;

        if (value is List) {
          imagesList = value
              .where((item) => item is String && item.isNotEmpty)
              .cast<String>()
              .toList();
        } else if (value is Map) {
          imagesList = value.values
              .where((item) => item is String && item.isNotEmpty)
              .cast<String>()
              .toList();
        }
      }

      setState(() {
        imgInformationList = imagesList;
        _current = 0; // กัน out-of-range เสมอ
      });
    } catch (_) {
      setState(() {
        imgInformationList = [];
        _current = 0;
      });
    }
  }

  // ย้าย function fetchMangaDB เข้ามาใน class
  Future<void> fetchMangaDB() async {
    final databaseRef = FirebaseDatabase.instance.ref('mangas');
    try {
      final snapshot = await databaseRef.get();

      if (!snapshot.exists) {
        setState(() {
          mangas = [];
          latestUpdatedMangas = [];
          isLoading = false;
        });
        return;
      }

      final raw = snapshot.value;
      final List<Map<String, dynamic>> mangaList = [];

      if (raw is Map) {
        // ถ้าเป็น Map: พยายาม parse key เป็นเลข index จริง
        raw.forEach((key, data) {
          if (data is Map) {
            final m = Map<String, dynamic>.from(data);
            final idx = int.tryParse(key.toString());
            if (idx != null && idx > 0) {
              m['__dbIndex'] = idx; // <---- เก็บ index 1-based
            }
            mangaList.add(m);
          }
        });
      } else if (raw is List) {
        // ถ้าเป็น List: ข้าม index 0 (ที่เป็น null) แล้วเก็บ index จริงไว้
        for (var i = 1; i < raw.length; i++) {
          final e = raw[i];
          if (e is Map) {
            final m = Map<String, dynamic>.from(e);
            m['__dbIndex'] = i; // <---- เก็บ index 1-based
            mangaList.add(m);
          }
        }
      }

      // คำนวณเวลาอัปเดตล่าสุดต่อเรื่อง (รองรับ chapters เป็น List/Map)
      List<Map<String, dynamic>> withLatest = mangaList.map((manga) {
        int latestUpdateTime = 0;

        final chapters = manga['chapters'];
        Iterable chapterValues;
        if (chapters is List) {
          chapterValues = chapters.where((c) => c != null);
        } else if (chapters is Map) {
          chapterValues = chapters.values.where((c) => c != null);
        } else {
          chapterValues = const [];
        }

        for (final ch in chapterValues) {
          if (ch is Map && ch['updatedAt'] != null) {
            final rawTime = ch['updatedAt'];
            int? ms;
            if (rawTime is int) {
              ms = rawTime;
            } else if (rawTime is String) {
              ms = int.tryParse(rawTime);
            }
            if (ms != null && ms > latestUpdateTime) {
              latestUpdateTime = ms;
            }
          }
        }

        return {...manga, 'latestUpdateTime': latestUpdateTime};
      }).toList();

      withLatest.sort(
        (a, b) =>
            (b['latestUpdateTime'] ?? 0).compareTo(a['latestUpdateTime'] ?? 0),
      );

      setState(() {
        mangas = mangaList; // <-- มี __dbIndex อยู่แล้ว
        latestUpdatedMangas = withLatest; // <-- ยังพก __dbIndex มาด้วย
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        mangas = [];
        latestUpdatedMangas = [];
        isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _AnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: const Navbar2(),
      drawer: ExampleSidebarX(controller: _controller),
      body: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),

            // ---------- Carousel #1 (imgInformationList) ----------
            LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth;
                final bool isDesktop = w >= 600;

                if (isDesktop) {
                  // จอใหญ่: fix 584x219
                  return Center(
                    child: SizedBox(
                      width: 584,
                      height: 219,
                      child: CarouselSlider(
                        carouselController: _carouselCtrl,
                        items: imgInformationList.map((p) {
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(30),
                            child: _buildCarouselImage(p, 584, 219),
                          );
                        }).toList(),
                        options: CarouselOptions(
                          height: 219,
                          viewportFraction: 1.0, // เต็ม 584px
                          enlargeCenterPage: false, // ไม่ต้องขยายตรงกลาง
                          padEnds: false, // ไม่ให้เหลือขอบข้าง
                          autoPlay: true,
                          onPageChanged: (i, _) => setState(() => _current = i),
                        ),
                      ),
                    ),
                  );
                }

                // มือถือ: responsive
                return CarouselSlider(
                  carouselController: _carouselCtrl,
                  items: imgInformationList.map((p) {
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: Container(
                        color: Colors.black,
                        alignment: Alignment.center,
                        child: _buildCarouselImage(p, null, 200),
                      ),
                    );
                  }).toList(),
                  options: CarouselOptions(
                    // aspectRatio: 16 / 9,
                    viewportFraction: 0.9,
                    enlargeCenterPage: true,
                    padEnds: true,
                    autoPlay: true,
                    height: 200,
                    onPageChanged: (i, _) => setState(() => _current = i),
                  ),
                );
              },
            ),
            if (imgInformationList.isNotEmpty) ...[
              const SizedBox(height: 8),
              AnimatedSmoothIndicator(
                activeIndex: _current,
                count: imgInformationList.length,
                effect: const WormEffect(
                  dotWidth: 8,
                  dotHeight: 8,
                  activeDotColor: Color(0xFFF6B606),
                ),
                onDotClicked: (i) => _carouselCtrl.animateToPage(i),
              ),
            ],
            const SizedBox(height: 16),

            const SizedBox(height: 16),

            // ---------- ส่วนหัว "เรื่องแนะนำ!" ----------
            _sectionHeader("เรื่องแนะนำ!"),
            const SizedBox(height: 16),

            // ---------- แสดงข้อมูลจาก Firebase ----------
            if (isLoading)
              const Center(child: CircularProgressIndicator())
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 50,
                  runSpacing: 20,
                  alignment: WrapAlignment.spaceBetween,
                  children: mangas.map<Widget>((manga) {
                    return SizedBox(
                      width: 150,
                      child: InkWell(
                        onTap: () {
                          final dbIndex = (manga['__dbIndex'] as int?) ?? 0;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => MangaDetailPage(
                                mangaId: dbIndex,
                                cover: manga['cover'] ?? '',
                                name: manga['name'] ?? 'ไม่มีชื่อ',
                                background: manga['background'],
                              ),
                            ),
                          );
                        },
                        child: _mangaCard(manga['cover'], manga['name']),
                      ),
                    );
                  }).toList(),
                ),
              ),

            const SizedBox(height: 16),

            // ---------- ส่วนหัว "อัปเดตล่าสุด! ----------
            _sectionHeader("อัปเดตล่าสุด!"),
            const SizedBox(height: 16),

            // ---------- แสดงมังงะที่อัปเดตล่าสุดจาก Firebase ----------
            if (isLoading)
              const Center(child: CircularProgressIndicator())
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 50,
                  runSpacing: 20,
                  alignment: WrapAlignment.spaceBetween,
                  children: latestUpdatedMangas.take(4).map<Widget>((manga) {
                    // แสดงแค่ 4 เรื่องล่าสุด
                    return SizedBox(
                      width: 150,
                      child: InkWell(
                        onTap: () {
                          final dbIndex = (manga['__dbIndex'] as int?) ?? 0;

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => MangaDetailPage(
                                mangaId: dbIndex,
                                cover: manga['cover'] ?? '',
                                name: manga['name'] ?? 'ไม่มีชื่อ',
                                background: manga['background'],
                              ),
                            ),
                          );
                        },
                        child: Column(
                          children: [
                            _mangaCard(manga['cover'], manga['name']),
                            // แสดงวันที่อัปเดตล่าสุด
                            if (manga['latestUpdateTime'] != null &&
                                manga['latestUpdateTime'] > 0)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  'อัปเดต: ${_formatDate(manga['latestUpdateTime'])}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.white.withOpacity(0.7),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

            const SizedBox(height: 16),

            // ---------- ปุ่มดูเพิ่มเติม ----------
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFF6B606)),
                    backgroundColor: const Color.fromARGB(0, 0, 0, 0),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.zero,
                    ),
                  ),
                  child: const Align(
                    alignment: Alignment.center,
                    child: Text(
                      "ดูเพิ่มเติม",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ---------------- helpers ----------------

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16.0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.only(left: 16, top: 8, right: 8, bottom: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF6B606),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          title,
          style: const TextStyle(fontSize: 16, color: Colors.white),
        ),
      ),
    );
  }

  // แก้ไข _mangaCard function
  Widget _mangaCard(String? assetPath, String? name) {
    // เปลี่ยนเป็น nullable
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: (assetPath != null && assetPath.isNotEmpty)
                ? Image.network(
                    assetPath,
                    width: 150,
                    height: 200,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 150,
                        height: 200,
                        color: Colors.grey[800],
                        child: const Icon(Icons.error, color: Colors.white),
                      );
                    },
                  )
                : Container(
                    width: 150,
                    height: 200,
                    color: Colors.grey[800],
                    child: const Icon(
                      Icons.image_not_supported,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          name ?? 'ไม่มีชื่อ', // ใช้ null-aware operator
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  // สร้าง widget สำหรับแสดงรูปภาพใน carousel
  Widget _buildCarouselImage(String imagePath, double? width, double height) {
    final imageWidth = (width == null || width == double.infinity)
        ? null
        : width;

    if (imagePath.startsWith('lib/assets/')) {
      // รูปภาพ local assets
      return Image.asset(
        imagePath,
        fit: BoxFit.cover,
        width: imageWidth,
        height: height,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: imageWidth,
            height: height,
            color: Colors.grey[800],
            child: const Icon(Icons.broken_image, color: Colors.white70),
          );
        },
      );
    } else {
      // รูปภาพจาก URL
      return Image.network(
        imagePath,
        fit: BoxFit.cover,
        width: imageWidth,
        height: height,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: imageWidth,
            height: height,
            color: Colors.grey[800],
            child: const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: imageWidth,
            height: height,
            color: Colors.grey[800],
            child: const Icon(Icons.broken_image, color: Colors.white70),
          );
        },
      );
    }
  }

  // เพิ่ม function สำหรับแปลง timestamp เป็นวันที่
  String _formatDate(int timestamp) {
    DateTime date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    DateTime now = DateTime.now();

    Duration difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays} วันที่แล้ว';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ชั่วโมงที่แล้ว';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} นาทีที่แล้ว';
    } else {
      return 'เพิ่งอัปเดต';
    }
  }
}

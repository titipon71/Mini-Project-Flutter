import 'package:firebase_core/firebase_core.dart';
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

final List<String> imgInformationList = [
  'lib/assets/images/welcome.png',
  'lib/assets/images/99b.png',
  'lib/assets/images/popular/I-made-a-Deal_1_1757569497.jpg',
  'lib/assets/images/popular/madam_1-(2)_1757569729.jpg',
  'lib/assets/images/popular/madam_1-(3)_1757569781.jpg',
  'lib/assets/images/popular/Untitled-1_1757570500.jpg',
  'lib/assets/images/popular/1.png',
];



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
  }

  // ย้าย function fetchMangaDB เข้ามาใน class
  Future<void> fetchMangaDB() async {
    final databaseRef = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL:
          'https://flutterapp-3d291-default-rtdb.asia-southeast1.firebasedatabase.app/',
    ).ref('mangas');

    final snapshot = await databaseRef.get();

    if (snapshot.exists) {
      final value = snapshot.value;
      List<Map<String, dynamic>> mangaList = [];

      if (value is Map) {
        // กรณี database เก็บเป็น object { "1": {...}, "2": {...} }
        value.forEach((key, data) {
          if (data != null) {
            // เช็ค null ก่อน
            mangaList.add(Map<String, dynamic>.from(data));
          }
        });
      } else if (value is List) {
        // กรณี database เก็บเป็น array [null, {...}, {...}]
        mangaList = value
            .where((e) => e != null) // กรอง null ออก
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }

      // เรียงลำดับตาม updatedAt ของ chapter ล่าสุด
      List<Map<String, dynamic>> sortedMangaList = mangaList.map((manga) {
        // หา updatedAt ล่าสุดของ manga นี้
        int latestUpdateTime = 0;
        if (manga['chapters'] is List) {
          List chapters = manga['chapters'];
          for (var chapter in chapters) {
            if (chapter != null && chapter['updatedAt'] != null) {
              int updateTime = chapter['updatedAt'];
              if (updateTime > latestUpdateTime) {
                latestUpdateTime = updateTime;
              }
            }
          }
        }
        // เพิ่ม latestUpdateTime เข้าไปใน manga object
        manga['latestUpdateTime'] = latestUpdateTime;
        return manga;
      }).toList();

      // เรียงจากล่าสุดไปเก่าสุด
      sortedMangaList.sort((a, b) => 
        (b['latestUpdateTime'] ?? 0).compareTo(a['latestUpdateTime'] ?? 0)
      );

      setState(() {
        mangas = mangaList; // รายการทั้งหมด
        latestUpdatedMangas = sortedMangaList; // รายการเรียงตามอัปเดต
        isLoading = false;
      });
    } else {
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
                            child: Image.asset(
                              p,
                              fit: BoxFit
                                  .cover, // เปลี่ยนเป็น contain ได้หากไม่อยากให้ครอป
                              width: 584,
                              height: 219,
                            ),
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
                        child: Image.asset(
                          p,
                          fit: BoxFit
                              .cover, // หรือ BoxFit.contain ถ้าไม่อยากครอป
                          width: double.infinity,
                        ),
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

            const SizedBox(height: 16),

            // ---------- ปุ่มหมวด ----------
            // Center(
            //   child: Container(
            //     constraints: const BoxConstraints(maxWidth: 800),
            //     width: double.infinity,
            //     height: 50,
            //     margin: const EdgeInsets.symmetric(horizontal: 20),
            //     padding: const EdgeInsets.all(8),
            //     decoration: BoxDecoration(
            //       color: Color(0xFFF6B606),
            //       borderRadius: BorderRadius.circular(37),
            //     ),
            //     child: Wrap(
            //       spacing: 20,
            //       runAlignment: WrapAlignment.center,
            //       crossAxisAlignment: WrapCrossAlignment.center,
            //       alignment: WrapAlignment.center,
            //       children: [
            //         _chipButton("โรแมนซ์"),
            //         const SizedBox(width: 1),
            //         _chipButton("แอ็กชัน"),
            //         const SizedBox(width: 10),
            //         _chipButton("วาย"),
            //       ],
            //     ),
            //   ),
            // ),
            // ---------- Carousel #2 (imgInformationListmangapop) ----------
            // LayoutBuilder(
            //   builder: (context, constraints) {
            //     final w = constraints.maxWidth;
            //     final bool isDesktop = w >= 600;

            //     if (isDesktop) {
            //       return Center(
            //         child: SizedBox(
            //           width: 584,
            //           height: 219,
            //           child: CarouselSlider(
            //             carouselController: _carouselCtrlmangapop,
            //             items: imgInformationListmangapop.map((p) {
            //               return ClipRRect(
            //                 borderRadius: BorderRadius.circular(20),
            //                 child: Image.asset(
            //                   p,
            //                   fit: BoxFit.cover,
            //                   width: 584,
            //                   height: 219,
            //                 ),
            //               );
            //             }).toList(),
            //             options: CarouselOptions(
            //               height: 219,
            //               viewportFraction: 1.0,
            //               enlargeCenterPage: false,
            //               padEnds: false,
            //               autoPlay: true,
            //               onPageChanged: (i, _) =>
            //                   setState(() => _currentPopular = i),
            //             ),
            //           ),
            //         ),
            //       );
            //     }

            //     return CarouselSlider(
            //       carouselController: _carouselCtrlmangapop,
            //       items: imgInformationListmangapop.map((p) {
            //         return ClipRRect(
            //           borderRadius: BorderRadius.circular(20),
            //           child: Container(
            //             color: Colors.black,
            //             alignment: Alignment.center,
            //             child: Image.asset(
            //               p,
            //               fit: BoxFit.cover, // หรือ BoxFit.contain
            //               width: double.infinity,
            //             ),
            //           ),
            //         );
            //       }).toList(),
            //       options: CarouselOptions(
            //         aspectRatio: 16 / 9,
            //         viewportFraction: 0.9,
            //         enlargeCenterPage: true,
            //         padEnds: true,
            //         autoPlay: true,
            //         onPageChanged: (i, _) =>
            //             setState(() => _currentPopular = i),
            //       ),
            //     );
            //   },
            // ),

            // const SizedBox(height: 8),
            // AnimatedSmoothIndicator(
            //   activeIndex: _currentPopular,
            //   count: imgInformationListmangapop.length,
            //   effect: const WormEffect(
            //     dotWidth: 8,
            //     dotHeight: 8,
            //     activeDotColor: Color(0xFFF6B606),
            //   ),
            //   onDotClicked: (i) => _carouselCtrlmangapop.animateToPage(i),
            // ),

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
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => MangaDetailPage(
                                mangaId: manga['id']?.toString() ?? '',
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
                  children: latestUpdatedMangas.take(4).map<Widget>((manga) { // แสดงแค่ 4 เรื่องล่าสุด
                    return SizedBox(
                      width: 150,
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => MangaDetailPage(
                                mangaId: manga['id']?.toString() ?? '',
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
                            if (manga['latestUpdateTime'] != null && manga['latestUpdateTime'] > 0)
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

  Widget _chipButton(String label) {
    return ElevatedButton(
      onPressed: () {},
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.transparent,
        shadowColor: Colors.transparent,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      child: Text(label),
    );
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

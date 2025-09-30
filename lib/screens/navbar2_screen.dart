import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class Navbar2 extends StatefulWidget implements PreferredSizeWidget {
  const Navbar2({Key? key, this.height = 112, this.onMenuTap,this.onSelectManga})
    : super(key: key);

  final double height;
  final VoidCallback? onMenuTap;
  final ValueChanged<_Manga>? onSelectManga;

  @override
  Size get preferredSize => Size.fromHeight(height);

  @override
  State<Navbar2> createState() => _Navbar2State();
}

class _Navbar2State extends State<Navbar2> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _alignmentAnim;

  List mangas = [];
  List latestUpdatedMangas = []; // เพิ่มตัวแปรสำหรับมังงะที่อัปเดตล่าสุด
  bool isLoading = true;

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
      sortedMangaList.sort(
        (a, b) =>
            (b['latestUpdateTime'] ?? 0).compareTo(a['latestUpdateTime'] ?? 0),
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

  // --- Normalization (ตัดวรรณยุกต์/สระลอยพื้นฐาน + lower case) ---
String _normalize(String input) {
  final lower = input.toLowerCase();
  // ตัดอักขระประกอบไทยที่พบบ่อย (ครอบคลุมเบื้องต้น)
  const combining = [
    '\u0e31','\u0e34','\u0e35','\u0e36','\u0e37','\u0e38','\u0e39',
    '\u0e47','\u0e48','\u0e49','\u0e4a','\u0e4b','\u0e4c','\u0e4d','\u0e4e'
  ];
  final stripped = lower.split('').where((c) => !combining.contains(c)).join();
  // ตัด whitespace ซ้ำ
  return stripped.replaceAll(RegExp(r'\s+'), ' ').trim();
}

// --- สร้าง index สำหรับค้นหา ---
String _buildSearchHaystack(_Manga m) {
  final parts = <String>[];
  if (m.name != null) parts.add(m.name!);
  if (m.altNames != null) parts.addAll(m.altNames!);
  if (m.authors != null) parts.addAll(m.authors!);
  if (m.genres != null) parts.addAll(m.genres!);
  return _normalize(parts.join(' • '));
}

// --- ให้คะแนนความเกี่ยวข้อง ---
int _scoreMatch(String normHaystack, String normQuery) {
  if (normQuery.isEmpty) return 0;
  if (normHaystack == normQuery) return 1000;
  if (normHaystack.startsWith(normQuery)) return 800;
  if (normHaystack.contains(' $normQuery')) return 650; // ตรงเป็นคำถัดไป
  if (normHaystack.contains(normQuery)) return 500;      // ตรงที่ไหนก็ได้
  return 0;
}

// --- ตัวช่วย highlight ---
InlineSpan _highlightText(String? text, String query) {
  final original = text ?? '';
  if (query.isEmpty || original.isEmpty) return TextSpan(text: original);

  final o = original;
  final normO = _normalize(o);
  final normQ = _normalize(query);
  final idx = normO.indexOf(normQ);
  if (idx < 0) return TextSpan(text: o);

  // หา mapping index (แบบคร่าว ๆ) ระหว่างสตริง normalize กับต้นฉบับ
  // วิธีง่าย: หา substring ของต้นฉบับที่ lower ตรงกับช่วงนั้น
  final lowerO = o.toLowerCase();
  final qLower = query.toLowerCase();
  final matchStart = lowerO.indexOf(qLower);
  if (matchStart < 0) return TextSpan(text: o);

  final matchEnd = matchStart + qLower.length;
  return TextSpan(children: [
    TextSpan(text: o.substring(0, matchStart)),
    TextSpan(
      text: o.substring(matchStart, matchEnd),
      style: const TextStyle(fontWeight: FontWeight.bold),
    ),
    TextSpan(text: o.substring(matchEnd)),
  ]);
}


  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    _alignmentAnim = Tween<double>(
      begin: -1.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.linear));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _openDrawer(BuildContext context) {
    if (widget.onMenuTap != null) {
      widget.onMenuTap!.call();
      return;
    }
    final scaffold = Scaffold.maybeOf(context);
    scaffold?.openDrawer();
  }

  Future<void> _openSearchDialog() async {
  final TextEditingController controller = TextEditingController();
  String query = '';
  Timer? debouncer;

  // อ้างอิง DB
  final ref = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL: 'https://flutterapp-3d291-default-rtdb.asia-southeast1.firebasedatabase.app/',
  ).ref('mangas');

  void onQueryChanged(void Function(void Function()) setDialogState, String text) {
    debouncer?.cancel();
    debouncer = Timer(const Duration(milliseconds: 250), () {
      setDialogState(() => query = text.trim());
    });
  }

  try {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.grey.shade900,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('ค้นหามังงะ', style: TextStyle(color: Colors.white)),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.9,
                height: MediaQuery.of(context).size.height * 0.62,
                child: Column(
                  children: [
                    // ช่องค้นหา
                    TextField(
                      controller: controller,
                      autofocus: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'พิมพ์ชื่อ / นามปากกา / แนวเรื่อง...',
                        hintStyle: const TextStyle(color: Colors.white70),
                        prefixIcon: const Icon(Icons.search, color: Colors.white),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.1),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                      ),
                      onChanged: (text) => onQueryChanged(setDialogState, text),
                    ),
                    const SizedBox(height: 12),

                    // ปุ่มล้าง / คำอธิบายสั้น
                    Row(
                      children: [
                        Text('ดึงแบบสตรีมสดจากฐานข้อมูล', style: TextStyle(color: Colors.white54, fontSize: 12)),
                        const Spacer(),
                        if (query.isNotEmpty)
                          TextButton(
                            onPressed: () {
                              controller.clear();
                              setDialogState(() => query = '');
                            },
                            child: const Text('ล้าง', style: TextStyle(color: Colors.white)),
                          ),
                      ],
                    ),

                    // รายชื่อจาก Realtime Database
                    Expanded(
                      child: StreamBuilder<DatabaseEvent>(
                        stream: ref.onValue,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator(color: Colors.white));
                          }
                          if (snapshot.hasError) {
                            return Center(
                              child: Text('เกิดข้อผิดพลาด: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
                            );
                          }

                          final value = snapshot.data?.snapshot.value;
                          if (value == null) {
                            return const Center(child: Text('ไม่มีข้อมูลมังงะ', style: TextStyle(color: Colors.white70)));
                          }

                          final all = _parseMangaList(value);
                          final normQ = _normalize(query);

                          // สร้าง haystack ล่วงหน้า + จัดอันดับ
                          final withScore = all.map((m) {
                            final hay = _buildSearchHaystack(m);
                            final score = _scoreMatch(hay, normQ);
                            return (manga: m, haystack: hay, score: score);
                          }).toList();

                          // ถ้าไม่ได้พิมพ์อะไร: โชว์ตาม "อัปเดตล่าสุด"
                          if (normQ.isEmpty) {
                            withScore.sort((a, b) => b.manga.latestUpdateTime.compareTo(a.manga.latestUpdateTime));
                          } else {
                            // คัดเฉพาะที่มีคะแนน + เรียง (คะแนน > เวลาอัปเดต)
                            withScore.removeWhere((e) => e.score <= 0);
                            withScore.sort((a, b) {
                              final byScore = b.score.compareTo(a.score);
                              if (byScore != 0) return byScore;
                              return b.manga.latestUpdateTime.compareTo(a.manga.latestUpdateTime);
                            });
                          }

                          final results = withScore.map((e) => e.manga).toList();

                          if (results.isEmpty && normQ.isNotEmpty) {
                            return const Center(child: Text('ไม่พบผลลัพธ์', style: TextStyle(color: Colors.white70)));
                          }

                          return ListView.separated(
                            itemCount: results.length,
                            separatorBuilder: (_, __) => Divider(color: Colors.white12, height: 1),
                            itemBuilder: (context, index) {
                              final m = results[index];
                              return ListTile(
                                leading: (m.cover != null && m.cover!.isNotEmpty)
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(
                                          m.cover!,
                                          width: 40,
                                          height: 56,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => const Icon(Icons.book, color: Colors.white70),
                                        ),
                                      )
                                    : const Icon(Icons.book, color: Colors.white70),
                                title: RichText(
                                  text: _highlightText(m.name, query),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (m.latestChapterTitle != null)
                                      Text(m.latestChapterTitle!, style: const TextStyle(color: Colors.white60)),
                                    if ((m.authors?.isNotEmpty ?? false) || (m.genres?.isNotEmpty ?? false))
                                      Text(
                                        [
                                          if (m.authors?.isNotEmpty ?? false) (m.authors!.join(', ')),
                                          if (m.genres?.isNotEmpty ?? false) (m.genres!.join(', ')),
                                        ].join(' • '),
                                        style: const TextStyle(color: Colors.white38, fontSize: 12),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                  ],
                                ),
                                onTap: () {
                                  Navigator.of(context).pop();
                                  // เลือกได้ 2 ทาง:
                                  // 1) ใช้ callback ให้ parent ตัดสินใจนำทาง
                                  if (widget.onSelectManga != null) {
                                    widget.onSelectManga!(m);
                                  } else {
                                    // 2) หรือ pushNamed ถ้าคุณมี route '/mangaDetail'
                                    // Navigator.pushNamed(context, '/mangaDetail', arguments: m);
                                  }
                                },
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('ปิด', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
    }
  } finally {
    debouncer?.cancel();
  }
}


  // ช่วยแปลงข้อมูลจาก Realtime DB (รองรับทั้ง List ที่มี index 0 = null และ Map)
  List<_Manga> _parseMangaList(dynamic value) {
  final List<_Manga> out = [];
  if (value is List) {
    for (final item in value) {
      if (item == null) continue;
      if (item is Map) {
        out.add(_Manga.fromMap(item.map((k, v) => MapEntry(k.toString(), v))));
      }
    }
  } else if (value is Map) {
    value.forEach((key, item) {
      if (item is Map) {
        final m = _Manga.fromMap(item.map((k, v) => MapEntry(k.toString(), v)));
        out.add(m);
      }
    });
  }
  // เรียงตามชื่อพื้นฐานเพื่อความคงที่
  out.sort((a, b) => (a.name ?? '').toLowerCase().compareTo((b.name ?? '').toLowerCase()));
  return out;
}

  // -------------------- END NEW --------------------

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      title: null,
      centerTitle: false,
      leading: IconButton(
        icon: const Icon(Icons.menu, color: Colors.white),
        onPressed: () => _openDrawer(context),
        tooltip: 'Menu',
      ),

      // ปุ่มค้นหามุมขวาบน
      actions: [
        IconButton(
          icon: const Icon(Icons.search, color: Colors.white),
          tooltip: 'ค้นหา',
          onPressed: _openSearchDialog,
        ),
      ],

      // พื้นหลังภาพเลื่อน
      flexibleSpace: PreferredSize(
        preferredSize: widget.preferredSize,
        child: AnimatedBuilder(
          animation: _alignmentAnim,
          builder: (context, child) {
            return LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final t = (_alignmentAnim.value + 1) / 2; // 0..1
                final dx = -t * width;

                return Stack(
                  children: [
                    Positioned(
                      left: dx,
                      top: 0,
                      width: width,
                      height: widget.height,
                      child: Image.asset(
                        'lib/assets/images/top.jpg',
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      left: dx + width,
                      top: 0,
                      width: width,
                      height: widget.height,
                      child: Image.asset(
                        'lib/assets/images/top.jpg',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

// -------------------- Helper Model --------------------
class _Manga {
  final String? id;
  final String? name;
  final String? cover;
  final String? background;
  final List<dynamic>? chapters;

  // ฟิลด์เสริม (มี-ไม่มีก็ได้)
  final List<String>? altNames;
  final List<String>? authors;
  final List<String>? genres;

  // เวลาที่อัปเดตล่าสุด (epoch millis)
  final int latestUpdateTime;

  _Manga({
    this.id,
    this.name,
    this.cover,
    this.background,
    this.chapters,
    this.altNames,
    this.authors,
    this.genres,
    this.latestUpdateTime = 0,
  });

  String? get latestChapterTitle {
    if (chapters == null || chapters!.isEmpty) return null;
    final list = chapters!.where((e) => e != null).toList();
    if (list.isEmpty) return null;

    list.sort((a, b) {
      final ma = (a is Map) ? (a['updatedAt'] as num?) ?? 0 : 0;
      final mb = (b is Map) ? (b['updatedAt'] as num?) ?? 0 : 0;
      return mb.compareTo(ma);
    });

    final latest = list.first;
    if (latest is Map && latest['title'] is String) return latest['title'] as String;
    return null;
  }

  factory _Manga.fromMap(Map<String, dynamic> map) {
    // หาเวลาล่าสุดจาก chapters
    int latest = 0;
    if (map['chapters'] is List) {
      for (final ch in (map['chapters'] as List)) {
        if (ch is Map && ch['updatedAt'] is num) {
          final u = (ch['updatedAt'] as num).toInt();
          if (u > latest) latest = u;
        }
      }
    }

    List<String>? _toStrList(dynamic v) {
      if (v is List) {
        return v.where((e) => e != null).map((e) => e.toString()).toList();
      }
      if (v is String && v.trim().isNotEmpty) {
        // เผื่อเก็บเป็นสตริงคั่นด้วย comma
        return v.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      }
      return null;
    }

    return _Manga(
      id: map['id']?.toString() ?? map['key']?.toString(),
      name: map['name']?.toString(),
      cover: map['cover']?.toString(),
      background: map['background']?.toString(),
      chapters: (map['chapters'] is List) ? map['chapters'] as List : null,
      altNames: _toStrList(map['altNames']),
      authors: _toStrList(map['authors']),
      genres: _toStrList(map['genres']),
      latestUpdateTime: latest,
    );
  }
}


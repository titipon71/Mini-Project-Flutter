// admin_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:my_app/screens/add_chapter_screen.dart';
import 'package:my_app/screens/add_manga_screen.dart';
import 'package:my_app/screens/admin_topup_screen.dart';
import 'package:my_app/screens/edit_chapter_screen.dart';
import 'package:my_app/screens/edit_manga_screen.dart';
import 'package:my_app/screens/edit_websiteinfo_screen.dart';
import 'package:my_app/screens/make_role_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  List mangas = [];
  bool isLoading = true;

  /// จำค่าว่าการ์ด manga แต่ละอัน (index) เลือก chapter index ไหนใน Dropdown
  /// key = mangaIndex ใน ListView, value = chapterIndex จริงใน Firebase (เริ่มที่ 1)
  final Map<int, int?> selectedChapterByManga = {};

  DatabaseReference get _rootRef => FirebaseDatabase.instance.ref();

  @override
  void initState() {
    super.initState();
    fetchMangas();
  }

  Future<void> fetchMangas() async {
    try {
      final snapshot = await _rootRef.child('mangas').get();

      if (!snapshot.exists) {
        setState(() {
          mangas = [];
          isLoading = false;
        });
        return;
      }

      final raw = snapshot.value;
      final List<Map<String, dynamic>> mangaList = [];

      if (raw is List) {
        for (final e in raw) {
          if (e is Map) mangaList.add(Map<String, dynamic>.from(e));
        }
      } else if (raw is Map) {
        raw.forEach((k, v) {
          if (v is Map) mangaList.add(Map<String, dynamic>.from(v));
        });
      } // อื่น ๆ ข้าม

      setState(() {
        mangas = mangaList;
        isLoading = false;

        // รีเซ็ตตัวเลือกตอนต่อการ์ด ถ้ายังไม่เคยตั้งค่า ให้เลือกตอนแรกที่มีได้
        for (var i = 0; i < mangas.length; i++) {
          final chapters = _extractChapters(mangas[i]);
          if (chapters.isNotEmpty && (selectedChapterByManga[i] == null)) {
            selectedChapterByManga[i] =
                chapters.first['chapterIndex']; // int หรือ String ก็ได้
          }
        }
      });
    } catch (e) {
      setState(() {
        mangas = [];
        isLoading = false;
      });
    }
  }

  /// แปลง chapters ที่เป็น List (มี null ตัวแรก) -> List<Map> ที่สะอาด
  /// และพ่วงค่า chapterIndex (index จริงใน Firebase)
  /// คืนค่าเป็น List<Map> ที่ “สะอาด”
  /// เพิ่ม field 'chapterIndex' ไว้ชี้ไปยัง index (ถ้า chapters เป็น List)
  /// หรือ key จริง (ถ้า chapters เป็น Map/push keys)
  List<Map<String, dynamic>> _extractChapters(Map<String, dynamic> manga) {
    final raw = manga['chapters'];
    final List<Map<String, dynamic>> result = [];

    if (raw is List) {
      for (int i = 0; i < raw.length; i++) {
        final item = raw[i];
        if (item is Map) {
          final map = Map<String, dynamic>.from(item);
          map['chapterIndex'] = i; // index จริงใน Firebase กรณีเป็นลิสต์
          result.add(map);
        }
      }
    } else if (raw is Map) {
      raw.forEach((key, value) {
        if (value is Map) {
          final map = Map<String, dynamic>.from(value);
          map['chapterIndex'] = key; // เก็บ push key ไว้ใช้ตอนอ่าน/อัปเดต
          result.add(map);
        }
      });
    } else {
      return [];
    }

    // เรียงตาม number (ถ้ามี) โดยพยายามแปลงเป็น int ให้ได้
    int _asInt(dynamic v) {
      if (v is int) return v;
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }

    result.sort((a, b) => _asInt(a['number']).compareTo(_asInt(b['number'])));
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.grey[900],
      body: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AddMangaScreen(),
                      ),
                    ).then((_) => fetchMangas()); // refresh หลังเพิ่มเรื่องใหม่
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('เพิ่มเรื่องใหม่'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const EditWebsiteInfoScreen(),
                      ),
                    ).then((_) => fetchMangas()); // refresh หลังเพิ่มเรื่องใหม่
                  },
                  icon: const Icon(Icons.info),
                  label: const Text('แก้ไข Website Info'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 10.0,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MakeRoleScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.card_membership),
                label: const Text('Role Management'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10.0),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AdminTopupScreen(),
                    ),
                  );
                },
                label: const Text('Status Management'),
                icon: const Icon(Icons.dashboard_customize),
              ),
            ],
          ),
          // รายการเรื่องทั้งหมด
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: mangas.length,
                    itemBuilder: (context, index) {
                      final manga = mangas[index];

                      // ดึง chapters ที่สะอาด + มี chapterIndex แนบมา
                      final chapters = _extractChapters(manga);

                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        color: Colors.grey[800],
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: manga['cover'] != null
                                    ? Image.network(
                                        manga['cover'],
                                        width: 50,
                                        height: 70,
                                        fit: BoxFit.cover,
                                      )
                                    : const Icon(
                                        Icons.image,
                                        color: Colors.white,
                                      ),
                                title: Text(
                                  manga['name'] ?? 'ไม่มีชื่อ',
                                  style: const TextStyle(color: Colors.white),
                                ),
                                subtitle: Text(
                                  'จำนวนตอน: ${chapters.length}',
                                  style: TextStyle(color: Colors.grey[400]),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => AddChapterScreen(
                                              mangaIndex:
                                                  index +
                                                  1, // +1 เพราะ Firebase index เริ่มจาก 1
                                              mangaName: manga['name'],
                                            ),
                                          ),
                                        ).then((_) => fetchMangas());
                                      },
                                      icon: const Icon(Icons.add_circle),
                                      tooltip: 'เพิ่มตอน',
                                      color: Colors.blue,
                                    ),
                                    IconButton(
                                      onPressed: () {
                                        // วิธีเรียกใช้ที่ปลอดภัย
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => EditMangaScreen(
                                              mangaId: 'manga_id',
                                              initialName:
                                                  manga['name'], // อาจเป็น null ได้
                                              initialCover:
                                                  manga['cover'], // อาจเป็น null ได้
                                              initialBackground:
                                                  manga['background'], // อาจเป็น null ได้
                                            ),
                                          ),
                                        );
                                      },
                                      icon: const Icon(Icons.edit),
                                      tooltip: 'แก้ไขเรื่อง',
                                      color: Colors.orange,
                                    ),
                                  ],
                                ),
                              ),

                              // ===== Dropdown รายชื่อตอน + ปุ่มแก้ไขตอน =====
                              if (chapters.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.grey[700],
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: DropdownButton<int>(
                                          value:
                                              selectedChapterByManga[index] ??
                                              chapters.first['chapterIndex']
                                                  as int,
                                          isExpanded: true,
                                          underline: const SizedBox.shrink(),
                                          dropdownColor: Colors.grey[800],
                                          iconEnabledColor: Colors.white,
                                          style: const TextStyle(
                                            color: Colors.white,
                                          ),
                                          items: chapters.map((c) {
                                            final ci =
                                                c['chapterIndex'] as int; // db
                                            final num = (c['number'] ?? '')
                                                .toString();
                                            final title = (c['title'] ?? '')
                                                .toString();
                                            return DropdownMenuItem<int>(
                                              value: ci,
                                              child: Text(
                                                'ตอนที่ $num - $title',
                                              ),
                                            );
                                          }).toList(),
                                          onChanged: (val) {
                                            setState(() {
                                              selectedChapterByManga[index] =
                                                  val;
                                            });
                                          },
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton.filled(
                                      onPressed: () async {
                                        final chapters = _extractChapters(
                                          manga,
                                        );
                                        final selectedIdx =
                                            selectedChapterByManga[index] ??
                                            chapters.first['chapterIndex']
                                                as int;

                                        final chapter = chapters.firstWhere(
                                          (c) =>
                                              (c['chapterIndex'] as int) ==
                                              selectedIdx,
                                        );

                                        final updated = await Navigator.push<bool>(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => EditChapterScreen(
                                              mangaIndexForDb:
                                                  index +
                                                  1, // index จริงของ manga ใน DB (เริ่ม 1)
                                              chapterIndexForDb:
                                                  selectedIdx, // index จริงของ chapter ใน DB (เริ่ม 1)
                                              initialChapter:
                                                  chapter, // ส่งข้อมูลตอนปัจจุบันไปแก้
                                              mangaName:
                                                  manga['name'] ?? 'ไม่มีชื่อ',
                                            ),
                                          ),
                                        );

                                        // ถ้าหน้าแก้ไขกดบันทึกแล้ว pop(true) กลับมา ให้รีเฟรชรายการ
                                        if (updated == true) {
                                          await fetchMangas();
                                          selectedChapterByManga[index] =
                                              selectedIdx; // คงค่าตอนที่เลือกไว้
                                          setState(() {}); // เผื่ออัปเดต UI
                                        }
                                      },
                                      icon: const Icon(Icons.edit),
                                      tooltip: 'แก้ไขตอนที่เลือก',
                                      style: const ButtonStyle(
                                        backgroundColor: WidgetStatePropertyAll(
                                          Colors.green,
                                        ),
                                        foregroundColor: WidgetStatePropertyAll(
                                          Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ] else ...[
                                Text(
                                  'ยังไม่มีตอน',
                                  style: TextStyle(color: Colors.grey[400]),
                                ),
                              ],
                            ],
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

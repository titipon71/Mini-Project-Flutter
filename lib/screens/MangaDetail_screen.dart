import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:my_app/screens/ChapterReaderPage.dart';

class MangaDetailPage extends StatefulWidget {
  final int mangaId; // index จริงใน DB (เริ่มที่ 1)
  final String cover;
  final String name;
  final String? background;

  const MangaDetailPage({
    super.key,
    required this.mangaId,
    required this.cover,
    required this.name,
    this.background,
  });

  @override
  State<MangaDetailPage> createState() => _MangaDetailPageState();
}

class _MangaDetailPageState extends State<MangaDetailPage> {
  List<Map<String, dynamic>> _chapters = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ---------- helpers ----------
  int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  String _formatUpdatedAt(dynamic v) {
    final ms = _toInt(v);
    if (ms == null || ms <= 0) return '—';
    try {
      final dt = DateTime.fromMillisecondsSinceEpoch(ms);
      return dt.toString(); // ปรับรูปแบบวันที่ได้ตามต้องการ
    } catch (_) {
      return '—';
    }
  }

  Future<void> _load() async {
    try {
      final chapters = await _fetchChaptersRobust(widget.mangaId);
      
      // ✅ sort: ตอนน้อยไปมาก (1 → 2 → 3 ...)
    chapters.sort((a, b) {
      final na = _toInt(a['number'])?? 0;
      final nb = _toInt(b['number'])?? 0;
      return na.compareTo(nb); // ← แก้ตรงนี้ (จากเดิม ub.compareTo(ua))
    });

      setState(() {
        _chapters = chapters;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  /// อ่าน chapters แบบ robust: รองรับทั้ง List 1-based และ Map
  Future<List<Map<String, dynamic>>> _fetchChaptersRobust(int mangaId) async {
    final ref = FirebaseDatabase.instance.ref('mangas/$mangaId/chapters');
    final snap = await ref.get();

    final out = <Map<String, dynamic>>[];
    if (!snap.exists) return out;

    final data = snap.value;

    // กรณีเป็น List และ index 0 = null (โครงสร้าง 1-based)
    if (data is List) {
      for (var i = 1; i < data.length; i++) {
        final item = data[i];
        if (item is Map) {
          final m = Map<String, dynamic>.from(
            item.map((k, v) => MapEntry(k.toString(), v)),
          );
          m['__dbIndex'] = i; // เก็บ index จริงใน DB
          out.add(m);
        }
      }
      return out;
    }

    // กรณีเป็น Map (key เป็น "1","2",…)
    if (data is Map) {
      data.forEach((k, v) {
        if (v is Map) {
          final m = Map<String, dynamic>.from(
            v.map((kk, vv) => MapEntry(kk.toString(), vv)),
          );
          final idx = _toInt(k) ?? 0;
          if (idx > 0) m['__dbIndex'] = idx;
          out.add(m);
        }
      });
      return out;
    }

    return out;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.name),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          image: (widget.background != null && widget.background!.isNotEmpty)
              ? DecorationImage(
                  image: NetworkImage(widget.background!),
                  fit: BoxFit.cover,
                  colorFilter: const ColorFilter.mode(
                    Color.fromARGB(200, 0, 0, 0), // ทำให้ภาพมืดลง
                    BlendMode.darken,
                  ),
                )
              : null,
          color: (widget.background == null || widget.background!.isEmpty)
              ? Colors.grey[900]
              : null,
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ปก
                ClipRRect(
                  borderRadius: BorderRadius.circular(8.0),
                  child: widget.cover.isNotEmpty
                      ? Image.network(
                          widget.cover,
                          width: 200,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 200,
                              height: 280,
                              color: Colors.grey,
                              child: const Icon(Icons.error),
                            );
                          },
                        )
                      : Container(
                          width: 200,
                          height: 280,
                          color: Colors.grey,
                          child: const Icon(Icons.image_not_supported),
                        ),
                ),
                const SizedBox(height: 16),

                // ชื่อเรื่อง
                Text(
                  widget.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 16),

                // แสดงสถานะโหลด/ผิดพลาด/ว่าง/รายการตอน
                if (_loading) ...[
                  const CircularProgressIndicator(),
                ] else if (_error != null) ...[
                  Text(
                    'เกิดข้อผิดพลาด: $_error',
                    style: TextStyle(
                      color: Colors.red[200],
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ] else if (_chapters.isEmpty) ...[
                  Text(
                    'ไม่มีตอนให้อ่าน',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 16,
                    ),
                  ),
                ] else ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'ตอนทั้งหมด (${_chapters.length} ตอน)',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // ปุ่มตอนแบบ Wrap + OutlinedButton
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: _chapters.map((ch) {
                      final numberInt = _toInt(ch['number']) ??
                          (_chapters.indexOf(ch) + 1);
                      final title =
                          (ch['title'] as String?)?.trim() ?? '';

                      // pages: กัน null และนับเฉพาะที่ไม่ใช่ null (เผื่อเอาไว้เช็ค)
                      final pages = ch['pages'];
                      final hasAnyPage = (pages is List) &&
                          pages.where((e) => e != null).isNotEmpty;

                      return OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(
                            color: Colors.white.withOpacity(0.6),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () {
                          if (hasAnyPage) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChapterReaderPage(
                                  mangaName: widget.name,
                                  chapterNumber: numberInt,
                                ),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('ตอนนี้ยังไม่มีหน้าให้แสดง'),
                              ),
                            );
                          }
                        },
                        child: Text(
                          title.isNotEmpty
                              ? title
                              : 'ตอนที่ $numberInt',
                        ),
                      );
                    }).toList(),
                  ),
                ],

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

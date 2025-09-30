import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';

class MangaDetailPage extends StatefulWidget {
  final String mangaId;
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
  List<Map<String, dynamic>> chapters = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchChapters();
  }

  Future<void> fetchChapters() async {
    try {
      final databaseRef = FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL:
            'https://flutterapp-3d291-default-rtdb.asia-southeast1.firebasedatabase.app/',
      ).ref('mangas');

      final snapshot = await databaseRef.get();

      if (snapshot.exists) {
        final value = snapshot.value;
        List<Map<String, dynamic>> chapterList = [];

        if (value is List) {
          // หา manga ที่ตรงกับ name
          for (var manga in value) {
            if (manga != null && manga['name'] == widget.name) {
              var mangaChapters = manga['chapters'];
              if (mangaChapters is List) {
                chapterList = mangaChapters
                    .where((ch) => ch != null) // กรอง null ออก
                    .map((ch) => Map<String, dynamic>.from(ch))
                    .toList();
              }
              break;
            }
          }
        }

        setState(() {
          chapters = chapterList;
          isLoading = false;
        });
      } else {
        setState(() {
          chapters = [];
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching chapters: $e');
      setState(() {
        chapters = [];
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.name) ,backgroundColor: Colors.black,foregroundColor: Colors.white,),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          image: widget.background != null && widget.background!.isNotEmpty
              ? DecorationImage(
                  image: NetworkImage(widget.background!),
                  fit: BoxFit.cover,
                  colorFilter: const ColorFilter.mode(
                    Color.fromARGB(200, 0, 0, 0),
                    BlendMode.darken,
                  ),
                )
              : null,
          color: widget.background == null || widget.background!.isEmpty 
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
                Text(
                  widget.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                
                // แสดง loading หรือ chapters
                if (isLoading)
                  const CircularProgressIndicator()
                else if (chapters.isEmpty)
                  Text(
                    'ไม่มีตอนให้อ่าน',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 16,
                    ),
                  )
                else ...[
                  // หัวข้อ
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'ตอนทั้งหมด (${chapters.length} ตอน)',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // ปุ่มตอนแบบ Wrap
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: chapters.map((ch) {
                      return OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(color: Colors.white.withOpacity(0.6)),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChapterReaderPage(
                                mangaName: widget.name,
                                chapterId: ch['number']?.toString() ?? '',
                                chapterTitle: ch['title'] ?? 'ไม่มีชื่อตอน',
                                chapterNumber: ch['number'] ?? 0,
                                pages: ch['pages'] ?? [], // ส่งข้อมูลหน้าไปด้วย
                              ),
                            ),
                          );
                        },
                        child: Text('${ch['title'] ?? 'ตอนที่ ${ch['number'] ?? '?'}'}'),
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

/// หน้าสำหรับอ่านตอน
class ChapterReaderPage extends StatelessWidget {
  final String mangaName;
  final String chapterId;
  final String chapterTitle;
  final int chapterNumber;
  final List<dynamic> pages; // เพิ่มข้อมูลหน้า

  const ChapterReaderPage({
    super.key,
    required this.mangaName,
    required this.chapterId,
    required this.chapterTitle,
    required this.chapterNumber,
    this.pages = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('$mangaName - $chapterTitle'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.black,
      body: pages.isNotEmpty
    ? ListView.builder(
        padding: EdgeInsets.zero,
        itemCount: pages.length,
        itemBuilder: (context, index) {
          final page = pages[index];
          if (page != null &&
              page['type'] == 'image' &&
              page['url'] != null) {
            final screenWidth = MediaQuery.of(context).size.width;

            return Image.network(
              page['url'],
              width: screenWidth,
              fit: BoxFit.fitWidth, // รูปเต็มความกว้างหน้าจอ
              alignment: Alignment.topCenter,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 300,
                  color: Colors.grey[800],
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error, color: Colors.white, size: 50),
                        SizedBox(height: 8),
                        Text(
                          'ไม่สามารถโหลดรูปภาพได้',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                );
              },
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return const SizedBox(
                  height: 300,
                  child: Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                );
              },
            );
          }

          return Container(
            height: 300,
            color: Colors.grey[800],
            child: const Center(
              child: Text(
                'ไม่สามารถแสดงหน้านี้ได้',
                style: TextStyle(color: Colors.white),
              ),
            ),
          );
        },
      )
    : const Center(
        child: Text(
          'ไม่มีเนื้อหาให้แสดง',
          style: TextStyle(fontSize: 16, color: Colors.white),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

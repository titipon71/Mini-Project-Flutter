import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

class ChapterReaderPage extends StatefulWidget {
  final String mangaName;
  final int chapterNumber; // ใช้ number จาก DB

  const ChapterReaderPage({
    super.key,
    required this.mangaName,
    required this.chapterNumber,
  });

  @override
  State<ChapterReaderPage> createState() => _ChapterReaderPageState();
}

class _ChapterReaderPageState extends State<ChapterReaderPage> {
  bool _showControls = false;
  Timer? _autoHideTimer;

  final _scrollController = ScrollController();

  List<Map<String, dynamic>> _chapters = [];
  bool _isLoadingChapters = true;

  List<dynamic> _pages = [];
  bool _isLoadingPages = true;

  // ------------------ lifecycle ------------------
  @override
  void initState() {
    super.initState();
    _loadChaptersAndPages(widget.mangaName, widget.chapterNumber);
    _scrollController.addListener(_maybePrefetchAhead);
  }

  @override
  void didUpdateWidget(covariant ChapterReaderPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mangaName != widget.mangaName ||
        oldWidget.chapterNumber != widget.chapterNumber) {
      _loadChaptersAndPages(widget.mangaName, widget.chapterNumber);
    }
  }

  @override
  void dispose() {
    _autoHideTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _normalizeChapters(dynamic raw) {
  if (raw == null) return [];

  // chapters เป็น List (เช่น [null, {...}, {...}])
  if (raw is List) {
    final list = raw
        .where((e) => e != null)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    list.sort((a, b) {
      final na = (a['number'] is int)
          ? a['number'] as int
          : int.tryParse('${a['number']}') ?? 0;
      final nb = (b['number'] is int)
          ? b['number'] as int
          : int.tryParse('${b['number']}') ?? 0;
      return na.compareTo(nb); // 1,2,3,...
    });
    return list;
  }

  // chapters เป็น Map (เช่น {"1": {...}, "2": {...}})
  if (raw is Map) {
    final list = raw.values
        .where((e) => e != null)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    list.sort((a, b) {
      final na = (a['number'] is int)
          ? a['number'] as int
          : int.tryParse('${a['number']}') ?? 0;
      final nb = (b['number'] is int)
          ? b['number'] as int
          : int.tryParse('${b['number']}') ?? 0;
      return na.compareTo(nb);
    });
    return list;
  }

  return [];
}

  // ------------------ UI controls ------------------
  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    _restartAutoHide();
  }

  void _restartAutoHide() {
    _autoHideTimer?.cancel();
    if (_showControls) {
      _autoHideTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _showControls = false);
      });
    }
  }

  // พรีโหลดรูปถัดไป 2–3 รูป
  Future<void> _prefetchAround(int currentIndex) async {
    if (!mounted || _pages.isEmpty) return;
    final ctx = context;
    final end = (_pages.length - 1).clamp(0, _pages.length - 1);
    for (int i = currentIndex + 1; i <= (currentIndex + 3).clamp(0, end); i++) {
      final p = _pages[i];
      if (p != null && p['type'] == 'image' && p['url'] != null) {
        final provider = CachedNetworkImageProvider(p['url']);
        precacheImage(provider, ctx);
      }
    }
  }

  // เรียกเวลาเลื่อน เพื่อพรีโหลดล่วงหน้า
  void _maybePrefetchAhead() {
    if (!_scrollController.hasClients) return;
    final offset = _scrollController.offset;
    final viewport = _scrollController.position.viewportDimension;
    final itemHeight = 800.0; // ประมาณความสูงเฉลี่ยของ 1 รูป (ปรับตามจริง)
    final currentIndex = (offset / itemHeight).floor().clamp(
      0,
      _pages.length - 1,
    );
    _prefetchAround(currentIndex);
  }

  // ------------------ Firebase fetchers ------------------
  Future<void> _loadChaptersAndPages(
    String mangaName,
    int chapterNumber,
  ) async {
    setState(() {
      _isLoadingChapters = true;
      _isLoadingPages = true;
    });

    final chapters = await _fetchChapters(mangaName);
    if (!mounted) return;

    setState(() {
      _chapters = chapters;
      _isLoadingChapters = false;
    });

    await _selectPagesForChapterNumber(chapterNumber);
  }

  Future<List<Map<String, dynamic>>> _fetchChapters(String mangaName) async {
  try {
    final ref = FirebaseDatabase.instance.ref('mangas');

    final snapshot = await ref.get();
    if (!snapshot.exists) return [];

    final value = snapshot.value;

    // กรณี A: mangas เป็น Map (เช่น {"1": {...}, "2": {...}})
    if (value is Map) {
      // หาเรื่องที่ name ตรง
      for (final v in value.values) {
        if (v is Map && v['name'] == mangaName) {
          final rawChapters = v['chapters'];
          return _normalizeChapters(rawChapters); // ✅
        }
      }
      return [];
    }

    // กรณี B: mangas เป็น List (เช่น [null, {...}, {...}])
    if (value is List) {
      final manga = value.firstWhere(
        (m) => m != null && m is Map && m['name'] == mangaName,
        orElse: () => null,
      );
      if (manga is Map && manga['chapters'] != null) {
        return _normalizeChapters(manga['chapters']); // ✅
      }
    }

    return [];
  } catch (e) {
    debugPrint('Error fetching chapters: $e');
    return [];
  }
}


  Future<void> _selectPagesForChapterNumber(int chapterNumber) async {
    setState(() => _isLoadingPages = true);

    // หา chapter ตาม number
    final idx = _chapters.indexWhere((c) {
      final n = (c['number'] is int)
          ? c['number'] as int
          : int.tryParse('${c['number']}') ?? -1;
      return n == chapterNumber;
    });

    List<dynamic> pages = [];
    String title = 'ตอนที่ $chapterNumber';

    if (idx >= 0) {
      final ch = _chapters[idx];
      title = ch['title']?.toString() ?? title;

      final p = ch['pages'];
      if (p is List) {
        pages = p.where((e) => e != null).toList();
        // เรียงตาม index เผื่อ DB ไม่เรียง
        pages.sort((a, b) {
          final ia = (a['index'] is int)
              ? a['index'] as int
              : int.tryParse('${a['index']}') ?? 0;
          final ib = (b['index'] is int)
              ? b['index'] as int
              : int.tryParse('${b['index']}') ?? 0;
          return ia.compareTo(ib);
        });
      }
    }

    if (!mounted) return;
    setState(() {
      _pages = pages;
      _isLoadingPages = false;
    });

    // อัปเดต title ใน AppBar ทันที
    if (mounted) {
      // ใช้ setState ของ Scaffold? เราจะใช้ PreferredSizeWidget ปกติพอ
    }

  // หลัง setState _pages เสร็จ:
WidgetsBinding.instance.addPostFrameCallback((_) {
  _prefetchAround(0); // พรีโหลดตั้งแต่รูปแรก
});


  }
  
  // ------------------ navigation ------------------
  int? _currentIndex() {
    final idx = _chapters.indexWhere((c) {
      final n = (c['number'] is int)
          ? c['number'] as int
          : int.tryParse('${c['number']}') ?? -1;
      return n == widget.chapterNumber;
    });
    return idx >= 0 ? idx : null;
  }

  void _goToPrevChapter() {
    if (_isLoadingChapters || _chapters.isEmpty) return;

    final idx = _currentIndex();
    if (idx == null || idx <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('นี่คือตอนแรกแล้ว')));
      return;
    }

    final prev = _chapters[idx - 1];
    final prevNum = (prev['number'] is int)
        ? prev['number'] as int
        : int.tryParse('${prev['number']}') ?? widget.chapterNumber - 1;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ChapterReaderPage(
          mangaName: widget.mangaName,
          chapterNumber: prevNum,
        ),
      ),
    );
  }

  void _goToNextChapter() {
    if (_isLoadingChapters || _chapters.isEmpty) return;

    final idx = _currentIndex();
    if (idx == null || idx >= _chapters.length - 1) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('นี่คือตอนล่าสุดแล้ว')));
      return;
    }

    final next = _chapters[idx + 1];
    final nextNum = (next['number'] is int)
        ? next['number'] as int
        : int.tryParse('${next['number']}') ?? widget.chapterNumber + 1;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ChapterReaderPage(
          mangaName: widget.mangaName,
          chapterNumber: nextNum,
        ),
      ),
    );
  }

  // ------------------ build ------------------
  @override
  Widget build(BuildContext context) {
    final title = _isLoadingChapters
        ? '${widget.mangaName} - กำลังโหลด...'
        : () {
            final idx = _currentIndex();
            if (idx == null)
              return '${widget.mangaName} - ตอนที่ ${widget.chapterNumber}';
            final t = _chapters[idx]['title']?.toString();
            return '${widget.mangaName} - ${t ?? 'ตอนที่ ${widget.chapterNumber}'}';
          }();

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggleControls,
        child: Stack(
          children: [
            // เนื้อหา
            if (_isLoadingPages)
              const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
            else if (_pages.isEmpty)
              const Center(
                child: Text(
                  'ตอนนี้ยังไม่มีเนื้อหาให้แสดง',
                  style: TextStyle(color: Colors.white),
                ),
              )
            else
              ListView.builder(
                controller: _scrollController,
                padding: EdgeInsets.zero,
                itemCount: _pages.length,
                cacheExtent: MediaQuery.of(context).size.height * 1.5,
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  if (page != null &&
                      page['type'] == 'image' &&
                      page['url'] != null) {
                    final screenWidth = MediaQuery.of(context).size.width;
                    return CachedNetworkImage(
                      imageUrl: page['url'],
                      // ลดเวลาถอดรหัสภาพ: ย่อภาพตอน decode ให้พอดีกับความกว้างจอ
                      memCacheWidth: screenWidth.toInt(), // Android/iOS รองรับ
                      // สำหรับ web/บางแพลตฟอร์ม อาจไม่ใช้ memCacheWidth ก็ไม่เป็นไร
                      fit: BoxFit.fitWidth,
                      alignment: Alignment.topCenter,
                      filterQuality: FilterQuality.low, // ลดงานวาด
                      placeholder: (ctx, url) => const SizedBox(
                        height: 300,
                        child: Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                      ),
                      errorWidget: (ctx, url, error) => Container(
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
                      ),
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
              ),

            // ปุ่มควบคุม (โอเวอร์เลย์)
            Positioned(
              left: 0,
              right: 0,
              bottom: 24,
              child: SafeArea(
                top: false,
                child: IgnorePointer(
                  ignoring: !_showControls,
                  child: AnimatedOpacity(
                    opacity: _showControls ? 1 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextButton(
                              onPressed: _goToPrevChapter,
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                              ),
                              child: const Text('〈 ก่อนหน้า'),
                            ),
                            const SizedBox(width: 24),
                            TextButton(
                              onPressed: _goToNextChapter,
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                              ),
                              child: const Text('ถัดไป 〉'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

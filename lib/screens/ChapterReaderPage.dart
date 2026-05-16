import 'dart:async';
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:Twebtoon/services/api_service.dart';

class ChapterReaderPage extends StatefulWidget {
  final int mangaId;
  final String mangaName;
  final int chapterId;
  final int chapterNumber;

  const ChapterReaderPage({
    super.key,
    required this.mangaId,
    required this.mangaName,
    required this.chapterId,
    required this.chapterNumber,
  });

  @override
  State<ChapterReaderPage> createState() => _ChapterReaderPageState();
}

class _ChapterReaderPageState extends State<ChapterReaderPage> {
  bool _showControls = false;
  Timer? _autoHideTimer;
  final _scrollController = ScrollController();

  // รายการ chapters ทั้งหมด (สำหรับ prev/next nav)
  List<Map<String, dynamic>> _chapters = [];
  bool _isLoadingChapters = true;

  // หน้าของ chapter ปัจจุบัน
  List<Map<String, dynamic>> _pages = [];
  bool _isLoadingPages = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_maybePrefetchAhead);
    _loadAll();
  }

  @override
  void didUpdateWidget(covariant ChapterReaderPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chapterId != widget.chapterId ||
        oldWidget.mangaId != widget.mangaId) {
      _loadAll();
    }
  }

  @override
  void dispose() {
    _autoHideTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() {
      _isLoadingChapters = true;
      _isLoadingPages = true;
    });
    await Future.wait([_fetchChapterList(), _fetchPages()]);
  }

  Future<void> _fetchChapterList() async {
    try {
      final response = await ApiService.get(
          '/api/v1/mangas/${widget.mangaId}/chapters');
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final items = (json['items'] as List<dynamic>)
            .cast<Map<String, dynamic>>();
        items.sort((a, b) {
          final na = (a['number'] as num?)?.toInt() ?? 0;
          final nb = (b['number'] as num?)?.toInt() ?? 0;
          return na.compareTo(nb);
        });
        if (mounted) setState(() {
          _chapters = items;
          _isLoadingChapters = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingChapters = false);
    }
  }

  Future<void> _fetchPages() async {
    setState(() => _isLoadingPages = true);
    try {
      final response = await ApiService.get(
          '/api/v1/mangas/${widget.mangaId}/chapters/${widget.chapterId}');
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final pages = (json['pages'] as List<dynamic>)
            .cast<Map<String, dynamic>>();
        pages.sort((a, b) {
          final ia = (a['index'] as num?)?.toInt() ?? 0;
          final ib = (b['index'] as num?)?.toInt() ?? 0;
          return ia.compareTo(ib);
        });
        if (mounted) {
          setState(() {
            _pages = pages;
            _isLoadingPages = false;
          });
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _prefetchAround(0);
          });
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingPages = false);
    }
  }

  // ── Controls ──────────────────────────────────────────────────────────────

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

  Future<void> _prefetchAround(int currentIndex) async {
    if (!mounted || _pages.isEmpty) return;
    final ctx = context;
    final end = (_pages.length - 1).clamp(0, _pages.length - 1);
    for (int i = currentIndex + 1; i <= (currentIndex + 3).clamp(0, end); i++) {
      final p = _pages[i];
      if (p['type'] == 'image' && p['url'] != null) {
        precacheImage(CachedNetworkImageProvider(p['url'] as String), ctx);
      }
    }
  }

  void _maybePrefetchAhead() {
    if (!_scrollController.hasClients) return;
    final offset = _scrollController.offset;
    const itemHeight = 800.0;
    final idx = (offset / itemHeight).floor().clamp(0, _pages.length - 1);
    _prefetchAround(idx);
  }

  // ── Navigation ────────────────────────────────────────────────────────────

  int? _currentIndex() {
    final idx = _chapters.indexWhere((c) => c['id'] == widget.chapterId);
    return idx >= 0 ? idx : null;
  }

  void _goToPrevChapter() {
    if (_isLoadingChapters || _chapters.isEmpty) return;
    final idx = _currentIndex();
    if (idx == null || idx <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('นี่คือตอนแรกแล้ว')));
      return;
    }
    final prev = _chapters[idx - 1];
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ChapterReaderPage(
          mangaId: widget.mangaId,
          mangaName: widget.mangaName,
          chapterId: prev['id'] as int,
          chapterNumber: (prev['number'] as num).toInt(),
        ),
      ),
    );
  }

  void _goToNextChapter() {
    if (_isLoadingChapters || _chapters.isEmpty) return;
    final idx = _currentIndex();
    if (idx == null || idx >= _chapters.length - 1) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('นี่คือตอนล่าสุดแล้ว')));
      return;
    }
    final next = _chapters[idx + 1];
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ChapterReaderPage(
          mangaId: widget.mangaId,
          mangaName: widget.mangaName,
          chapterId: next['id'] as int,
          chapterNumber: (next['number'] as num).toInt(),
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final idx = _currentIndex();
    final title = idx != null
        ? '${widget.mangaName} - ${_chapters[idx]['title'] ?? 'ตอนที่ ${widget.chapterNumber}'}'
        : '${widget.mangaName} - ตอนที่ ${widget.chapterNumber}';

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
            if (_isLoadingPages)
              const Center(
                  child: CircularProgressIndicator(color: Colors.white))
            else if (_pages.isEmpty)
              const Center(
                child: Text('ตอนนี้ยังไม่มีเนื้อหาให้แสดง',
                    style: TextStyle(color: Colors.white)),
              )
            else
              ListView.builder(
                controller: _scrollController,
                padding: EdgeInsets.zero,
                itemCount: _pages.length,
                cacheExtent: MediaQuery.of(context).size.height * 1.5,
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  if (page['type'] == 'image' && page['url'] != null) {
                    final screenWidth = MediaQuery.of(context).size.width;
                    return CachedNetworkImage(
                      imageUrl: page['url'] as String,
                      memCacheWidth: screenWidth.toInt(),
                      fit: BoxFit.fitWidth,
                      alignment: Alignment.topCenter,
                      filterQuality: FilterQuality.low,
                      placeholder: (ctx, url) => const SizedBox(
                        height: 300,
                        child: Center(
                            child: CircularProgressIndicator(
                                color: Colors.white)),
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
                              Text('ไม่สามารถโหลดรูปภาพได้',
                                  style: TextStyle(color: Colors.white)),
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
                      child: Text('ไม่สามารถแสดงหน้านี้ได้',
                          style: TextStyle(color: Colors.white)),
                    ),
                  );
                },
              ),

            // ปุ่ม prev/next
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
                            horizontal: 16, vertical: 8),
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
                                      horizontal: 16)),
                              child: const Text('〈 ก่อนหน้า'),
                            ),
                            const SizedBox(width: 24),
                            TextButton(
                              onPressed: _goToNextChapter,
                              style: TextButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16)),
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

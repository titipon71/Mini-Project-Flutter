import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:Twebtoon/screens/ChapterReaderPage.dart';
import 'package:Twebtoon/services/api_service.dart';

class MangaDetailPage extends StatefulWidget {
  final int mangaId; // MySQL auto-increment ID
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
  bool _isVip = false;

  @override
  void initState() {
    super.initState();
    _fetchUserRole();
    _load();
  }

  Future<void> _fetchUserRole() async {
    try {
      final response = await ApiService.get('/api/v1/me/roles');
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final vip = json['vip'] == true;
        final vipUntil = json['vipUntil'] as String?;
        bool nextIsVip = false;
        if (vip) {
          if (vipUntil == null) {
            nextIsVip = true;
          } else {
            final until = DateTime.tryParse(vipUntil);
            nextIsVip = until != null && until.isAfter(DateTime.now());
          }
        }
        if (mounted) setState(() => _isVip = nextIsVip);
      }
    } catch (_) {
      if (mounted) setState(() => _isVip = false);
    }
  }

  Future<void> _load() async {
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
          _loading = false;
        });
      } else {
        if (mounted) setState(() {
          _error = 'โหลดข้อมูลไม่สำเร็จ (${response.statusCode})';
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String _formatUpdatedAt(String? iso) {
    if (iso == null) return '—';
    final dt = DateTime.tryParse(iso);
    return dt?.toString() ?? '—';
  }

  @override
  Widget build(BuildContext context) {
    final caption = _isVip
        ? 'ตอนทั้งหมด (${_chapters.length} ตอน)'
        : 'ตอนทั้งหมด (${_chapters.length} ตอน) · (สำหรับสมาชิก VIP เท่านั้น)';

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
                    Color.fromARGB(200, 0, 0, 0),
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
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 16),

                if (_loading) ...[
                  const CircularProgressIndicator(),
                ] else if (_error != null) ...[
                  Text(
                    'เกิดข้อผิดพลาด: $_error',
                    style: TextStyle(color: Colors.red[200], fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ] else if (_chapters.isEmpty) ...[
                  Text(
                    'ไม่มีตอนให้อ่าน',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.7), fontSize: 16),
                  ),
                ] else ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      caption,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: _chapters.map((ch) {
                      final numberInt = (ch['number'] as num?)?.toInt() ??
                          (_chapters.indexOf(ch) + 1);
                      final chapterId = ch['id'] as int;
                      final title =
                          (ch['title'] as String?)?.trim() ?? '';

                      return OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(
                              color: Colors.white.withOpacity(0.6)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          disabledForegroundColor:
                              Colors.white.withOpacity(0.3),
                          disabledBackgroundColor:
                              Colors.white.withOpacity(0.05),
                        ),
                        onPressed: !_isVip
                            ? null
                            : () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ChapterReaderPage(
                                      mangaId: widget.mangaId,
                                      mangaName: widget.name,
                                      chapterId: chapterId,
                                      chapterNumber: numberInt,
                                    ),
                                  ),
                                );
                              },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!_isVip) ...[
                              const Icon(Icons.lock, size: 16),
                              const SizedBox(width: 6),
                            ],
                            Text(title.isNotEmpty
                                ? title
                                : 'ตอนที่ $numberInt'),
                          ],
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

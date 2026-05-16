import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:Twebtoon/services/api_service.dart';

class Navbar2 extends StatefulWidget implements PreferredSizeWidget {
  const Navbar2({Key? key, this.height = 112, this.onMenuTap, this.onSelectManga})
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

  bool _searchLoading = false;

  // --- Normalization ---
  String _normalize(String input) {
    final lower = input.toLowerCase();
    const combining = [
      'ั', 'ิ', 'ี', 'ึ', 'ื', 'ุ', 'ู',
      '็', '่', '้', '๊', '๋', '์', 'ํ', '๎',
    ];
    final stripped = lower.split('').where((c) => !combining.contains(c)).join();
    return stripped.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _buildSearchHaystack(_Manga m) {
    final parts = <String>[];
    if (m.name != null) parts.add(m.name!);
    if (m.altNames != null) parts.addAll(m.altNames!);
    if (m.authors != null) parts.addAll(m.authors!);
    if (m.genres != null) parts.addAll(m.genres!);
    return _normalize(parts.join(' • '));
  }

  int _scoreMatch(String normHaystack, String normQuery) {
    if (normQuery.isEmpty) return 0;
    if (normHaystack == normQuery) return 1000;
    if (normHaystack.startsWith(normQuery)) return 800;
    if (normHaystack.contains(' $normQuery')) return 650;
    if (normHaystack.contains(normQuery)) return 500;
    return 0;
  }

  InlineSpan _highlightText(String? text, String query) {
    final original = text ?? '';
    if (query.isEmpty || original.isEmpty) return TextSpan(text: original);

    final lowerO = original.toLowerCase();
    final qLower = query.toLowerCase();
    final matchStart = lowerO.indexOf(qLower);
    if (matchStart < 0) return TextSpan(text: original);

    final matchEnd = matchStart + qLower.length;
    return TextSpan(children: [
      TextSpan(text: original.substring(0, matchStart)),
      TextSpan(
        text: original.substring(matchStart, matchEnd),
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      TextSpan(text: original.substring(matchEnd)),
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
    Scaffold.maybeOf(context)?.openDrawer();
  }

  Future<void> _openSearchDialog() async {
    if (_searchLoading) return;
    setState(() => _searchLoading = true);

    List<_Manga> allMangas = [];
    bool fetchError = false;
    try {
      final response = await ApiService.get('/api/v1/mangas?limit=200');
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final items = (json['items'] as List<dynamic>).cast<Map<String, dynamic>>();
        allMangas = items.map((m) => _Manga.fromApiMap(m)).toList();
        allMangas.sort(
            (a, b) => (a.name ?? '').toLowerCase().compareTo((b.name ?? '').toLowerCase()));
      } else {
        fetchError = true;
      }
    } catch (_) {
      fetchError = true;
    }

    if (!mounted) {
      setState(() => _searchLoading = false);
      return;
    }
    setState(() => _searchLoading = false);

    final TextEditingController controller = TextEditingController();
    String query = '';
    Timer? debouncer;

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
              final normQ = _normalize(query);

              final withScore = allMangas.map((m) {
                final hay = _buildSearchHaystack(m);
                final score = _scoreMatch(hay, normQ);
                return (manga: m, score: score);
              }).toList();

              if (normQ.isEmpty) {
                withScore.sort(
                    (a, b) => b.manga.latestUpdateTime.compareTo(a.manga.latestUpdateTime));
              } else {
                withScore.removeWhere((e) => e.score <= 0);
                withScore.sort((a, b) {
                  final byScore = b.score.compareTo(a.score);
                  if (byScore != 0) return byScore;
                  return b.manga.latestUpdateTime.compareTo(a.manga.latestUpdateTime);
                });
              }
              final results = withScore.map((e) => e.manga).toList();

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
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                        ),
                        onChanged: (text) => onQueryChanged(setDialogState, text),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Text(
                            fetchError
                                ? 'โหลดข้อมูลไม่สำเร็จ'
                                : 'ผลลัพธ์: ${results.length} เรื่อง',
                            style: TextStyle(
                                color: fetchError ? Colors.red : Colors.white54,
                                fontSize: 12),
                          ),
                          const Spacer(),
                          if (query.isNotEmpty)
                            TextButton(
                              onPressed: () {
                                controller.clear();
                                setDialogState(() => query = '');
                              },
                              child:
                                  const Text('ล้าง', style: TextStyle(color: Colors.white)),
                            ),
                        ],
                      ),
                      Expanded(
                        child: results.isEmpty && normQ.isNotEmpty
                            ? const Center(
                                child: Text('ไม่พบผลลัพธ์',
                                    style: TextStyle(color: Colors.white70)))
                            : ListView.separated(
                                itemCount: results.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(color: Colors.white12, height: 1),
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
                                              errorBuilder: (_, __, ___) => const Icon(
                                                  Icons.book,
                                                  color: Colors.white70),
                                            ),
                                          )
                                        : const Icon(Icons.book, color: Colors.white70),
                                    title: RichText(
                                      text: _highlightText(m.name, query),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: (m.authors?.isNotEmpty ?? false) ||
                                            (m.genres?.isNotEmpty ?? false)
                                        ? Text(
                                            [
                                              if (m.authors?.isNotEmpty ?? false)
                                                m.authors!.join(', '),
                                              if (m.genres?.isNotEmpty ?? false)
                                                m.genres!.join(', '),
                                            ].join(' • '),
                                            style: const TextStyle(
                                                color: Colors.white38, fontSize: 12),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          )
                                        : null,
                                    onTap: () {
                                      Navigator.of(context).pop();
                                      if (widget.onSelectManga != null) {
                                        widget.onSelectManga!(m);
                                      }
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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
      }
    } finally {
      debouncer?.cancel();
    }
  }

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
      actions: [
        _searchLoading
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
              )
            : IconButton(
                icon: const Icon(Icons.search, color: Colors.white),
                tooltip: 'ค้นหา',
                onPressed: _openSearchDialog,
              ),
      ],
      flexibleSpace: PreferredSize(
        preferredSize: widget.preferredSize,
        child: AnimatedBuilder(
          animation: _alignmentAnim,
          builder: (context, child) {
            return LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final t = (_alignmentAnim.value + 1) / 2;
                final dx = -t * width;

                return Stack(
                  children: [
                    Positioned(
                      left: dx,
                      top: 0,
                      width: width,
                      height: widget.height,
                      child: Image.network(
                        'https://raw.githubusercontent.com/titipon71/Flutter-images/refs/heads/main/top.jpg',
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      left: dx + width,
                      top: 0,
                      width: width,
                      height: widget.height,
                      child: Image.network(
                        'https://raw.githubusercontent.com/titipon71/Flutter-images/refs/heads/main/top.jpg',
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

class _Manga {
  final String? id;
  final String? name;
  final String? cover;
  final String? background;

  final List<String>? altNames;
  final List<String>? authors;
  final List<String>? genres;

  final int latestUpdateTime;

  _Manga({
    this.id,
    this.name,
    this.cover,
    this.background,
    this.altNames,
    this.authors,
    this.genres,
    this.latestUpdateTime = 0,
  });

  factory _Manga.fromApiMap(Map<String, dynamic> map) {
    final latestUpdatedAt = map['latestUpdatedAt'] as String?;
    final latestUpdateTime = latestUpdatedAt != null
        ? (DateTime.tryParse(latestUpdatedAt)?.millisecondsSinceEpoch ?? 0)
        : 0;

    List<String>? toStrList(dynamic v) {
      if (v is List) {
        return v.where((e) => e != null).map((e) => e.toString()).toList();
      }
      if (v is String && v.trim().isNotEmpty) {
        return v.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      }
      return null;
    }

    return _Manga(
      id: map['id']?.toString(),
      name: map['name']?.toString(),
      cover: map['coverUrl']?.toString(),
      background: map['backgroundUrl']?.toString(),
      altNames: toStrList(map['altNames']),
      authors: toStrList(map['authors']),
      genres: toStrList(map['genres']),
      latestUpdateTime: latestUpdateTime,
    );
  }
}

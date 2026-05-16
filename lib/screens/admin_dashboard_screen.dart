// admin_dashboard_screen.dart
import 'dart:convert';
import 'package:Twebtoon/screens/add_manga_screen.dart';
import 'package:flutter/material.dart';
import 'package:Twebtoon/screens/add_chapter_screen.dart';
import 'package:Twebtoon/screens/admin_topup_screen.dart';
import 'package:Twebtoon/screens/edit_chapter_screen.dart';
import 'package:Twebtoon/screens/edit_manga_screen.dart';
import 'package:Twebtoon/screens/edit_websiteinfo_screen.dart';
import 'package:Twebtoon/screens/make_role_screen.dart';
import 'package:Twebtoon/services/api_service.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  List<Map<String, dynamic>> mangas = [];
  bool isLoading = true;

  // key = mangaId, value = chapterId selected in dropdown
  final Map<int, int?> selectedChapterByManga = {};

  // lazy chapter cache: key = mangaId, value = Future for that manga's chapters
  final Map<int, Future<List<Map<String, dynamic>>>> _chapterFutures = {};

  @override
  void initState() {
    super.initState();
    fetchMangas();
  }

  Future<void> fetchMangas() async {
    setState(() => isLoading = true);
    try {
      final response = await ApiService.get('/api/v1/mangas?limit=100');
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final items = (json['items'] as List<dynamic>).cast<Map<String, dynamic>>();
        if (mounted) {
          setState(() {
            mangas = items;
            isLoading = false;
            // reset chapter cache on refresh
            _chapterFutures.clear();
            selectedChapterByManga.clear();
          });
        }
      } else {
        if (mounted) setState(() { mangas = []; isLoading = false; });
      }
    } catch (_) {
      if (mounted) setState(() { mangas = []; isLoading = false; });
    }
  }

  Future<List<Map<String, dynamic>>> _getChapters(int mangaId) {
    return _chapterFutures.putIfAbsent(mangaId, () => _fetchChapters(mangaId));
  }

  Future<List<Map<String, dynamic>>> _fetchChapters(int mangaId) async {
    try {
      final response = await ApiService.get('/api/v1/mangas/$mangaId/chapters');
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final items = (json['items'] as List<dynamic>).cast<Map<String, dynamic>>();
        items.sort((a, b) =>
            ((a['number'] as num?)?.toInt() ?? 0)
                .compareTo((b['number'] as num?)?.toInt() ?? 0));
        return items;
      }
    } catch (_) {}
    return [];
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
                          builder: (context) => const AddMangaScreen()),
                    ).then((_) => fetchMangas());
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('เพิ่มเรื่องใหม่'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green, foregroundColor: Colors.white),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const EditWebsiteInfoScreen()),
                    ).then((_) => fetchMangas());
                  },
                  icon: const Icon(Icons.info),
                  label: const Text('แก้ไข Website Info'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo, foregroundColor: Colors.white),
                ),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (context) => const MakeRoleScreen()));
                },
                icon: const Icon(Icons.card_membership),
                label: const Text('Role Management'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber, foregroundColor: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const AdminTopupScreen()),
                  );
                },
                label: const Text('Status Management'),
                icon: const Icon(Icons.dashboard_customize),
              ),
            ],
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: mangas.length,
                    itemBuilder: (context, index) {
                      final manga = mangas[index];
                      final mangaId = manga['id'] as int;
                      final mangaName = (manga['name'] ?? 'ไม่มีชื่อ') as String;
                      final coverUrl = manga['coverUrl'] as String?;

                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        color: Colors.grey[800],
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: coverUrl != null && coverUrl.isNotEmpty
                                    ? Image.network(coverUrl,
                                        width: 50, height: 70, fit: BoxFit.cover)
                                    : const Icon(Icons.image, color: Colors.white),
                                title: Text(mangaName,
                                    style: const TextStyle(color: Colors.white)),
                                subtitle: FutureBuilder<List<Map<String, dynamic>>>(
                                  future: _getChapters(mangaId),
                                  builder: (context, snap) {
                                    final count = snap.data?.length ?? 0;
                                    return Text('จำนวนตอน: $count',
                                        style: TextStyle(color: Colors.grey[400]));
                                  },
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
                                              mangaId: mangaId,
                                              mangaName: mangaName,
                                            ),
                                          ),
                                        ).then((_) {
                                          _chapterFutures.remove(mangaId);
                                          fetchMangas();
                                        });
                                      },
                                      icon: const Icon(Icons.add_circle),
                                      tooltip: 'เพิ่มตอน',
                                      color: Colors.blue,
                                    ),
                                    IconButton(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => EditMangaScreen(
                                              mangaId: mangaId,
                                              initialName: mangaName,
                                              initialCover: manga['coverUrl'],
                                              initialBackground: manga['backgroundUrl'],
                                            ),
                                          ),
                                        ).then((_) => fetchMangas());
                                      },
                                      icon: const Icon(Icons.edit),
                                      tooltip: 'แก้ไขเรื่อง',
                                      color: Colors.orange,
                                    ),
                                  ],
                                ),
                              ),

                              // Chapter dropdown
                              FutureBuilder<List<Map<String, dynamic>>>(
                                future: _getChapters(mangaId),
                                builder: (context, snap) {
                                  if (snap.connectionState ==
                                      ConnectionState.waiting) {
                                    return const Padding(
                                      padding: EdgeInsets.symmetric(vertical: 8),
                                      child: LinearProgressIndicator(),
                                    );
                                  }
                                  final chapters = snap.data ?? [];
                                  if (chapters.isEmpty) {
                                    return Text('ยังไม่มีตอน',
                                        style: TextStyle(color: Colors.grey[400]));
                                  }

                                  // ensure selected value is valid
                                  final validIds = chapters
                                      .map((c) => c['id'] as int)
                                      .toSet();
                                  if (selectedChapterByManga[mangaId] == null ||
                                      !validIds.contains(
                                          selectedChapterByManga[mangaId])) {
                                    selectedChapterByManga[mangaId] =
                                        chapters.first['id'] as int;
                                  }

                                  return Padding(
                                    padding:
                                        const EdgeInsets.only(top: 8, bottom: 4),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12),
                                            decoration: BoxDecoration(
                                              color: Colors.grey[700],
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: DropdownButton<int>(
                                              value:
                                                  selectedChapterByManga[mangaId],
                                              isExpanded: true,
                                              underline: const SizedBox.shrink(),
                                              dropdownColor: Colors.grey[800],
                                              iconEnabledColor: Colors.white,
                                              style: const TextStyle(
                                                  color: Colors.white),
                                              items: chapters.map((c) {
                                                final cid = c['id'] as int;
                                                final num = (c['number'] ?? '')
                                                    .toString();
                                                final title =
                                                    (c['title'] ?? '').toString();
                                                return DropdownMenuItem<int>(
                                                  value: cid,
                                                  child:
                                                      Text('ตอนที่ $num - $title'),
                                                );
                                              }).toList(),
                                              onChanged: (val) => setState(() =>
                                                  selectedChapterByManga[mangaId] =
                                                      val),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        IconButton.filled(
                                          onPressed: () async {
                                            final selectedId =
                                                selectedChapterByManga[mangaId];
                                            if (selectedId == null) return;
                                            final chapter = chapters.firstWhere(
                                                (c) => c['id'] == selectedId,
                                                orElse: () => chapters.first);

                                            final updated =
                                                await Navigator.push<bool>(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => EditChapterScreen(
                                                  mangaId: mangaId,
                                                  chapterId: selectedId,
                                                  initialChapter: chapter,
                                                  mangaName: mangaName,
                                                ),
                                              ),
                                            );

                                            if (updated == true) {
                                              _chapterFutures.remove(mangaId);
                                              setState(() {});
                                            }
                                          },
                                          icon: const Icon(Icons.edit),
                                          tooltip: 'แก้ไขตอนที่เลือก',
                                          style: const ButtonStyle(
                                            backgroundColor:
                                                WidgetStatePropertyAll(Colors.green),
                                            foregroundColor:
                                                WidgetStatePropertyAll(Colors.white),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
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

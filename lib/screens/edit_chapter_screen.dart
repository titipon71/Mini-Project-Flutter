import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/services.dart'; // สำหรับคัดลอก URL

import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';

class EditChapterScreen extends StatefulWidget {
  const EditChapterScreen({
    super.key,
    required this.mangaIndexForDb, // index จริงใน DB (เริ่ม 1)
    required this.chapterIndexForDb, // index จริงใน DB (เริ่ม 1)
    required this.initialChapter, // Map ของตอนปัจจุบัน
    required this.mangaName, // ชื่อเรื่อง (เพื่อแสดงผล)
  });

  final int mangaIndexForDb;
  final int chapterIndexForDb;
  final Map<String, dynamic> initialChapter;
  final String mangaName;

  @override
  State<EditChapterScreen> createState() => _EditChapterScreenState();
}

class _EditChapterScreenState extends State<EditChapterScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _numberCtrl;
  late TextEditingController _titleCtrl;
  bool _fabOpen = false;

  int _auto = 0;
  String _newId() => '${DateTime.now().microsecondsSinceEpoch}_${_auto++}';
  // โครงสร้างหน้า: [{index:1, type:'image', url:'...'}]
  late List<Map<String, dynamic>> _pages;

  bool _saving = false;

  DatabaseReference get _db => FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL:
        'https://flutterapp-3d291-default-rtdb.asia-southeast1.firebasedatabase.app/',
  ).ref();

  @override
  void initState() {
    super.initState();
    _numberCtrl = TextEditingController(
      text: '${widget.initialChapter['number'] ?? ''}',
    );
    _titleCtrl = TextEditingController(
      text: widget.initialChapter['title']?.toString() ?? '',
    );
    _pages = _extractPages(widget.initialChapter['pages']);
  }

  List<Map<String, dynamic>> _extractPages(dynamic raw) {
    if (raw is! List) return [];
    final seen = <String>{};
    final List<Map<String, dynamic>> result = [];

    for (final item in raw) {
      if (item == null) continue;
      final m = Map<String, dynamic>.from(item);

      // เติม/ซ่อม id
      var id = m['id']?.toString();
      if (id == null || id.isEmpty || seen.contains(id)) {
        id = _newId();
        m['id'] = id;
      }
      seen.add(id);

      // กัน type ว่าง
      m['type'] = m['type'] ?? 'image';

      result.add(m);
    }

    // เรียงตาม index ถ้ามี ไม่งั้นตามลำดับเดิม
    result.sort((a, b) {
      final ai = (a['index'] is int) ? a['index'] as int : 1 << 30;
      final bi = (b['index'] is int) ? b['index'] as int : 1 << 30;
      return ai.compareTo(bi);
    });

    // รีอินเด็กซ์ให้เป็น 1..n (อย่าแตะ id!)
    for (var i = 0; i < result.length; i++) {
      result[i]['index'] = i + 1;
    }
    return result;
  }

  bool _isLikelyImageUrl(String url) {
    final u = url.toLowerCase();
    return u.startsWith('http://') ||
        u.startsWith('https://'); // เปิดกว้าง ไม่บังคับนามสกุลไฟล์
  }

  void _showUrlDialog(String url) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('URL ของรูป', style: TextStyle(color: Colors.white)),
        content: SelectableText(
          url,
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: url));
              if (mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('คัดลอก URL แล้ว')),
                );
              }
            },
            child: const Text('คัดลอก'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ปิด'),
          ),
        ],
      ),
    );
  }

  void _addPageByUrlDialog() {
    final urlCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'เพิ่มหน้าด้วย URL',
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: urlCtrl,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'วางลิงก์รูปภาพ (http/https)',
            hintStyle: TextStyle(color: Colors.grey[500]),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.grey[700]!),
            ),
            focusedBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Colors.blue),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () {
              final raw = urlCtrl.text.trim();
              final url = _sanitizeUrl(raw);
              if (_isLikelyImageUrl(url)) {
                setState(() {
                  _pages.add({
                    'id': _newId(),
                    'index': _pages.length + 1,
                    'type': 'image',
                    'url': url,
                  });
                });
                Navigator.pop(ctx);
              } else {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('URL ไม่ถูกต้อง')));
              }
            },
            child: const Text('เพิ่ม'),
          ),
        ],
      ),
    );
  }

  void _addPagesBulkDialog() {
    final multiCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'เพิ่มหลายหน้า (วางหลายบรรทัด)',
          style: TextStyle(color: Colors.white),
        ),
        content: SizedBox(
          width: 480,
          child: TextField(
            controller: multiCtrl,
            maxLines: 10,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'ใส่ URL ละ 1 บรรทัด',
              hintStyle: TextStyle(color: Colors.grey[500]),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.grey[700]!),
              ),
              focusedBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: Colors.blue),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () {
              final lines = multiCtrl.text
                  .split('\n')
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty && _isLikelyImageUrl(e))
                  .toList();
              if (lines.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('ไม่พบ URL ที่ถูกต้อง')),
                );
                return;
              }
              setState(() {
                for (final url in lines) {
                  _pages.add({
                    'id': _newId(),
                    'index': _pages.length + 1,
                    'type': 'image',
                    'url': url,
                  });
                }
              });
              Navigator.pop(ctx);
            },
            child: const Text('เพิ่มทั้งหมด'),
          ),
        ],
      ),
    );
  }

  void _editPageUrlDialog(int pageIdx) {
    final urlCtrl = TextEditingController(
      text: _pages[pageIdx]['url']?.toString() ?? '',
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'แก้ไข URL รูป',
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: urlCtrl,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'วางลิงก์รูปภาพใหม่ (http/https)',
            hintStyle: TextStyle(color: Colors.grey[500]),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.grey[700]!),
            ),
            focusedBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Colors.blue),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () {
              final raw = urlCtrl.text.trim();
              final url = _sanitizeUrl(raw);
              if (_isLikelyImageUrl(url)) {
                setState(() {
                  _pages[pageIdx]['url'] = url;
                });
                Navigator.pop(ctx);
              } else {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('URL ไม่ถูกต้อง')));
              }
            },
            child: const Text('บันทึก'),
          ),
        ],
      ),
    );
  }

  void _deletePage(int pageIdx) async {
    final url = _pages[pageIdx]['url']?.toString();
    setState(() {
      _pages.removeAt(pageIdx);
      for (int i = 0; i < _pages.length; i++) {
        _pages[i]['index'] = i + 1;
      }
    });
    // ลบจาก Storage ถ้าเป็นไฟล์ที่เราอัปโหลด (มี downloadURL)
    if (url != null && url.startsWith('http')) {
      try {
        await FirebaseStorage.instance.refFromURL(url).delete();
      } catch (_) {}
    }
  }

  /// ใช้กับทุก URL ที่รับเข้ามา ก่อนเก็บลง _pages
  String _sanitizeUrl(String url) => url.trim();

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final number = int.parse(_numberCtrl.text.trim());
      final title = _titleCtrl.text.trim();

      // รีอินเด็กซ์หน้าให้ต่อเนื่อง 1..n และกำหนด type ถ้ายังไม่มี
      for (int i = 0; i < _pages.length; i++) {
        _pages[i]['index'] = i + 1;
        _pages[i]['type'] = _pages[i]['type'] ?? 'image';
      }

      final ref = _db
          .child('mangas')
          .child(widget.mangaIndexForDb.toString())
          .child('chapters')
          .child(widget.chapterIndexForDb.toString());

      await ref.update({
        'number': number,
        'title': title,
        'updatedAt': ServerValue.timestamp,
        'pages': _pages,
      });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('บันทึกเรียบร้อย')));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('บันทึกไม่สำเร็จ: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addPageByUpload() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      setState(() => _saving = true);

      // แก้ไข: ใช้ default instance แทน
      final storage = FirebaseStorage.instance;

      final List<String> urls = [];

      for (final f in result.files) {
        final Uint8List? bytes = f.bytes;
        if (bytes == null) continue;

        final ext = (f.extension?.toLowerCase() ?? 'jpg');
        final filename =
            '${DateTime.now().millisecondsSinceEpoch}_${f.name ?? 'image.$ext'}';

        // แก้ไข path ให้ตรงกับโครงสร้าง Firebase ของคุณ
        final path =
            'mangas/${widget.mangaIndexForDb}/chapters/${widget.chapterIndexForDb}/$filename';

        try {
          final ref = storage.ref(path);

          final metadata = SettableMetadata(
            contentType: _guessContentType(ext),
            cacheControl: 'public, max-age=31536000',
            customMetadata: {
              'mangaIndex': '${widget.mangaIndexForDb}',
              'chapterIndex': '${widget.chapterIndexForDb}',
              'originalName': f.name ?? filename,
            },
          );

          // อัปโหลดและรอให้เสร็จ
          final uploadTask = ref.putData(bytes, metadata);
          final snapshot = await uploadTask;

          // ตรวจสอบว่าอัปโหลดสำเร็จ
          if (snapshot.state == TaskState.success) {
            final url = await ref.getDownloadURL();
            urls.add(url);
            print('อัปโหลดสำเร็จ: $url'); // สำหรับ debug
          } else {
            print('อัปโหลดไม่สำเร็จ: ${f.name}');
          }
        } catch (uploadError) {
          print('Error uploading ${f.name}: $uploadError');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('อัปโหลด ${f.name} ไม่สำเร็จ: $uploadError'),
              ),
            );
          }
        }
      }

      if (urls.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ไม่มีรูปที่อัปโหลดสำเร็จ')),
          );
        }
        return;
      }

      setState(() {
        for (final url in urls) {
          _pages.add({
            'id': _newId(),
            'index': _pages.length + 1,
            'type': 'image',
            'url': url,
          });
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('อัปโหลดสำเร็จ ${urls.length} รูป')),
        );
      }
    } catch (e) {
      print('General upload error: $e'); // สำหรับ debug
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('อัปโหลดไม่สำเร็จ: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _guessContentType(String ext) {
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      case 'heic':
      case 'heif':
        return 'image/heic';
      default:
        return 'image/jpeg';
    }
  }

  @override
  void dispose() {
    _numberCtrl.dispose();
    _titleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('แก้ไขตอน • ${widget.mangaName}'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save),
            tooltip: 'บันทึก',
          ),
        ],
      ),
      backgroundColor: Colors.grey[900],
      floatingActionButtonLocation:
          FloatingActionButtonLocation.startFloat, // ชิดซ้าย
      floatingActionButton: _saving
          ? null
          : (_fabOpen
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FloatingActionButton.extended(
                        heroTag: 'add_upload',
                        onPressed: _addPageByUpload,
                        icon: const Icon(Icons.file_upload),
                        label: const Text('อัปโหลดรูป (เลือกไฟล์)'),
                      ),
                      const SizedBox(height: 8),
                      FloatingActionButton.extended(
                        heroTag: 'add_url',
                        onPressed: _addPageByUrlDialog,
                        icon: const Icon(Icons.link),
                        label: const Text('เพิ่มหน้า (URL เดียว)'),
                      ),
                      const SizedBox(height: 8),
                      FloatingActionButton.extended(
                        heroTag: 'add_bulk',
                        onPressed: _addPagesBulkDialog,
                        icon: const Icon(Icons.playlist_add),
                        label: const Text('เพิ่มหลายหน้า (วางหลายบรรทัด)'),
                      ),
                      const SizedBox(height: 12),
                      FloatingActionButton.small(
                        heroTag: 'fab_toggle_close',
                        onPressed: () => setState(() => _fabOpen = false),
                        tooltip: 'ย่อเมนู',
                        child: const Icon(Icons.close),
                      ),
                    ],
                  )
                : FloatingActionButton(
                    heroTag: 'fab_toggle_open',
                    onPressed: () => setState(() => _fabOpen = true),
                    tooltip: 'ขยายเมนู',
                    child: const Icon(Icons.add),
                  )),

      body: AbsorbPointer(
        absorbing: _saving,
        child: Column(
          children: [
            if (_saving) const LinearProgressIndicator(minHeight: 3),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _numberCtrl,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'เลขตอน',
                          labelStyle: TextStyle(color: Colors.grey[400]),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.grey[700]!),
                          ),
                          focusedBorder: const OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.blue),
                          ),
                        ),
                        validator: (v) => int.tryParse(v?.trim() ?? '') == null
                            ? 'กรอกเลขตอนให้ถูกต้อง'
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _titleCtrl,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'ชื่อตอน',
                          labelStyle: TextStyle(color: Colors.grey[400]),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.grey[700]!),
                          ),
                          focusedBorder: const OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.blue),
                          ),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'กรอกชื่อตอน'
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: _pages.isEmpty
                  ? Center(
                      child: Text(
                        'ยังไม่มีหน้า',
                        style: TextStyle(color: Colors.grey[400]),
                      ),
                    )
                  : ReorderableListView.builder(
  padding: const EdgeInsets.only(bottom: 96),
  itemCount: _pages.length,
  buildDefaultDragHandles: false, // <- ใช้ handle ของเราเอง
  onReorder: (oldIndex, newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _pages.removeAt(oldIndex);
      _pages.insert(newIndex, item);
      for (int i = 0; i < _pages.length; i++) {
        _pages[i]['index'] = i + 1;
      }
    });
  },
  itemBuilder: (context, i) {
    final p = _pages[i];
    final url = p['url']?.toString() ?? '';
    return Card(
      key: ValueKey(p["id"]),
      color: Colors.grey[800],
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        // ===== ปุ่มจับลาก + ไอคอนรูป =====
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ReorderableDragStartListener(
              index: i,
              child: const Icon(Icons.drag_handle, color: Colors.white70),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.image, color: Colors.white, size: 32),
          ],
        ),
        title: Text('หน้า ${p["index"]}', style: const TextStyle(color: Colors.white)),
        trailing: Wrap(
          spacing: 8,
          children: [
            IconButton(
              tooltip: 'ดูรูป',
              icon: const Icon(Icons.visibility),
              color: Colors.blue,
              onPressed: url.isNotEmpty ? () => _viewImage(url) : null,
            ),
            IconButton(
              tooltip: 'ดู URL',
              icon: const Icon(Icons.link_outlined),
              color: Colors.cyan,
              onPressed: url.isNotEmpty ? () => _showUrlDialog(url) : null,
            ),
            IconButton(
              tooltip: 'แก้ไข URL',
              icon: const Icon(Icons.link),
              color: Colors.amber,
              onPressed: () => _editPageUrlDialog(i),
            ),
            IconButton(
              tooltip: 'ลบหน้า',
              icon: const Icon(Icons.delete),
              color: Colors.redAccent,
              onPressed: () => _deletePage(i),
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
      ),
    );
  }

  void _viewImage(String url) {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.9),
      useSafeArea: false, // <-- ให้คลุมเต็มหน้าจอ รวมถึงพื้นที่ status bar
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero, // <-- ตัดขอบ dialog ออกให้หมด
        child: Stack(
          children: [
            // เนื้อหาเต็มหน้าจอ
            Positioned.fill(
              child: InteractiveViewer(
                panEnabled: true,
                minScale: 1.0,
                maxScale: 5.0,
                child: Center(
                  child: Image.network(
                    url,
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.contain, // แสดงเต็มพื้นที่แบบรักษาสัดส่วน
                    errorBuilder: (context, error, stackTrace) {
                      return const Center(
                        child: Icon(
                          Icons.error_outline,
                          color: Colors.white,
                          size: 48,
                        ),
                      );
                    },
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      );
                    },
                  ),
                ),
              ),
            ),
            // ปุ่มปิด
            Positioned(
              top: MediaQuery.of(ctx).padding.top + 12,
              right: 12,
              child: IconButton(
                onPressed: () => Navigator.pop(ctx),
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black54,
                  shape: const CircleBorder(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

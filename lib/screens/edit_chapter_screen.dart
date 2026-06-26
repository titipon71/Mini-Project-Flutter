import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:Twebtoon/services/api_service.dart';

class EditChapterScreen extends StatefulWidget {
  const EditChapterScreen({
    super.key,
    required this.mangaId,
    required this.chapterId,
    required this.initialChapter,
    required this.mangaName,
  });

  final int mangaId;
  final int chapterId;
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

  late List<Map<String, dynamic>> _pages;
  bool _saving = false;

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
      var id = m['id']?.toString();
      if (id == null || id.isEmpty || seen.contains(id)) {
        id = _newId();
        m['id'] = id;
      }
      seen.add(id);
      m['type'] = m['type'] ?? 'image';
      result.add(m);
    }

    result.sort((a, b) {
      final ai = (a['index'] is int) ? a['index'] as int : 1 << 30;
      final bi = (b['index'] is int) ? b['index'] as int : 1 << 30;
      return ai.compareTo(bi);
    });

    for (var i = 0; i < result.length; i++) {
      result[i]['index'] = i + 1;
    }
    return result;
  }

  bool _isLikelyImageUrl(String url) {
    final u = url.toLowerCase();
    return u.startsWith('http://') || u.startsWith('https://');
  }

  void _showUrlDialog(String url) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('URL ของรูป', style: TextStyle(color: Colors.white)),
        content: SelectableText(url, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: url));
              if (mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('คัดลอก URL แล้ว')));
              }
            },
            child: const Text('คัดลอก', style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ปิด', style: TextStyle(color: Colors.white)),
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
        title: const Text('เพิ่มหน้าด้วย URL', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: urlCtrl,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'วางลิงก์รูปภาพ (http/https)',
            hintStyle: TextStyle(color: Colors.grey[500]),
            enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.grey[700]!)),
            focusedBorder:
                const OutlineInputBorder(borderSide: BorderSide(color: Colors.blue)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () {
              final url = urlCtrl.text.trim();
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
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('URL ไม่ถูกต้อง')));
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
        title: const Text('เพิ่มหลายหน้า (วางหลายบรรทัด)',
            style: TextStyle(color: Colors.white)),
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
                  borderSide: BorderSide(color: Colors.grey[700]!)),
              focusedBorder:
                  const OutlineInputBorder(borderSide: BorderSide(color: Colors.blue)),
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
                    const SnackBar(content: Text('ไม่พบ URL ที่ถูกต้อง')));
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

  String? _guessMimeType(String? extension) {
    switch (extension?.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  Future<void> _editPageImageDialog(int pageIdx) async {
    double progress = 0.0;
    bool uploading = false;
    String? errorText;

    Future<void> uploadAndSet(Uint8List bytes, String filename) async {
      setState(() { uploading = true; progress = 0; });
      try {
        final response = await ApiService.uploadBytes(
          bytes: bytes,
          filename: filename,
          purpose: UploadPurpose.chapterPage,
        );
        final url = ApiService.parseUploadUrl(response);
        if (url != null) {
          setState(() => _pages[pageIdx]['url'] = url);
          if (context.mounted) Navigator.pop(context);
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('อัปโหลดรูปสำเร็จ')));
        } else {
          setState(() { errorText = 'อัปโหลดไม่สำเร็จ (${response.statusCode})'; uploading = false; });
        }
      } catch (e) {
        setState(() { errorText = 'อัปโหลดไม่สำเร็จ: $e'; uploading = false; });
      }
    }

    Future<void> pickFromGallery() async {
      try {
        if (kIsWeb) {
          final result = await FilePicker.platform.pickFiles(
              type: FileType.image, allowMultiple: false, withData: true);
          if (result != null && result.files.single.bytes != null) {
            final f = result.files.single;
            await uploadAndSet(f.bytes!, f.name);
          }
        } else {
          final picker = ImagePicker();
          final xfile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
          if (xfile != null) {
            final bytes = await xfile.readAsBytes();
            await uploadAndSet(bytes, xfile.name);
          }
        }
      } catch (e) {
        setState(() => errorText = 'เลือกไฟล์ไม่สำเร็จ: $e');
      }
    }

    Future<void> pickFromCamera() async {
      if (kIsWeb) {
        setState(() => errorText = 'โหมดกล้องยังไม่รองรับบนเว็บ ใช้เลือกไฟล์แทน');
        return;
      }
      try {
        final picker = ImagePicker();
        final xfile = await picker.pickImage(source: ImageSource.camera, imageQuality: 90);
        if (xfile != null) {
          final bytes = await xfile.readAsBytes();
          await uploadAndSet(bytes, xfile.name);
        }
      } catch (e) {
        setState(() => errorText = 'เปิดกล้องไม่สำเร็จ: $e');
      }
    }

    showDialog(
      context: context,
      barrierDismissible: !uploading,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocalState) {
            return AlertDialog(
              backgroundColor: Colors.grey[900],
              title: const Text('เลือกรูปเพื่ออัปโหลด',
                  style: TextStyle(color: Colors.white)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!uploading) ...[
                    const Text('เลือกรูปจากแกลเลอรีหรือถ่ายใหม่',
                        style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 12),
                  ],
                  if (uploading) ...[
                    const Text('กำลังอัปโหลด...',
                        style: TextStyle(color: Colors.white)),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(value: progress),
                    const SizedBox(height: 4),
                    Text('${(progress * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(color: Colors.white70)),
                  ],
                  if (errorText != null) ...[
                    const SizedBox(height: 12),
                    Text(errorText!, style: const TextStyle(color: Colors.redAccent)),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: uploading ? null : () => Navigator.pop(ctx),
                  child: const Text('ยกเลิก'),
                ),
                if (!uploading) ...[
                  TextButton(
                    onPressed: pickFromGallery,
                    child: const Text('เลือกจากแกลเลอรี'),
                  ),
                  TextButton(
                    onPressed: pickFromCamera,
                    child: const Text('ถ่ายรูป'),
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }

  void _deletePage(int pageIdx) {
    setState(() {
      _pages.removeAt(pageIdx);
      for (int i = 0; i < _pages.length; i++) {
        _pages[i]['index'] = i + 1;
      }
    });
  }

  Future<void> _addPageByUpload() async {
    try {
      late final List<XFile> selectedFiles;

      if (kIsWeb) {
        final result = await FilePicker.platform
            .pickFiles(type: FileType.image, allowMultiple: true, withData: true);
        if (result == null || result.files.isEmpty) return;
        selectedFiles = result.files
            .map((file) => XFile.fromData(file.bytes!, name: file.name,
                mimeType: _guessMimeType(file.extension)))
            .toList();
      } else {
        final picker = ImagePicker();
        selectedFiles = await picker.pickMultiImage(
            maxWidth: 1024, maxHeight: 1024, imageQuality: 85);
        if (selectedFiles.isEmpty) return;
      }

      setState(() => _saving = true);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('กำลังอัปโหลด ${selectedFiles.length} รูป...')));

      final List<String> uploadedUrls = [];

      for (int i = 0; i < selectedFiles.length; i++) {
        final file = selectedFiles[i];
        try {
          final bytes = await file.readAsBytes();
          final response = await ApiService.uploadBytes(
            bytes: bytes,
            filename: file.name,
            purpose: UploadPurpose.chapterPage,
          );
          final url = ApiService.parseUploadUrl(response);
          if (url != null) uploadedUrls.add(url);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('อัปโหลดสำเร็จ ${i + 1}/${selectedFiles.length} รูป'),
              duration: const Duration(milliseconds: 500),
            ));
          }
        } catch (e) {
          debugPrint('Error uploading ${file.name}: $e');
        }
      }

      if (uploadedUrls.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('ไม่มีรูปที่อัปโหลดสำเร็จ')));
        }
        return;
      }

      setState(() {
        for (final url in uploadedUrls) {
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
            SnackBar(content: Text('อัปโหลดสำเร็จ ${uploadedUrls.length} รูป')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final number = int.parse(_numberCtrl.text.trim());
      final title = _titleCtrl.text.trim();

      for (int i = 0; i < _pages.length; i++) {
        _pages[i]['index'] = i + 1;
        _pages[i]['type'] = _pages[i]['type'] ?? 'image';
      }

      final response = await ApiService.patch(
        '/api/v1/mangas/${widget.mangaId}/chapters/${widget.chapterId}',
        {
          'number': number,
          'title': title,
          'pages': _pages
              .map((p) => {'index': p['index'], 'type': p['type'], 'url': p['url'] ?? ''})
              .toList(),
        },
      );

      if (!mounted) return;
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('บันทึกเรียบร้อย')));
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('บันทึกไม่สำเร็จ (${response.statusCode})')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('บันทึกไม่สำเร็จ: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
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
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      floatingActionButton: _saving
          ? null
          : (_fabOpen
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FloatingActionButton.extended(
                      heroTag: null,
                      onPressed: _addPageByUpload,
                      icon: const Icon(Icons.file_upload),
                      label: const Text('อัปโหลดรูป (เลือกไฟล์)'),
                    ),
                    const SizedBox(height: 8),
                    FloatingActionButton.extended(
                      heroTag: null,
                      onPressed: _addPageByUrlDialog,
                      icon: const Icon(Icons.link),
                      label: const Text('เพิ่มหน้า (URL เดียว)'),
                    ),
                    const SizedBox(height: 8),
                    FloatingActionButton.extended(
                      heroTag: null,
                      onPressed: _addPagesBulkDialog,
                      icon: const Icon(Icons.playlist_add),
                      label: const Text('เพิ่มหลายหน้า (วางหลายบรรทัด)'),
                    ),
                    const SizedBox(height: 12),
                    FloatingActionButton.small(
                      heroTag: null,
                      onPressed: () => setState(() => _fabOpen = false),
                      tooltip: 'ย่อเมนู',
                      child: const Icon(Icons.close),
                    ),
                  ],
                )
              : FloatingActionButton(
                  heroTag: null,
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
                              borderSide: BorderSide(color: Colors.grey[700]!)),
                          focusedBorder: const OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.blue)),
                        ),
                        validator: (v) =>
                            int.tryParse(v?.trim() ?? '') == null
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
                              borderSide: BorderSide(color: Colors.grey[700]!)),
                          focusedBorder: const OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.blue)),
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
                      child: Text('ยังไม่มีหน้า',
                          style: TextStyle(color: Colors.grey[400])))
                  : ReorderableListView.builder(
                      padding: const EdgeInsets.only(bottom: 96),
                      itemCount: _pages.length,
                      buildDefaultDragHandles: false,
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
                          key: ValueKey(p['id']),
                          color: Colors.grey[800],
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          child: ListTile(
                            leading: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ReorderableDragStartListener(
                                  index: i,
                                  child: const Icon(Icons.drag_handle,
                                      color: Colors.white70),
                                ),
                                const SizedBox(width: 8),
                              ],
                            ),
                            title: Text('หน้า ${p["index"]}',
                                style: const TextStyle(color: Colors.white)),
                            trailing: Wrap(
                              spacing: 8,
                              children: [
                                IconButton(
                                  tooltip: 'ดูรูป',
                                  icon: const Icon(Icons.visibility),
                                  color: Colors.blue,
                                  onPressed:
                                      url.isNotEmpty ? () => _viewImage(url) : null,
                                ),
                                IconButton(
                                  tooltip: 'ดู URL',
                                  icon: const Icon(Icons.link_outlined),
                                  color: Colors.lightGreenAccent,
                                  onPressed: url.isNotEmpty
                                      ? () => _showUrlDialog(url)
                                      : null,
                                ),
                                IconButton(
                                  tooltip: 'อัปโหลด/เปลี่ยนรูป',
                                  icon: const Icon(Icons.add_photo_alternate),
                                  color: Colors.amber,
                                  onPressed: () => _editPageImageDialog(i),
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
      useSafeArea: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
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
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const Center(
                          child: Icon(Icons.error_outline,
                              color: Colors.white, size: 48));
                    },
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const Center(
                          child: CircularProgressIndicator(color: Colors.white));
                    },
                  ),
                ),
              ),
            ),
            Positioned(
              top: MediaQuery.of(ctx).padding.top + 12,
              right: 12,
              child: IconButton(
                onPressed: () => Navigator.pop(ctx),
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                style: IconButton.styleFrom(
                    backgroundColor: Colors.black54, shape: const CircleBorder()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

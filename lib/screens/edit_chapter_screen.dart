import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/services.dart'; // สำหรับคัดลอก URL

import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';

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

  DatabaseReference get _db => FirebaseDatabase.instance.ref('mangas');

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

  Future<void> _editPageImageDialog(int pageIdx) async {
    String? errorText;
    double progress = 0.0;
    bool uploading = false;

    Future<void> _uploadAndSet(
      Uint8List bytes,
      String filename, {
      String? contentType,
    }) async {
      setState(() {
        uploading = true;
        progress = 0;
      });

      final storage = FirebaseStorage.instance;
      final path =
          'pages/$pageIdx/${DateTime.now().millisecondsSinceEpoch}_$filename';
      final ref = storage.ref(path);

      final metadata = SettableMetadata(
        contentType: contentType ?? 'image/jpeg',
      );

      UploadTask task = ref.putData(bytes, metadata);
      task.snapshotEvents.listen((snapshot) {
        if (snapshot.totalBytes > 0) {
          setState(() {
            progress = snapshot.bytesTransferred / snapshot.totalBytes;
          });
        }
      });

      try {
        await task;
        final url = await ref.getDownloadURL();
        setState(() {
          _pages[pageIdx]['url'] = url;
        });
        if (context.mounted) Navigator.pop(context); // ปิด dialog หลังสำเร็จ
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('อัปโหลดรูปสำเร็จ')));
      } on FirebaseException catch (e) {
        setState(() {
          errorText = e.message ?? 'อัปโหลดไม่สำเร็จ';
          uploading = false;
        });
      }
    }

    String? _guessMimeType(PlatformFile file) {
      final ext = file.extension?.toLowerCase();
      switch (ext) {
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
          return 'application/octet-stream';
      }
    }

    // ตัวเลือกไฟล์ (รองรับทั้ง Mobile/Web)
    Future<void> _pickFromGallery() async {
      try {
        if (kIsWeb) {
          final result = await FilePicker.platform.pickFiles(
            type: FileType.image,
            allowMultiple: false,
            withData: true,
          );
          
          if (result != null && result.files.single.bytes != null) {
            final f = result.files.single;
            final mimeType = _guessMimeType(f);
            await _uploadAndSet(f.bytes!, f.name, contentType: mimeType);
          }
        } else {
          final picker = ImagePicker();
          final xfile = await picker.pickImage(
            source: ImageSource.gallery,
            imageQuality: 90,
          );
          if (xfile != null) {
            final bytes = await xfile.readAsBytes();
            await _uploadAndSet(bytes, xfile.name);
          }
        }
      } catch (e) {
        setState(() {
          errorText = 'เลือกไฟล์ไม่สำเร็จ: $e';
        });
      }
    }

    Future<void> _pickFromCamera() async {
      if (kIsWeb) {
        setState(() {
          errorText = 'โหมดกล้องยังไม่รองรับบนเว็บ ใช้เลือกไฟล์แทน';
        });
        return;
      }
      try {
        final picker = ImagePicker();
        final xfile = await picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 90,
        );
        if (xfile != null) {
          final bytes = await xfile.readAsBytes();
          await _uploadAndSet(bytes, xfile.name);
        }
      } catch (e) {
        setState(() {
          errorText = 'เปิดกล้องไม่สำเร็จ: $e';
        });
      }
    }

    // แสดง Dialog
    showDialog(
      context: context,
      barrierDismissible: !uploading,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocalState) {
            // sync setState ภายใน dialog
            void localSet(VoidCallback cb) {
              setLocalState(cb);
              // ซิงก์ด้วย setState หลักเพื่ออัปเดต UI ภายนอกถ้าจำเป็น
              // ignore: invalid_use_of_protected_member
              // setState(cb);  // ถ้าอยากอัปเดต state ภายนอกด้วย ให้เปิดบรรทัดนี้
            }

            return AlertDialog(
              backgroundColor: Colors.grey[900],
              title: const Text(
                'เลือกรูปเพื่ออัปโหลด',
                style: TextStyle(color: Colors.white),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!uploading) ...[
                    const Text(
                      'เลือกรูปจากแกลเลอรีหรือถ่ายใหม่',
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (uploading) ...[
                    const Text(
                      'กำลังอัปโหลด...',
                      style: TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(value: progress),
                    const SizedBox(height: 4),
                    Text(
                      '${(progress * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                  if (errorText != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      errorText!,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
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
                    onPressed: () async {
                      await _pickFromGallery();
                    },
                    child: const Text('เลือกจากแกลเลอรี'),
                  ),
                  TextButton(
                    onPressed: () async {
                      await _pickFromCamera();
                    },
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

  Future<void> _addPageByUpload() async {
    try {
      late final List<XFile> selectedFiles;
      
      if (kIsWeb) {
        // สำหรับ Web ใช้ FilePicker
        final result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          allowMultiple: true,
          withData: true,
        );
        
        if (result == null || result.files.isEmpty) return;
        
        // แปลง PlatformFile เป็น XFile
        selectedFiles = result.files.map((file) {
          return XFile.fromData(
            file.bytes!,
            name: file.name,
            mimeType: _guessMimeTypeFromExtension(file.extension),
          );
        }).toList();
      } else {
        // สำหรับ Mobile ใช้ ImagePicker
        final picker = ImagePicker();
        selectedFiles = await picker.pickMultiImage(
          maxWidth: 1024,
          maxHeight: 1024,
          imageQuality: 85,
        );
        
        if (selectedFiles.isEmpty) return;
      }

      setState(() => _saving = true);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('กำลังอัปโหลด ${selectedFiles.length} รูป...')),
      );

      final List<String> uploadedUrls = [];
      
      for (int i = 0; i < selectedFiles.length; i++) {
        final file = selectedFiles[i];
        
        try {
          // อัปโหลดไปยัง Firebase Storage
          final uploadedUrl = await _uploadSingleFile(file, i);
          if (uploadedUrl != null) {
            uploadedUrls.add(uploadedUrl);
          }
          
          // แสดงความคืบหน้า
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('อัปโหลดสำเร็จ ${i + 1}/${selectedFiles.length} รูป'),
              duration: const Duration(milliseconds: 500),
            ),
          );
        } catch (e) {
          print('Error uploading file ${file.name}: $e');
        }
      }

      if (uploadedUrls.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ไม่มีรูปที่อัปโหลดสำเร็จ')),
          );
        }
        return;
      }

      // เพิ่มหน้าใหม่เข้าไปใน _pages
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
          SnackBar(content: Text('อัปโหลดสำเร็จ ${uploadedUrls.length} รูป')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<String?> _uploadSingleFile(XFile file, int fileIndex) async {
    try {
      final bytes = await file.readAsBytes();
      final fileName = file.name;
      final fileExtension = fileName.split('.').last.toLowerCase();
      
      // สร้างชื่อไฟล์ใหม่ที่รวมชื่อเดิม
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final newFileName = 'page_${_pages.length + fileIndex + 1}_${timestamp}_$fileName';
      
      // Path: mangas/{mangaIndex}/chapters/{chapterIndex}/{newFileName}
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('mangas')
          .child('${widget.mangaIndexForDb}')
          .child('chapters')
          .child('${widget.chapterIndexForDb}')
          .child(newFileName);

      // กำหนด content type และ metadata
      final contentType = _guessContentType(fileExtension);
      final metadata = SettableMetadata(
        contentType: contentType,
        customMetadata: {
          'originalFileName': fileName,
          'uploadedAt': DateTime.now().toIso8601String(),
          'mangaIndex': '${widget.mangaIndexForDb}',
          'chapterIndex': '${widget.chapterIndexForDb}',
        },
      );

      // อัปโหลดไฟล์
      final uploadTask = storageRef.putData(bytes, metadata);
      final snapshot = await uploadTask;
      
      if (snapshot.state == TaskState.success) {
        final downloadUrl = await storageRef.getDownloadURL();
        return downloadUrl;
      }
      
      return null;
    } catch (e) {
      print('Error uploading single file: $e');
      return null;
    }
  }

  String? _guessMimeTypeFromExtension(String? extension) {
    if (extension == null) return null;
    
    switch (extension.toLowerCase()) {
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
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: ListTile(
                            // ===== ปุ่มจับลาก + ไอคอนรูป =====
                            leading: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ReorderableDragStartListener(
                                  index: i,
                                  child: const Icon(
                                    Icons.drag_handle,
                                    color: Colors.white70,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // const Icon(Icons.image, color: Colors.white, size: 32),
                              ],
                            ),
                            title: Text(
                              'หน้า ${p["index"]}',
                              style: const TextStyle(color: Colors.white),
                            ),
                            trailing: Wrap(
                              spacing: 8,
                              children: [
                                IconButton(
                                  tooltip: 'ดูรูป',
                                  icon: const Icon(Icons.visibility),
                                  color: Colors.blue,
                                  onPressed: url.isNotEmpty
                                      ? () => _viewImage(url)
                                      : null,
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

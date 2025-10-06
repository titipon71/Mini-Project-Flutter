import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

class AddMangaScreen extends StatefulWidget {
  const AddMangaScreen({super.key});

  @override
  State<AddMangaScreen> createState() => _AddMangaScreenState();
}

class _AddMangaScreenState extends State<AddMangaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _coverController = TextEditingController();
  final _backgroundController = TextEditingController();

  bool isLoading = false;
  bool _coverUploading = false;
  bool _bgUploading = false;

  // -------------------- Utils --------------------
  bool _isHttpUrl(String v) {
    final u = v.trim().toLowerCase();
    return u.startsWith('http://') || u.startsWith('https://');
  }

  String _guessContentType(String ext) {
    switch (ext.toLowerCase()) {
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

  String _randomName(String original) =>
      '${DateTime.now().millisecondsSinceEpoch}_$original';

  Future<String?> _uploadBytes(
    Uint8List bytes,
    String filename, {
    required String bucketFolder, // e.g. 'mangas/covers' or 'mangas/backgrounds'
    String? contentType,
    void Function(double p)? onProgress,
  }) async {
    final storage = FirebaseStorage.instance;
    final safeName = _randomName(filename);
    final ref = storage.ref('$bucketFolder/$safeName');

    final metadata = SettableMetadata(
      contentType: contentType ?? 'image/jpeg',
      cacheControl: 'public, max-age=31536000',
    );

    final task = ref.putData(bytes, metadata);
    task.snapshotEvents.listen((s) {
      if (onProgress != null && s.totalBytes > 0) {
        onProgress(s.bytesTransferred / s.totalBytes);
      }
    });

    await task.whenComplete(() {});
    return await ref.getDownloadURL();
  }

  Future<void> _pickAndUpload({
    required bool forCover,
  }) async {
    // state flags
    void setUploading(bool v) {
      setState(() {
        if (forCover) {
          _coverUploading = v;
        } else {
          _bgUploading = v;
        }
      });
    }

    setUploading(true);
    double progress = 0;

    try {
      // เลือกไฟล์รูป
      Uint8List? bytes;
      String filename = 'image.jpg';
      String contentType = 'image/jpeg';

      if (kIsWeb) {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          allowMultiple: false,
          withData: true,
        );
        if (result == null || result.files.isEmpty || result.files.single.bytes == null) {
          setUploading(false);
          return;
        }
        final f = result.files.single;
        bytes = f.bytes!;
        filename = f.name; // non-nullable
        final ext = f.extension ?? 'jpg';
        contentType = _guessContentType(ext);
      } else {
        final picker = ImagePicker();
        final xfile = await picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 92,
        );
        if (xfile == null) {
          setUploading(false);
          return;
        }
        filename = xfile.name;
        bytes = await xfile.readAsBytes();
        final dot = filename.lastIndexOf('.');
        final ext = (dot >= 0 && dot < filename.length - 1)
            ? filename.substring(dot + 1)
            : 'jpg';
        contentType = _guessContentType(ext);
      }

      // อัปโหลดขึ้น Storage
      final url = await _uploadBytes(
        bytes,
        filename,
        bucketFolder: forCover ? 'mangas/covers' : 'mangas/backgrounds',
        contentType: contentType,
        onProgress: (p) {
          progress = p;
          // โชว์ progress ด้วย SnackBar อย่างง่าย
          // (จะไม่สแปม: โชว์เฉพาะ milestone)
          if (p == 1 || p >= 0.25 && p < 0.27 || p >= 0.5 && p < 0.52 || p >= 0.75 && p < 0.77) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                duration: const Duration(milliseconds: 600),
                content: Text(
                  'กำลังอัปโหลด ${forCover ? 'ปก' : 'พื้นหลัง'} ${(p * 100).toStringAsFixed(0)}%',
                ),
              ),
            );
          }
        },
      );

      if (url == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('อัปโหลดไม่สำเร็จ')),
        );
        setUploading(false);
        return;
      }

      // ใส่ URL กลับเข้า TextField ให้เลย
      if (forCover) {
        _coverController.text = url;
      } else {
        _backgroundController.text = url;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('อัปโหลด${forCover ? 'ปก' : 'พื้นหลัง'}สำเร็จ ${(progress * 100).toStringAsFixed(0)}%'),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('อัปโหลดไม่สำเร็จ: $e')),
      );
    } finally {
      setUploading(false);
    }
  }

  void _previewImage(String url) {
    if (!_isHttpUrl(url)) return;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 5,
                child: Center(
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    width: double.infinity,
                    height: double.infinity,
                    errorBuilder: (_, __, ___) => const Icon(Icons.error, color: Colors.white),
                    loadingBuilder: (c, child, prog) =>
                        prog == null ? child : const Center(child: CircularProgressIndicator()),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 8,
              top: 8,
              child: IconButton(
                onPressed: () => Navigator.pop(ctx),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------- Save to Realtime DB --------------------
  Future<void> addManga() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      isLoading = true;
    });

    try {
      final databaseRef = FirebaseDatabase.instance.ref('mangas');

      // หา index ถัดไป (แบบลิสต์ 1-based โดยเว้น index 0 เป็น null)
      final snapshot = await databaseRef.get();
      int nextIndex = 1;

      if (snapshot.exists) {
        final val = snapshot.value;
        if (val is List) {
          // ถ้าโครงสร้างเป็นลิสต์และช่อง 0 อาจเป็น null -> เพิ่มต่อท้าย
          nextIndex = val.length;
        } else if (val is Map) {
          // ถ้าเป็น map ของสตริงอินเด็กซ์ => หา max + 1
          final keys = val.keys
              .map((e) => int.tryParse(e.toString()))
              .where((e) => e != null)
              .cast<int>()
              .toList();
          if (keys.isNotEmpty) {
            keys.sort();
            nextIndex = keys.last + 1;
          }
        }
      }

      await databaseRef.child(nextIndex.toString()).set({
        'name': _nameController.text.trim(),
        'cover': _coverController.text.trim(),        // ใส่ URL ที่พิมพ์หรืออัปโหลดแล้ว
        'background': _backgroundController.text.trim(), // optional
        'chapters': [null], // เริ่มด้วย null เพื่อให้ chapter index เริ่มที่ 1
        'createdAt': ServerValue.timestamp,
        'updatedAt': ServerValue.timestamp,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('เพิ่มเรื่องใหม่สำเร็จ!')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // -------------------- UI --------------------
  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(borderSide: BorderSide(color: Colors.grey[600]!));

    return Scaffold(
      appBar: AppBar(
        title: const Text('เพิ่มเรื่องใหม่'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.grey[900],
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // ชื่อเรื่อง
            TextFormField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'ชื่อเรื่อง',
                labelStyle: const TextStyle(color: Colors.white),
                enabledBorder: border,
                focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.blue)),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'กรุณาใส่ชื่อเรื่อง' : null,
            ),
            const SizedBox(height: 16),

            // URL ปก + ปุ่มอัปโหลด + ปุ่มพรีวิว
            Text('รูปปก (ใส่ URL หรืออัปโหลด)', style: TextStyle(color: Colors.grey[300])),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _coverController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'วางลิงก์รูปปก หรือกดปุ่มอัปโหลด',
                      hintStyle: TextStyle(color: Colors.white70),
                      enabledBorder: border,
                      focusedBorder:
                          const OutlineInputBorder(borderSide: BorderSide(color: Colors.blue)),
                      suffixIcon: IconButton(
                        tooltip: 'พรีวิว',
                        icon: const Icon(Icons.visibility),
                        onPressed: _isHttpUrl(_coverController.text)
                            ? () => _previewImage(_coverController.text.trim())
                            : null,
                      ),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'กรุณาใส่ URL รูปปก หรืออัปโหลด' : null,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _coverUploading ? null : () => _pickAndUpload(forCover: true),
                  icon: _coverUploading
                      ? const SizedBox(
                          width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.file_upload),
                  label: const Text('อัปโหลด'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // URL พื้นหลัง + ปุ่มอัปโหลด + ปุ่มพรีวิว
            Text('รูปพื้นหลัง (ใส่ URL หรืออัปโหลด) — ไม่บังคับ',
                style: TextStyle(color: Colors.grey[300])),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _backgroundController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'วางลิงก์รูปพื้นหลัง หรือกดปุ่มอัปโหลด',
                      hintStyle: TextStyle(color: Colors.white70),
                      enabledBorder: border,
                      focusedBorder:
                          const OutlineInputBorder(borderSide: BorderSide(color: Colors.blue)),
                      suffixIcon: IconButton(
                        tooltip: 'พรีวิว',
                        icon: const Icon(Icons.visibility),
                        onPressed: _isHttpUrl(_backgroundController.text)
                            ? () => _previewImage(_backgroundController.text.trim())
                            : null,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _bgUploading ? null : () => _pickAndUpload(forCover: false),
                  icon: _bgUploading
                      ? const SizedBox(
                          width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.file_upload),
                  label: const Text('อัปโหลด'),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ปุ่มบันทึก
            ElevatedButton(
              onPressed: (isLoading || _coverUploading || _bgUploading) ? null : addManga,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
              ),
              child: isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('เพิ่มเรื่อง'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _coverController.dispose();
    _backgroundController.dispose();
    super.dispose();
  }
}

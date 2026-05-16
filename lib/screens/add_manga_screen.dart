import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:Twebtoon/services/api_service.dart';

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
      default:
        return 'image/jpeg';
    }
  }

  Future<void> _pickAndUpload({required bool forCover}) async {
    void setUploading(bool v) => setState(() {
          if (forCover) { _coverUploading = v; } else { _bgUploading = v; }
        });

    setUploading(true);
    try {
      Uint8List? bytes;
      String filename = 'image.jpg';

      if (kIsWeb) {
        final result = await FilePicker.platform.pickFiles(
            type: FileType.image, allowMultiple: false, withData: true);
        if (result == null || result.files.isEmpty || result.files.single.bytes == null) {
          setUploading(false);
          return;
        }
        final f = result.files.single;
        bytes = f.bytes!;
        filename = f.name;
      } else {
        final picker = ImagePicker();
        final xfile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 92);
        if (xfile == null) { setUploading(false); return; }
        filename = xfile.name;
        bytes = await xfile.readAsBytes();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('กำลังอัปโหลด${forCover ? 'ปก' : 'พื้นหลัง'}...'),
          duration: const Duration(seconds: 30),
        ));
      }

      final response = await ApiService.uploadBytes(
        bytes: bytes,
        filename: filename,
        purpose: forCover ? 'manga_cover' : 'manga_background',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final url = json['url'] as String?;
        if (url != null) {
          if (forCover) { _coverController.text = url; }
          else { _backgroundController.text = url; }
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('อัปโหลด${forCover ? 'ปก' : 'พื้นหลัง'}สำเร็จ')));
        }
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('อัปโหลดไม่สำเร็จ')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('อัปโหลดไม่สำเร็จ: $e')));
      }
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
                  child: Image.network(url, fit: BoxFit.contain,
                      width: double.infinity, height: double.infinity,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.error, color: Colors.white),
                      loadingBuilder: (c, child, prog) =>
                          prog == null ? child : const Center(child: CircularProgressIndicator())),
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

  Future<void> addManga() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => isLoading = true);

    try {
      final response = await ApiService.post('/api/v1/mangas', {
        'name': _nameController.text.trim(),
        'coverUrl': _coverController.text.trim(),
        'backgroundUrl': _backgroundController.text.trim(),
      });

      if (!mounted) return;
      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('เพิ่มเรื่องใหม่สำเร็จ!')));
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('บันทึกไม่สำเร็จ (${response.statusCode})')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _coverController.dispose();
    _backgroundController.dispose();
    super.dispose();
  }

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
            TextFormField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'ชื่อเรื่อง',
                labelStyle: const TextStyle(color: Colors.white),
                enabledBorder: border,
                focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.blue)),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'กรุณาใส่ชื่อเรื่อง' : null,
            ),
            const SizedBox(height: 16),
            Text('รูปปก (ใส่ URL หรืออัปโหลด)',
                style: TextStyle(color: Colors.grey[300])),
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
                      focusedBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.blue)),
                      suffixIcon: IconButton(
                        tooltip: 'พรีวิว',
                        icon: const Icon(Icons.visibility),
                        onPressed: _isHttpUrl(_coverController.text)
                            ? () => _previewImage(_coverController.text.trim())
                            : null,
                      ),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'กรุณาใส่ URL รูปปก หรืออัปโหลด'
                        : null,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed:
                      _coverUploading ? null : () => _pickAndUpload(forCover: true),
                  icon: _coverUploading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.file_upload),
                  label: const Text('อัปโหลด'),
                ),
              ],
            ),
            const SizedBox(height: 16),
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
                      focusedBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.blue)),
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
                  onPressed:
                      _bgUploading ? null : () => _pickAndUpload(forCover: false),
                  icon: _bgUploading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.file_upload),
                  label: const Text('อัปโหลด'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed:
                  (isLoading || _coverUploading || _bgUploading) ? null : addManga,
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50)),
              child: isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('เพิ่มเรื่อง'),
            ),
          ],
        ),
      ),
    );
  }
}

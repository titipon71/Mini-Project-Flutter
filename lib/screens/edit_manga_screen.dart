import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:Twebtoon/services/api_service.dart';

class EditMangaScreen extends StatefulWidget {
  final int mangaId;
  final String? initialName;
  final String? initialCover;
  final String? initialBackground;

  const EditMangaScreen({
    Key? key,
    required this.mangaId,
    this.initialName,
    this.initialCover,
    this.initialBackground,
  }) : super(key: key);

  @override
  State<EditMangaScreen> createState() => _EditMangaScreenState();
}

class _EditMangaScreenState extends State<EditMangaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _coverController = TextEditingController();
  final _backgroundController = TextEditingController();

  bool _isLoading = false;
  Uint8List? _coverBytes;
  Uint8List? _backgroundBytes;
  String? _coverPickedName;
  String? _bgPickedName;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.initialName ?? '';
    _coverController.text = widget.initialCover ?? '';
    _backgroundController.text = widget.initialBackground ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _coverController.dispose();
    _backgroundController.dispose();
    super.dispose();
  }

  void _openImageFullScreen({Uint8List? bytes, String? url, required String heroTag}) {
    if (bytes == null && (url == null || url.isEmpty)) return;

    final ImageProvider provider =
        bytes != null ? MemoryImage(bytes) : NetworkImage(url!) as ImageProvider;

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.9),
      barrierDismissible: true,
      builder: (_) {
        return GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Stack(
            children: [
              Center(
                child: Hero(
                  tag: heroTag,
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: Image(image: provider, fit: BoxFit.contain),
                  ),
                ),
              ),
              const Positioned(
                top: 24,
                right: 24,
                child: Icon(Icons.close, color: Colors.white70, size: 28),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickImage(bool isCover) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          if (isCover) {
            _coverBytes = bytes;
            _coverPickedName = image.name;
          } else {
            _backgroundBytes = bytes;
            _bgPickedName = image.name;
          }
        });
      }
    } catch (e) {
      _showSnackBar('เกิดข้อผิดพลาดในการเลือกรูปภาพ: $e');
    }
  }

  Future<String?> _uploadImage(Uint8List bytes, String filename, String purpose) async {
    try {
      final response = await ApiService.uploadBytes(
        bytes: bytes,
        filename: filename,
        purpose: purpose,
      );
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return json['url'] as String?;
      }
      _showSnackBar('เกิดข้อผิดพลาดในการอัปโหลดรูปภาพ (${response.statusCode})');
      return null;
    } catch (e) {
      _showSnackBar('เกิดข้อผิดพลาดในการอัปโหลดรูปภาพ: $e');
      return null;
    }
  }

  Future<void> _saveManga() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      String coverUrl = _coverController.text;
      String backgroundUrl = _backgroundController.text;

      if (_coverBytes != null && _coverPickedName != null) {
        final uploadedUrl = await _uploadImage(_coverBytes!, _coverPickedName!, 'manga_cover');
        if (uploadedUrl != null) coverUrl = uploadedUrl;
      }

      if (_backgroundBytes != null && _bgPickedName != null) {
        final uploadedUrl = await _uploadImage(_backgroundBytes!, _bgPickedName!, 'manga_background');
        if (uploadedUrl != null) backgroundUrl = uploadedUrl;
      }

      final response = await ApiService.patch(
        '/api/v1/mangas/${widget.mangaId}',
        {
          'name': _nameController.text.trim(),
          'coverUrl': coverUrl,
          'backgroundUrl': backgroundUrl,
        },
      );

      if (!mounted) return;
      if (response.statusCode == 200) {
        _showSnackBar('บันทึกข้อมูลสำเร็จ');
        Navigator.of(context).pop(true);
      } else {
        _showSnackBar('บันทึกไม่สำเร็จ (${response.statusCode})');
      }
    } catch (e) {
      _showSnackBar('เกิดข้อผิดพลาดในการบันทึก: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: const Text('แก้ไขมังงะ', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.grey[850],
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2)),
            )
          else
            TextButton(
              onPressed: _saveManga,
              child: const Text('บันทึก',
                  style: TextStyle(color: Colors.white, fontSize: 16)),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('ชื่อมังงะ',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'กรอกชื่อมังงะ',
                  hintStyle: const TextStyle(color: Colors.white60),
                  filled: true,
                  fillColor: Colors.grey[800],
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'กรุณาใส่ชื่อมังงะ';
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // รูปปก
              const Text('รูปปก',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(8)),
                child: _coverBytes != null
                    ? InkWell(
                        onTap: () => _openImageFullScreen(
                            bytes: _coverBytes, heroTag: 'cover-hero'),
                        child: Hero(
                          tag: 'cover-hero',
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(_coverBytes!, fit: BoxFit.cover),
                          ),
                        ),
                      )
                    : _coverController.text.isNotEmpty
                        ? InkWell(
                            onTap: () => _openImageFullScreen(
                                url: _coverController.text, heroTag: 'cover-hero'),
                            child: Hero(
                              tag: 'cover-hero',
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(_coverController.text,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Center(
                                        child: Icon(Icons.image_not_supported,
                                            color: Colors.white60, size: 48))),
                              ),
                            ),
                          )
                        : const Center(
                            child:
                                Icon(Icons.image, color: Colors.white60, size: 48)),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _coverController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'URL รูปปก',
                        hintStyle: const TextStyle(color: Colors.white60),
                        filled: true,
                        fillColor: Colors.grey[800],
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _pickImage(true),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('เลือกรูป'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[600],
                        foregroundColor: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // รูปพื้นหลัง
              const Text('รูปพื้นหลัง',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(8)),
                child: _backgroundBytes != null
                    ? InkWell(
                        onTap: () => _openImageFullScreen(
                            bytes: _backgroundBytes, heroTag: 'bg-hero'),
                        child: Hero(
                          tag: 'bg-hero',
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child:
                                Image.memory(_backgroundBytes!, fit: BoxFit.cover),
                          ),
                        ),
                      )
                    : _backgroundController.text.isNotEmpty
                        ? InkWell(
                            onTap: () => _openImageFullScreen(
                                url: _backgroundController.text, heroTag: 'bg-hero'),
                            child: Hero(
                              tag: 'bg-hero',
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(_backgroundController.text,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Center(
                                        child: Icon(Icons.image_not_supported,
                                            color: Colors.white60, size: 48))),
                              ),
                            ),
                          )
                        : const Center(
                            child: Icon(Icons.wallpaper,
                                color: Colors.white60, size: 48)),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _backgroundController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'URL รูปพื้นหลัง',
                        hintStyle: const TextStyle(color: Colors.white60),
                        filled: true,
                        fillColor: Colors.grey[800],
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _pickImage(false),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('เลือกรูป'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[600],
                        foregroundColor: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveManga,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[600],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('บันทึกการเปลี่ยนแปลง',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

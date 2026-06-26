import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:Twebtoon/services/api_service.dart';

class EditWebsiteInfoScreen extends StatefulWidget {
  const EditWebsiteInfoScreen({super.key});

  @override
  State<EditWebsiteInfoScreen> createState() => _EditWebsiteInfoScreenState();
}

class _EditWebsiteInfoScreenState extends State<EditWebsiteInfoScreen> {
  List<String> imageList = [];
  bool isLoading = true;
  bool isSaving = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  Future<void> _loadImages() async {
    try {
      final response = await ApiService.get('/api/v1/website-info');
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final images = (json['carouselImages'] as List<dynamic>?)
                ?.whereType<String>()
                .where((s) => s.isNotEmpty)
                .toList() ??
            [];
        if (mounted) setState(() { imageList = images; isLoading = false; });
      } else {
        if (mounted) setState(() { imageList = []; isLoading = false; });
      }
    } catch (e) {
      _showSnackBar('เกิดข้อผิดพลาดในการโหลดข้อมูล: $e');
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _addImagesFromGalleryMulti() async {
    try {
      List<XFile> images = [];

      if (kIsWeb) {
        final result = await FilePicker.platform
            .pickFiles(type: FileType.image, allowMultiple: true, withData: true);
        if (result == null || result.files.isEmpty) return;
        images = result.files
            .where((f) => f.bytes != null)
            .map((f) => XFile.fromData(f.bytes!, name: f.name))
            .toList();
      } else {
        images = await _picker.pickMultiImage(maxWidth: 1024, maxHeight: 1024, imageQuality: 85);
        if (images.isEmpty) return;
      }

      // show progress dialog
      int done = 0;
      final total = images.length;

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => StatefulBuilder(
            builder: (context, setStateDialog) => AlertDialog(
              backgroundColor: Colors.grey[900],
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('กำลังอัปโหลด...', style: TextStyle(color: Colors.white)),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(value: total == 0 ? null : done / total),
                  const SizedBox(height: 8),
                  Text('$done / $total', style: const TextStyle(color: Colors.white70)),
                ],
              ),
            ),
          ),
        );
      }

      final List<String> newUrls = [];
      for (final image in images) {
        final bytes = await image.readAsBytes();
        final response = await ApiService.uploadBytes(
          bytes: bytes,
          filename: image.name,
          purpose: UploadPurpose.carouselImage,
        );
        final url = ApiService.parseUploadUrl(response);
        if (url != null) newUrls.add(url);
        done++;
      }

      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      if (mounted) {
        setState(() => imageList.addAll(newUrls));
        _showSnackBar('อัปโหลดรูปสำเร็จ ${newUrls.length} รูป');
      }
    } catch (e) {
      if (mounted && Navigator.of(context).canPop()) Navigator.of(context).pop();
      _showSnackBar('เกิดข้อผิดพลาดในการอัปโหลดหลายรูป: $e');
    }
  }

  Future<void> _saveImages() async {
    setState(() => isSaving = true);
    try {
      final response = await ApiService.patch('/api/v1/website-info', {
        'carouselImages': imageList,
      });
      if (!mounted) return;
      if (response.statusCode == 200) {
        _showSnackBar('บันทึกข้อมูลสำเร็จ');
        Navigator.pop(context);
      } else {
        _showSnackBar('บันทึกไม่สำเร็จ (${response.statusCode})');
      }
    } catch (e) {
      _showSnackBar('เกิดข้อผิดพลาดในการบันทึก: $e');
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  void _addImageFromUrl() {
    final urlController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('เพิ่มรูปภาพจาก URL', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: urlController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'ใส่ URL ของรูปภาพ',
            hintStyle: const TextStyle(color: Colors.white60),
            filled: true,
            fillColor: Colors.grey[800],
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('ยกเลิก', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () {
              final url = urlController.text.trim();
              if (url.isNotEmpty) {
                setState(() => imageList.add(url));
                Navigator.of(context).pop();
                _showSnackBar('เพิ่มรูปภาพสำเร็จ');
              }
            },
            child: const Text('เพิ่ม', style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );
  }

  void _removeImage(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('ยืนยันการลบ', style: TextStyle(color: Colors.white)),
        content: const Text('คุณต้องการลบรูปภาพนี้หรือไม่?',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('ยกเลิก', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () {
              setState(() => imageList.removeAt(index));
              Navigator.of(context).pop();
              _showSnackBar('ลบรูปภาพสำเร็จ');
            },
            child: const Text('ลบ', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _editImageUrl(int index) {
    final urlController = TextEditingController(text: imageList[index]);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('แก้ไข URL รูปภาพ', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: urlController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'แก้ไข URL ของรูปภาพ',
            hintStyle: const TextStyle(color: Colors.white60),
            filled: true,
            fillColor: Colors.grey[800],
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('ยกเลิก', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () {
              final url = urlController.text.trim();
              if (url.isNotEmpty) {
                setState(() => imageList[index] = url);
                Navigator.of(context).pop();
                _showSnackBar('แก้ไขรูปภาพสำเร็จ');
              }
            },
            child: const Text('บันทึก', style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );
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
        title: const Text('จัดการรูปภาพเว็บไซต์', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.grey[850],
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (isSaving)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
            )
          else
            TextButton(
              onPressed: _saveImages,
              child: const Text('บันทึก',
                  style: TextStyle(color: Colors.white, fontSize: 16)),
            ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _addImagesFromGalleryMulti,
                          icon: const Icon(Icons.collections),
                          label: const Text('อัปโหลดรูป'),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purple,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _addImageFromUrl,
                          icon: const Icon(Icons.link),
                          label: const Text('เพิ่มจาก URL'),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green[600],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12)),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: imageList.isEmpty
                      ? const Center(
                          child: Text(
                            'ไม่มีรูปภาพ\nกดปุ่มเพิ่มเพื่อเพิ่มรูปภาพ',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white70, fontSize: 16),
                          ),
                        )
                      : ReorderableListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: imageList.length,
                          onReorder: (oldIndex, newIndex) {
                            setState(() {
                              if (newIndex > oldIndex) newIndex -= 1;
                              final item = imageList.removeAt(oldIndex);
                              imageList.insert(newIndex, item);
                            });
                          },
                          itemBuilder: (context, index) {
                            final imageUrl = imageList[index];
                            return Card(
                              key: ValueKey('$imageUrl$index'),
                              color: Colors.grey[800],
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              child: ListTile(
                                leading: Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      color: Colors.grey[700]),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(imageUrl, fit: BoxFit.cover,
                                        loadingBuilder: (_, child, prog) =>
                                            prog == null
                                                ? child
                                                : const Center(
                                                    child: SizedBox(
                                                        width: 20,
                                                        height: 20,
                                                        child: CircularProgressIndicator(
                                                            strokeWidth: 2))),
                                        errorBuilder: (_, __, ___) => const Icon(
                                            Icons.broken_image,
                                            color: Colors.white70)),
                                  ),
                                ),
                                title: Text('รูปที่ ${index + 1}',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold)),
                                subtitle: Text(
                                  imageUrl.length > 50
                                      ? '${imageUrl.substring(0, 50)}...'
                                      : imageUrl,
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 12),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      onPressed: () => _editImageUrl(index),
                                      icon: const Icon(Icons.edit, color: Colors.orange),
                                      tooltip: 'แก้ไข',
                                    ),
                                    IconButton(
                                      onPressed: () => _removeImage(index),
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      tooltip: 'ลบ',
                                    ),
                                    const Icon(Icons.drag_handle, color: Colors.white70),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.grey[850],
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('จำนวนรูปภาพทั้งหมด: ${imageList.length}',
                          style: const TextStyle(color: Colors.white70)),
                      const Text('ลากเพื่อเรียงลำดับ',
                          style: TextStyle(color: Colors.white54, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

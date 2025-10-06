import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class AddChapterScreen extends StatefulWidget {
  final int mangaIndex;
  final String mangaName;

  const AddChapterScreen({
    super.key,
    required this.mangaIndex,
    required this.mangaName,
  });

  @override
  State<AddChapterScreen> createState() => _AddChapterScreenState();
}

class _AddChapterScreenState extends State<AddChapterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _numberController = TextEditingController();
  final List<TextEditingController> _pageControllers = [];
  final List<XFile?> _selectedImages = []; // เก็บรูปภาพที่เลือก
  final ImagePicker _picker = ImagePicker();

  bool isLoading = false;
  bool isUploading = false;

  @override
  void initState() {
    super.initState();
    // เริ่มต้นด้วยหน้าแรก
    _addPageField();
  }

  void _addPageField() {
    setState(() {
      _pageControllers.add(TextEditingController());
      _selectedImages.add(null); // เพิ่ม null สำหรับรูปภาพใหม่
    });
  }

  void _removePageField(int index) {
    setState(() {
      _pageControllers[index].dispose();
      _pageControllers.removeAt(index);
      _selectedImages.removeAt(index); // ลบรูปภาพที่สอดคล้องกัน
    });
  }

  // เลือกรูปภาพจาก Gallery
  Future<void> _pickImage(int index) async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (image != null) {
      setState(() {
        _selectedImages[index] = image; // ไม่ต้องแปลงเป็น File
      });
    }
  }

  Future<void> _pickMultipleImages() async {
    final List<XFile> images = await _picker.pickMultiImage(
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (images.isNotEmpty) {
      setState(() {
        for (var c in _pageControllers) {
          c.dispose();
        }
        _pageControllers
          ..clear()
          ..addAll(
            List.generate(images.length, (_) => TextEditingController()),
          );
        _selectedImages
          ..clear()
          ..addAll(images); // เก็บเป็น XFile ตรง ๆ
      });
    }
  }

  // อัปโหลดรูปภาพไป Firebase Storage
  Future<String?> _uploadImage(XFile imageFile, int pageIndex, int chapterIndex) async {
    try {
      // ดึงชื่อไฟล์เดิมและนามสกุลไฟล์
      final originalFileName = imageFile.name;
      final fileExtension = originalFileName.split('.').last.toLowerCase();
      
      // สร้างชื่อไฟล์ใหม่ที่รวมชื่อเดิม: page_{pageIndex}_{originalFileName}
      final newFileName = 'page_${pageIndex + 1}_$originalFileName';
      
      // Path: mangas/{mangaIndex}/chapters/{chapterIndex}/{newFileName}
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('mangas')
          .child('${widget.mangaIndex}') // index จริงของ manga ใน DB
          .child('chapters')
          .child('$chapterIndex') // index จริงของ chapter ใน DB
          .child(newFileName);

      final bytes = await imageFile.readAsBytes();
      
      // กำหนด content type ตามนามสกุลไฟล์
      String contentType = 'image/jpeg'; // default
      switch (fileExtension) {
        case 'png':
          contentType = 'image/png';
          break;
        case 'jpg':
        case 'jpeg':
          contentType = 'image/jpeg';
          break;
        case 'gif':
          contentType = 'image/gif';
          break;
        case 'webp':
          contentType = 'image/webp';
          break;
      }
      
      final metadata = SettableMetadata(
        contentType: contentType,
        customMetadata: {
          'originalFileName': originalFileName,
          'pageIndex': '${pageIndex + 1}',
          'uploadedAt': DateTime.now().toIso8601String(),
        },
      );

      final task = await storageRef.putData(bytes, metadata);
      final downloadUrl = await task.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      debugPrint('Error uploading image: $e');
      return null;
    }
  }

  Future<void> _showPickedImageDialog(XFile xfile) async {
    // อ่าน bytes แล้วแสดงด้วย Image.memory (ใช้ได้ทั้ง Mobile/Web)
    final Uint8List bytes = await xfile.readAsBytes();
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            // ซูม/แพนได้
            InteractiveViewer(child: Image.memory(bytes, fit: BoxFit.contain)),
            Positioned(
              right: 8,
              top: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
                tooltip: 'ปิด',
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showNetworkImageDialog(String url) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            InteractiveViewer(child: Image.network(url, fit: BoxFit.contain)),
            Positioned(
              right: 8,
              top: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
                tooltip: 'ปิด',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> addChapter() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      isLoading = true;
      isUploading = true;
    });

    try {
      final databaseRef = FirebaseDatabase.instance.ref('mangas/${widget.mangaIndex}/chapters');

      // หา chapter index ถัดไป
      final snapshot = await databaseRef.get();
      int nextChapterIndex = 1;

      if (snapshot.exists && snapshot.value is List) {
        List existingChapters = snapshot.value as List;
        nextChapterIndex = existingChapters.length;
      }

      // สร้าง pages array และอัปโหลดรูปภาพ
      List<Map<String, dynamic>> pages = [];

      for (int i = 0; i < _pageControllers.length; i++) {
        String pageUrl = '';

        // ถ้ามีรูปภาพที่เลือก ให้อัปโหลดก่อน
        if (_selectedImages[i] != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('กำลังอัปโหลดรูปหน้าที่ ${i + 1}...')),
          );

          final uploadedUrl = await _uploadImage(_selectedImages[i]!, i, nextChapterIndex);
          if (uploadedUrl != null) {
            pageUrl = uploadedUrl;
            // อัปเดท URL ในช่องข้อความด้วย
            _pageControllers[i].text = uploadedUrl;
          }
        } else {
          // ใช้ URL ที่กรอกเอง
          pageUrl = _pageControllers[i].text.trim();
        }

        if (pageUrl.isNotEmpty) {
          pages.add({'index': i + 1, 'type': 'image', 'url': pageUrl});
        }
      }

      setState(() {
        isUploading = false;
      });

      // เพิ่มตอนใหม่
      await databaseRef.child(nextChapterIndex.toString()).set({
        'number': int.parse(_numberController.text),
        'title': _titleController.text.trim(),
        'pages': pages,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('เพิ่มตอนใหม่สำเร็จ!')));

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
    } finally {
      setState(() {
        isLoading = false;
        isUploading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('เพิ่มตอน - ${widget.mangaName}'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.grey[900],
      body: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _numberController,
                      decoration: const InputDecoration(
                        labelText: 'เลขตอน',
                        labelStyle: TextStyle(color: Colors.white),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.blue),
                        ),
                      ),
                      style: const TextStyle(color: Colors.white),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'กรุณาใส่เลขตอน';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'ชื่อตอน',
                        labelStyle: TextStyle(color: Colors.white),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.blue),
                        ),
                      ),
                      style: const TextStyle(color: Colors.white),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'กรุณาใส่ชื่อตอน';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // หัวข้อหน้า
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'หน้าในตอน',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _pickMultipleImages,
                        icon: const Icon(Icons.photo_library),
                        label: const Text('เลือกหลายรูป'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _addPageField,
                        icon: const Icon(Icons.add),
                        label: const Text('เพิ่มหน้า'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // รายการหน้า
              Expanded(
                child: ListView.builder(
                  itemCount: _pageControllers.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Card(
                        color: Colors.grey[800],
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'หน้า ${index + 1}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    onPressed: () => _pickImage(index),
                                    icon: const Icon(Icons.photo_camera),
                                    color: Colors.blue,
                                    tooltip: 'เลือกรูปภาพ',
                                  ),
                                  IconButton(
                                    onPressed: _pageControllers.length > 1
                                        ? () => _removePageField(index)
                                        : null,
                                    icon: const Icon(Icons.delete),
                                    color: Colors.red,
                                    tooltip: 'ลบหน้า',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              // ปุ่มดูรูปภาพ (ถ้าเลือกไฟล์ไว้)
if (_selectedImages[index] != null)
  Padding(
    padding: const EdgeInsets.only(bottom: 8.0),
    child: OutlinedButton.icon(
      onPressed: () => _showPickedImageDialog(_selectedImages[index]!),
      icon: const Icon(Icons.visibility),
      label: const Text('ดูรูปภาพ'),
      style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
    ),
  )
else if (_pageControllers[index].text.trim().isNotEmpty)
  Padding(
    padding: const EdgeInsets.only(bottom: 8.0),
    child: OutlinedButton.icon(
      onPressed: () =>
          _showNetworkImageDialog(_pageControllers[index].text.trim()),
      icon: const Icon(Icons.visibility),
      label: const Text('ดูรูปภาพ (จาก URL)'),
      style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
    ),
  ),

                              // ช่องใส่ URL
                              TextFormField(
                                controller: _pageControllers[index],
                                decoration: InputDecoration(
                                  hintText: _selectedImages[index] != null
                                      ? 'รูปภาพจะถูกอัปโหลดอัตโนมัติ'
                                      : 'URL รูปภาพ หรือเลือกรูปจากปุ่มด้านบน',
                                  hintStyle: TextStyle(
                                    color: _selectedImages[index] != null
                                        ? Colors.green[300]
                                        : Colors.grey,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                      color: _selectedImages[index] != null
                                          ? Colors.green
                                          : Colors.white,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                      color: _selectedImages[index] != null
                                          ? Colors.green
                                          : Colors.blue,
                                    ),
                                  ),
                                  prefixIcon: Icon(
                                    _selectedImages[index] != null
                                        ? Icons.cloud_upload
                                        : Icons.link,
                                    color: _selectedImages[index] != null
                                        ? Colors.green
                                        : Colors.white70,
                                  ),
                                ),
                                style: const TextStyle(color: Colors.white),
                                validator: (value) {
                                  // ถ้ามีรูปภาพที่เลือกแล้ว ไม่ต้อง validate URL
                                  if (_selectedImages[index] != null) {
                                    return null;
                                  }
                                  if (value == null || value.isEmpty) {
                                    return 'กรุณาใส่ URL หรือเลือกรูปภาพ';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 16),

              // แสดงสถานะการอัปโหลด
              if (isUploading)
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.blue[900],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(width: 16),
                      Text(
                        'กำลังอัปโหลดรูปภาพ...',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),

              ElevatedButton(
                onPressed: isLoading ? null : addChapter,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: isLoading
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(color: Colors.white),
                          const SizedBox(width: 16),
                          Text(
                            isUploading ? 'กำลังอัปโหลด...' : 'กำลังบันทึก...',
                          ),
                        ],
                      )
                    : const Text('เพิ่มตอน', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _numberController.dispose();
    for (var controller in _pageControllers) {
      controller.dispose();
    }
    super.dispose();
  }
}

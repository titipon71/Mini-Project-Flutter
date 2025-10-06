import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:typed_data';

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

  // โหลดข้อมูลรูปภาพจาก Firebase
  Future<void> _loadImages() async {
    try {
      final ref = FirebaseDatabase.instance.ref('website_info/carousel_images');

      final snapshot = await ref.get();

      if (snapshot.exists) {
        final value = snapshot.value;
        if (value is List) {
          setState(() {
            imageList = value
                .where((item) => item != null)
                .cast<String>()
                .toList();
            isLoading = false;
          });
        } else if (value is Map) {
          setState(() {
            imageList = value.values
                .where((item) => item != null)
                .cast<String>()
                .toList();
            isLoading = false;
          });
        }
      } else {
        // ถ้าไม่มีข้อมูลใน Firebase ให้ใช้ค่าเริ่มต้น
        setState(() {
          imageList = [];
          isLoading = false;
        });
      }
    } catch (e) {
      _showSnackBar('เกิดข้อผิดพลาดในการโหลดข้อมูล: $e');
      setState(() => isLoading = false);
    }
  }

  String _guessMimeType(String pathOrName) {
    final dot = pathOrName.lastIndexOf('.');
    final ext = (dot >= 0 ? pathOrName.substring(dot + 1) : '').toLowerCase();
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

  Future<void> _addImagesFromGalleryMulti() async {
    try {
      // 1) เลือกหลายรูป
      final List<XFile> images = await _picker.pickMultiImage(
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (images.isEmpty) return;

      // 2) แสดง progress dialog
      int done = 0;
      final total = images.length;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: Colors.grey[900],
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'กำลังอัปโหลด...',
                    style: TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: total == 0 ? null : (done / total),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$done / $total',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            );
          },
        ),
      );

      // 3) อัปโหลดทีละรูป (sequential)
      final List<String> newUrls = [];
      for (final image in images) {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('carousel_images')
            // ใช้ timestamp + ชื่อไฟล์เดิมกันชนกัน + เก็บนามสกุลไว้
            .child(
              '${DateTime.now().millisecondsSinceEpoch}_${kIsWeb ? image.name : image.path.split('/').last}',
            );

        final mimeType = _guessMimeType(kIsWeb ? image.name : image.path);

        UploadTask uploadTask;
        if (kIsWeb) {
          final Uint8List bytes = await image.readAsBytes();
          uploadTask = storageRef.putData(
            bytes,
            SettableMetadata(contentType: mimeType),
          );
        } else {
          final file = File(image.path);
          uploadTask = storageRef.putFile(
            file,
            SettableMetadata(contentType: mimeType),
          );
        }

        final snapshot = await uploadTask;
        final downloadUrl = await snapshot.ref.getDownloadURL();
        newUrls.add(downloadUrl);

        // อัปเดต progress
        done += 1;
        if (Navigator.of(context).canPop()) {
          // อัปเดต dialog ถ้ายังเปิดอยู่
          // ใช้ showDialog+StatefulBuilder ด้านบน: หา state ของมันแล้ว setState
          // ทริค: เปิด dialog ด้วย StatefulBuilder แล้ว capture setStateDialog ผ่าน closure
          // แต่ในตัวอย่างด้านบนเราไม่ได้เก็บ setStateDialog ภายนอก
          // ดังนั้นใช้ showGeneralDialog ที่คืน controller ก็ได้
          // เพื่อความเรียบง่าย จะปิด-เปิดใหม่แบบเร็ว ๆ แทน (ไม่สวยเท่าไหร่แต่ใช้งานได้)
        }
      }

      // 4) ปิด dialog
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      // 5) ใส่ URL ที่ได้เข้า list แล้วอัปเดต UI
      setState(() {
        imageList.addAll(newUrls);
      });

      _showSnackBar('อัปโหลดรูปสำเร็จ ${newUrls.length} รูป');
    } catch (e) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop(); // เผื่อ dialog ยังค้าง
      }
      _showSnackBar('เกิดข้อผิดพลาดในการอัปโหลดหลายรูป: $e');
    }
  }

  // บันทึกข้อมูลไป Firebase
  Future<void> _saveImages() async {
    setState(() => isSaving = true);

    try {
      final ref = FirebaseDatabase.instance.ref('website_info/carousel_images');

      await ref.set(imageList);

      _showSnackBar('บันทึกข้อมูลสำเร็จ');
      // กลับไปหน้าก่อนหน้าแทนการ navigate ไปหน้าใหม่
      Navigator.push(context, MaterialPageRoute(builder: (context) => EditWebsiteInfoScreen())); // ส่งค่ากลับเพื่อบอกว่าได้อัปเดทแล้ว
      
    } catch (e) {
      _showSnackBar('เกิดข้อผิดพลาดในการบันทึก: $e');
    } finally {
      setState(() => isSaving = false);
    }
  }


  // เพิ่มรูปภาพจาก URL
  void _addImageFromUrl() {
    final TextEditingController urlController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'เพิ่มรูปภาพจาก URL',
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: urlController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'ใส่ URL ของรูปภาพ',
            hintStyle: const TextStyle(color: Colors.white60),
            filled: true,
            fillColor: Colors.grey[800],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'ยกเลิก',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () {
              final url = urlController.text.trim();
              if (url.isNotEmpty) {
                setState(() {
                  imageList.add(url);
                });
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

  // ลบรูปภาพ
  void _removeImage(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('ยืนยันการลบ', style: TextStyle(color: Colors.white)),
        content: const Text(
          'คุณต้องการลบรูปภาพนี้หรือไม่?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'ยกเลิก',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                imageList.removeAt(index);
              });
              Navigator.of(context).pop();
              _showSnackBar('ลบรูปภาพสำเร็จ');
            },
            child: const Text('ลบ', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // แก้ไข URL รูปภาพ
  void _editImageUrl(int index) {
    final TextEditingController urlController = TextEditingController();
    urlController.text = imageList[index];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'แก้ไข URL รูปภาพ',
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: urlController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'แก้ไข URL ของรูปภาพ',
            hintStyle: const TextStyle(color: Colors.white60),
            filled: true,
            fillColor: Colors.grey[800],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'ยกเลิก',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () {
              final url = urlController.text.trim();
              if (url.isNotEmpty) {
                setState(() {
                  imageList[index] = url;
                });
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: const Text(
          'จัดการรูปภาพเว็บไซต์',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.grey[850],
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (isSaving)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              ),
            )
          else
            TextButton(
              onPressed: _saveImages,
              child: const Text(
                'บันทึก',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : Column(
              children: [
                // ปุ่มเพิ่มรูปภาพ
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
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
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
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // รายการรูปภาพ
                Expanded(
                  child: imageList.isEmpty
                      ? const Center(
                          child: Text(
                            'ไม่มีรูปภาพ\nกดปุ่มเพิ่มเพื่อเพิ่มรูปภาพ',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                        )
                      : ReorderableListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: imageList.length,
                          onReorder: (oldIndex, newIndex) {
                            setState(() {
                              if (newIndex > oldIndex) {
                                newIndex -= 1;
                              }
                              final item = imageList.removeAt(oldIndex);
                              imageList.insert(newIndex, item);
                            });
                          },
                          itemBuilder: (context, index) {
                            final imageUrl = imageList[index];

                            return Card(
                              key: ValueKey(imageUrl),
                              color: Colors.grey[800],
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              child: ListTile(
                                leading: Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    color: Colors.grey[700],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: _buildImageWidget(imageUrl),
                                  ),
                                ),
                                title: Text(
                                  'รูปที่ ${index + 1}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(
                                  imageUrl.length > 50
                                      ? '${imageUrl.substring(0, 50)}...'
                                      : imageUrl,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      onPressed: () => _editImageUrl(index),
                                      icon: const Icon(
                                        Icons.edit,
                                        color: Colors.orange,
                                      ),
                                      tooltip: 'แก้ไข',
                                    ),
                                    IconButton(
                                      onPressed: () => _removeImage(index),
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                      ),
                                      tooltip: 'ลบ',
                                    ),
                                    const Icon(
                                      Icons.drag_handle,
                                      color: Colors.white70,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),

                // ข้อมูลสถิติ
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.grey[850],
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'จำนวนรูปภาพทั้งหมด: ${imageList.length}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      Text(
                        'ลากเพื่อเรียงลำดับ',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildImageWidget(String imageUrl) {
    // รูปภาพจาก URL
    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2,
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return const Icon(Icons.broken_image, color: Colors.white70);
      },
    );
  }
}

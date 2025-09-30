import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';

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
  
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    // เริ่มต้นด้วยหน้าแรก
    _addPageField();
  }

  void _addPageField() {
    setState(() {
      _pageControllers.add(TextEditingController());
    });
  }

  void _removePageField(int index) {
    setState(() {
      _pageControllers[index].dispose();
      _pageControllers.removeAt(index);
    });
  }

  Future<void> addChapter() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      isLoading = true;
    });

    try {
      final databaseRef = FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL:
            'https://flutterapp-3d291-default-rtdb.asia-southeast1.firebasedatabase.app/',
      ).ref('mangas/${widget.mangaIndex}/chapters');

      // หา chapter index ถัดไป
      final snapshot = await databaseRef.get();
      int nextChapterIndex = 1;
      
      if (snapshot.exists && snapshot.value is List) {
        List existingChapters = snapshot.value as List;
        nextChapterIndex = existingChapters.length;
      }

      // สร้าง pages array
      List<Map<String, dynamic>> pages = [];
      for (int i = 0; i < _pageControllers.length; i++) {
        String pageUrl = _pageControllers[i].text.trim();
        if (pageUrl.isNotEmpty) {
          pages.add({
            'index': i + 1,
            'type': 'image',
            'url': pageUrl,
          });
        }
      }

      // เพิ่มตอนใหม่
      await databaseRef.child(nextChapterIndex.toString()).set({
        'number': int.parse(_numberController.text),
        'title': _titleController.text.trim(),
        'pages': pages,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('เพิ่มตอนใหม่สำเร็จ!')),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
      );
    } finally {
      setState(() {
        isLoading = false;
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
              const SizedBox(height: 8),

              // รายการหน้า
              Expanded(
                child: ListView.builder(
                  itemCount: _pageControllers.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        children: [
                          Text(
                            'หน้า ${index + 1}:',
                            style: const TextStyle(color: Colors.white),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: _pageControllers[index],
                              decoration: const InputDecoration(
                                hintText: 'URL รูปภาพ',
                                hintStyle: TextStyle(color: Colors.grey),
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
                                  return 'กรุณาใส่ URL';
                                }
                                return null;
                              },
                            ),
                          ),
                          IconButton(
                            onPressed: _pageControllers.length > 1
                                ? () => _removePageField(index)
                                : null,
                            icon: const Icon(Icons.delete),
                            color: Colors.red,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: isLoading ? null : addChapter,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('เพิ่มตอน'),
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
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';

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

  Future<void> addManga() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      isLoading = true;
    });

    try {
      final databaseRef = FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL:
            'https://flutterapp-3d291-default-rtdb.asia-southeast1.firebasedatabase.app/',
      ).ref('mangas');

      // หา index ถัดไป
      final snapshot = await databaseRef.get();
      int nextIndex = 1;
      
      if (snapshot.exists && snapshot.value is List) {
        List existingMangas = snapshot.value as List;
        nextIndex = existingMangas.length;
      }

      // เพิ่มเรื่องใหม่
      await databaseRef.child(nextIndex.toString()).set({
        'name': _nameController.text.trim(),
        'cover': _coverController.text.trim(),
        'background': _backgroundController.text.trim(),
        'chapters': [null], // เริ่มต้นด้วย null เพื่อให้ index เริ่มจาก 1
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('เพิ่มเรื่องใหม่สำเร็จ!')),
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
        title: const Text('เพิ่มเรื่องใหม่'),
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
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'ชื่อเรื่อง',
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
                    return 'กรุณาใส่ชื่อเรื่อง';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _coverController,
                decoration: const InputDecoration(
                  labelText: 'URL รูปปก',
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
                    return 'กรุณาใส่ URL รูปปก';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _backgroundController,
                decoration: const InputDecoration(
                  labelText: 'URL รูปพื้นหลัง (ไม่บังคับ)',
                  labelStyle: TextStyle(color: Colors.white),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.blue),
                  ),
                ),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 32),

              ElevatedButton(
                onPressed: isLoading ? null : addManga,
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
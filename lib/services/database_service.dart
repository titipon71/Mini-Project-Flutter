import 'package:firebase_database/firebase_database.dart';

class DatabaseService {
  static DatabaseReference? _database;
  
  // Singleton pattern สำหรับ Firebase Database
  static DatabaseReference get database {
    _database ??= FirebaseDatabase.instance.ref();
    return _database!;
  }
  
  // Helper methods สำหรับการเข้าถึง path ต่างๆ
  static DatabaseReference get mangasRef => database.child('mangas');
  
  static DatabaseReference mangaRef(int mangaIndex) => 
      mangasRef.child(mangaIndex.toString());
  
  static DatabaseReference chaptersRef(int mangaIndex) => 
      mangaRef(mangaIndex).child('chapters');
      
  static DatabaseReference chapterRef(int mangaIndex, int chapterIndex) => 
      chaptersRef(mangaIndex).child(chapterIndex.toString());
}
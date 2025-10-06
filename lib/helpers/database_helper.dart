// database_helper.dart
import 'package:firebase_database/firebase_database.dart';

class DatabaseHelper {
  // ใช้ Default instance แทน instanceFor
  static DatabaseReference get database => FirebaseDatabase.instance.ref();
  
  // Helper methods
  static DatabaseReference get mangasRef => database.child('mangas');
  static DatabaseReference get websiteInfoRef => database.child('website_info');
  
  static DatabaseReference mangaRef(int mangaIndex) => 
      mangasRef.child(mangaIndex.toString());
  
  static DatabaseReference chaptersRef(int mangaIndex) => 
      mangaRef(mangaIndex).child('chapters');
      
  static DatabaseReference chapterRef(int mangaIndex, int chapterIndex) => 
      chaptersRef(mangaIndex).child(chapterIndex.toString());
}
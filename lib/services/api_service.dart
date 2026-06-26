import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UploadPurpose {
  static const String mangaCover = 'manga-cover';
  static const String mangaBackground = 'manga-background';
  static const String chapterPage = 'chapter-page';
  static const String topupSlip = 'topup-slip';
  static const String carouselImage = 'carousel-image';
}

class ApiService {
  static const String baseUrl = 'https://fastapi888.lukeenortaed.site';

  static String? _cachedToken;

  static Future<String?> getToken() async {
    if (_cachedToken != null) return _cachedToken;
    final prefs = await SharedPreferences.getInstance();
    _cachedToken = prefs.getString('jwt_token');
    return _cachedToken;
  }

  static Future<void> setToken(String token) async {
    _cachedToken = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token', token);
  }

  static Future<void> clearToken() async {
    _cachedToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
  }

  static Future<Map<String, String>> _headers() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Future<http.Response> get(String path) async {
    return http.get(Uri.parse('$baseUrl$path'), headers: await _headers());
  }

  static Future<http.Response> post(String path, Map<String, dynamic> body) async {
    return http.post(
      Uri.parse('$baseUrl$path'),
      headers: await _headers(),
      body: jsonEncode(body),
    );
  }

  // POST โดยไม่ต้องมี Auth token (ใช้สำหรับ /auth/token)
  static Future<http.Response> postPublic(
      String path, Map<String, dynamic> body) async {
    return http.post(
      Uri.parse('$baseUrl$path'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
  }

  static Future<http.Response> patch(
      String path, Map<String, dynamic> body) async {
    return http.patch(
      Uri.parse('$baseUrl$path'),
      headers: await _headers(),
      body: jsonEncode(body),
    );
  }

  static Future<http.Response> delete(String path) async {
    return http.delete(Uri.parse('$baseUrl$path'), headers: await _headers());
  }

  static MediaType contentTypeFromFilename(String filename) {
    final ext = filename.contains('.')
        ? filename.split('.').last.toLowerCase()
        : 'jpg';
    switch (ext) {
      case 'png':
        return MediaType('image', 'png');
      case 'webp':
        return MediaType('image', 'webp');
      case 'gif':
        return MediaType('image', 'gif');
      case 'jpg':
      case 'jpeg':
      default:
        return MediaType('image', 'jpeg');
    }
  }

  static Future<http.Response> uploadBytes({
    required List<int> bytes,
    required String filename,
    required String purpose,
    String? topupId,
  }) async {
    final token = await getToken();
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/api/v1/uploads'),
    );
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    request.fields['purpose'] = purpose;
    if (topupId != null) request.fields['topup_id'] = topupId;
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: filename,
        contentType: contentTypeFromFilename(filename),
      ),
    );
    final streamed = await request.send();
    return http.Response.fromStream(streamed);
  }

  /// Parses upload response and returns a full image URL, or null on failure.
  static String? parseUploadUrl(http.Response response) {
    if (response.statusCode != 200) return null;
    try {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final asset = json['asset'] as Map<String, dynamic>?;
      final path = asset?['url'] as String? ?? json['url'] as String?;
      if (path == null || path.isEmpty) return null;
      if (path.startsWith('http://') || path.startsWith('https://')) {
        return path;
      }
      return '$baseUrl$path';
    } catch (_) {
      return null;
    }
  }
}

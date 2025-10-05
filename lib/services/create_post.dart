// create_post.dart

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http_parser/http_parser.dart';
import 'dart:ui';

class CreatePostService {
  static final String _baseUrl = dotenv.env['API_BASE_URL']!;

  static Future<String?> generateBlurPreview({
    required File imageFile,
    required List<String> regionsToBlur,
  }) async {
    if (regionsToBlur.isEmpty || regionsToBlur.contains('select')) return null;

    final uri = Uri.parse('$_baseUrl/api/preview-blur');
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final req = http.MultipartRequest('POST', uri)
      ..headers['Accept'] = 'application/json'          // ✅ force JSON
      ..headers['Authorization'] = 'Bearer $token'
      ..fields['regions'] = jsonEncode(regionsToBlur)
      ..files.add(await http.MultipartFile.fromPath('image', imageFile.path));

    final res = await req.send();
    final body = await res.stream.bytesToString();

    if (res.statusCode == 200) {
      final json = jsonDecode(body);
      return json['blurred_url'] as String?;
    } else {
      // Helpful when tracking redirects / validation
      print('Preview failed: ${res.statusCode}  headers=${res.headers}  body=$body');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> uploadTier({
    required File imageFile,
    required int credits,
    int? postId,
    required String label,
    required String description,
    required double blurSigma,         // ✅ required by backend
    required double brushSize,         // ✅ required by backend
    File? mainPostAsset,
    List<Offset>? drawnPoints,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/post/upload-tier');
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final req = http.MultipartRequest('POST', uri)
      ..headers['Accept'] = 'application/json'          // ✅ FIX: prevents 302 to /login
      ..headers['Authorization'] = 'Bearer $token'
    // Do NOT set Content-Type manually on the request; MultipartRequest handles it.
      ..fields['credits'] = credits.toString()
      ..fields['label'] = label
      ..fields['description'] = description
      ..fields['blur_sigma'] = blurSigma.toString()     // ✅ always send
      ..fields['brush_size'] = brushSize.toString()     // ✅ always send
      ..files.add(
        await http.MultipartFile.fromPath(
          'tier_image',
          imageFile.path,
          // You can omit contentType; if you keep it, make sure it matches the file.
          contentType: MediaType('image', 'jpeg'),
        ),
      );

    if (postId != null && postId != 0) {
      req.fields['post_id'] = postId.toString();
    } else {
      if (mainPostAsset == null) {
        throw ArgumentError('mainPostAsset is required when postId is null');
      }
      req.files.add(await http.MultipartFile.fromPath('main_post_asset', mainPostAsset.path));
    }

    if (mainPostAsset != null) {
      req.files.add(
        await http.MultipartFile.fromPath(
          'main_post_asset',
          mainPostAsset.path,
          contentType: MediaType('image', 'jpeg'),
        ),
      );
    }

    if (drawnPoints != null) {
      final serialized = jsonEncode(
        drawnPoints.map((p) => {'dx': p.dx, 'dy': p.dy}).toList(),
      );
      req.fields['blur_points'] = serialized;
    }

    final res = await req.send();
    final body = await res.stream.bytesToString();

    if (res.statusCode == 200 || res.statusCode == 201) {
      final root = jsonDecode(body) as Map<String, dynamic>;
      final payload = (root['data'] is Map)
          ? Map<String, dynamic>.from(root['data'])
          : root; // fallback if you ever return bare object

      final tierId = payload['tier_id'];
      final postId = payload['post_id'];

      return payload; // or return {'tier_id': tierId, 'post_id': postId};
    } else {
      return null;
    }
  }
}

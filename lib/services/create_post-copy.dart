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

    final request =
        http.MultipartRequest('POST', uri)
          ..fields['regions'] = jsonEncode(regionsToBlur)
          ..headers['Authorization'] = 'Bearer $token'
          ..files.add(
            await http.MultipartFile.fromPath('image', imageFile.path),
          );

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();

    if (response.statusCode == 200) {
      final json = jsonDecode(responseBody);
      return json['blurred_url'];
    } else {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> uploadTier({
    required File imageFile,
    required int credits,
    required int postId,
    required String label,
    required String description,
    File? mainPostAsset,
    double? blurSigma,
    double? brushSize,
    List<Offset>? drawnPoints,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/post/upload-tier');

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final request =
        http.MultipartRequest('POST', uri)
          ..headers['Authorization'] = 'Bearer $token'
          ..fields['credits'] = credits.toString()
          ..fields['post_id'] = postId.toString()
          ..fields['label'] = label
          ..fields['description'] = description
          ..files.add(
            await http.MultipartFile.fromPath(
              'tier_image',
              imageFile.path,
              contentType: MediaType('image', 'jpeg'),
            ),
          );

    if (mainPostAsset != null) {
      request.files.add(
        await http.MultipartFile.fromPath(
          'main_post_asset',
          mainPostAsset.path,
          contentType: MediaType('image', 'jpeg'),
        ),
      );
    }

    if (blurSigma != null) {
      request.fields['blur_sigma'] = blurSigma.toString();
    }
    if (brushSize != null) {
      request.fields['brush_size'] = brushSize.toString();
    }
    if (drawnPoints != null) {
      final serialized = jsonEncode(
        drawnPoints.map((p) => {'dx': p.dx, 'dy': p.dy}).toList(),
      );
      request.fields['blur_points'] = serialized;
    }

    final response = await request.send();
    final respString = await response.stream.bytesToString();

    if (response.statusCode == 200) {
      try {
        final jsonResp = jsonDecode(respString);
        print('Tier uploaded successfully: $jsonResp');
        return jsonResp; // This should contain the post_id if first tier
      } catch (e) {
        print('Failed to decode response: $e');
        return null;
      }
    } else {
      print('Failed to upload tier: ${response.statusCode} → $respString');
      return null;
    }
  }
}

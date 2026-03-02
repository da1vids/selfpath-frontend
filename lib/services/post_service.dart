import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PostService {
  static final String _baseUrl = dotenv.env['API_BASE_URL']!;

  /// 🔓 Multi-tier unlock
  static Future<Map<String, dynamic>> unlockTier({
    required int postId,
    required int tierId,
  }) async {
    final url = Uri.parse('$_baseUrl/api/post/unlock-tier');

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'post_id': postId, 'tier_id': tierId}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return {
        'success': data['success'],
        'asset':
            data['data']?['asset'], // <- map snake_case to camelCase
        'message': data['data']?['message'],
        'credits': data['data']?['credits']
      };
    }

    return {'success': false};
  }

  static Future<Map<String, dynamic>> getPosts({
    int offset = 0,
    int limit = 10,
    int? creatorId,
    String? tag,
  }) async {
    final queryParams = {
      'offset': '$offset',
      'limit': '$limit',
      if (creatorId != null) 'creator_id': '$creatorId',
      if (tag != null) 'tag': tag,
    };

    final uri = Uri.parse(
      '$_baseUrl/api/posts',
    ).replace(queryParameters: queryParams);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      print('Posts $data');
      return {
        'posts': List<Map<String, dynamic>>.from(data['data']?['posts']),
        'hasMore': data['hasMore'] ?? false,
      };
    } else {
      throw Exception('Failed to load posts');
    }
  }

  static Future<Map<String, dynamic>> toggleLike({
    required dynamic postId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final response = await http.post(
      Uri.parse('$_baseUrl/api/post/like'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'post_id': postId}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to toggle like');
    }
  }

  static Future<Map<String, dynamic>> toggleBookmark({
    required dynamic postId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final response = await http.post(
      Uri.parse('$_baseUrl/api/post/bookmark'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'post_id': postId}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to make bookmark');
    }
  }

  /*   static Future<List<Map<String, dynamic>>> fetchComments(int postId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final response = await http.get(
      Uri.parse('$_baseUrl/api/post/$postId/comments'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
    if (response.statusCode == 200) {
      final jsonData = json.decode(response.body);
      return List<Map<String, dynamic>>.from(jsonData['comments']);
    } else {
      throw Exception('Failed to load comments');
    }
  } */

  static Future<Map<String, dynamic>> postComment({
    required int postId,
    required String content,
    int? parentId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final response = await http.post(
      Uri.parse('$_baseUrl/api/post/comments'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'post_id': postId,
        'content': content,
        if (parentId != null) 'parent_id': parentId,
      }),
    );

    final jsonData = json.decode(response.body);
    return jsonData;
  }

  static Future<Map<String, dynamic>> deleteComment(int commentId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final response = await http.delete(
      Uri.parse('$_baseUrl/api/post/comments'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode({'comment_id': commentId}),
    );
    return json.decode(response.body);
  }

  static Future<Map<String, dynamic>> toggleCommentLike(
    String commentId,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final response = await http.post(
      Uri.parse('$_baseUrl/api/post/comment/like'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode({'comment_id': commentId}),
    );

    final body = jsonDecode(response.body);
    return body;
  }

  static Future<List<Map<String, dynamic>>> fetchComments(
    int postId, {
    int offset = 0,
    int limit = 10,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final response = await http.get(
      Uri.parse(
        '$_baseUrl/api/post/$postId/comments?offset=$offset&limit=$limit',
      ),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final comments = data['data']['comments'];
      return List<Map<String, dynamic>>.from(comments);
    } else {
      throw Exception('Failed to load comments');
    }
  }

  static Future<List<Map<String, dynamic>>> searchPosts(String query) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final response = await http.get(
      Uri.parse('$_baseUrl/api/search/posts?q=$query'),
      headers: {'Authorization': 'Bearer $token'},
    );

    final data = jsonDecode(response.body);
    if (data['success'] && data['data']?['posts'] is List) {
      return List<Map<String, dynamic>>.from(data['data']?['posts']);
    } else {
      return [];
    }
  }
}

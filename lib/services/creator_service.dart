import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/creator_model.dart'; // we'll define this next
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CreatorService {
  static final String _baseUrl = dotenv.env['API_BASE_URL']!;

  static Future<List<Creator>> fetchCreators() async {
    final url = Uri.parse('$_baseUrl/api/creators');

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final jsonData = json.decode(response.body);
      final creatorList = jsonData['data'];

      return List<Creator>.from(creatorList.map((c) => Creator.fromJson(c)));
    } else {
      throw Exception('Failed to load creators');
    }
  }

  static Future<FollowToggleResult?> toggleFollow(String creatorId) async {
    final url = Uri.parse('$_baseUrl/api/creators/toggle-follow');
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'creator_id': creatorId}),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return FollowToggleResult(
        success: data['success'] ?? false,
        followed: data['data']?['followed'],
        followersCount: data['data']?['followers_count'],
        message: data['message'] ?? '',
      );
    }

    return null;
  }
}

class FollowToggleResult {
  final bool success;
  final bool followed;
  final int followersCount;
  final String message;

  FollowToggleResult({
    required this.success,
    required this.followed,
    required this.followersCount,
    required this.message,
  });
}

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:http/http.dart' as http;
import 'package:walletconnect_dart/walletconnect_dart.dart';
import 'package:web3dart/crypto.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../utils/device_utils.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class AuthService {
  static final String _baseUrl = dotenv.env['API_BASE_URL']!;

  final String loginEndpoint = '$_baseUrl/api/auth/login';

  Future<Map<String, dynamic>> loginWithEmail(
    String email,
    String password,
    String deviceName
  ) async {
    final response = await http.post(
      Uri.parse(loginEndpoint),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'login_method': 'username',
        'email': email,
        'password': password,
        'device_name': deviceName,
      }),
    );

    final data = jsonDecode(response.body);
    final token = data['data']?['token'] as String?;
    final user  = data['data']?['user'];

    if (response.statusCode == 200 && token != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', token);
      if (user != null) {
        await prefs.setString('user', jsonEncode(user));
      }
      // send device token now that we are authenticated
      await sendDeviceToken();

      return {'success': true, 'message': 'Login successful', 'user': user};
    }

    return {'success': false, 'message': data['message'] ?? 'Login failed'};
  }

  Future<Map<String, dynamic>> loginWithGoogle() async {
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        return {'success': false, 'message': 'Google sign-in was cancelled'};
      }

      final googleAuth = await googleUser.authentication;
      if (googleAuth.idToken == null) {
        return {'success': false, 'message': 'Google auth token missing'};
      }

      final response = await http.post(
        Uri.parse(loginEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'login_method': 'google',
          'social_token': googleAuth.idToken,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['token'] != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', data['token']);
        return {'success': true, 'message': 'Login successful'};
      }

      return {
        'success': false,
        'message': data['error'] ?? 'Google login failed',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Google login error: ${e.toString()}',
      };
    }
  }

  Future<Map<String, dynamic>> loginWithApple() async {
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final response = await http.post(
        Uri.parse(loginEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'login_method': 'apple',
          'social_token': credential.identityToken,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['token'] != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', data['token']);
        return {'success': true, 'message': 'Login successful'};
      }

      return {
        'success': false,
        'message': data['error'] ?? 'Apple login failed',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Apple login error: ${e.toString()}',
      };
    }
  }

  Future<Map<String, dynamic>> loginWithFacebook() async {
    try {
      final result = await FacebookAuth.instance.login();

      if (result.status != LoginStatus.success || result.accessToken == null) {
        return {
          'success': false,
          'message': 'Facebook login failed or was cancelled',
        };
      }

      final accessToken = result.accessToken;
      if (accessToken == null) {
        return {'success': false, 'message': 'Access token not found'};
      }

      final tokenMap = accessToken.toJson();
      final token = tokenMap['token'];

      final response = await http.post(
        Uri.parse(loginEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'login_method': 'facebook', 'social_token': token}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['token'] != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', data['token']);
        return {'success': true, 'message': 'Login successful'};
      }

      return {
        'success': false,
        'message': data['error'] ?? 'Facebook login failed',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Facebook login error: ${e.toString()}',
      };
    }
  }

  Future<bool> loginWithWeb3(Function(String uri) onDisplayUri) async {
    final connector = WalletConnect(
      bridge: 'https://bridge.walletconnect.org',
      clientMeta: PeerMeta(
        name: 'Blurred',
        description: 'Content unlock app',
        url: 'https://yourdomain.com',
        icons: ['https://yourdomain.com/logo.png'],
      ),
    );

    if (!connector.connected) {
      await connector.createSession(onDisplayUri: onDisplayUri);
    }

    if (connector.session.accounts.isEmpty) return false;
    final address = connector.session.accounts[0];
    final message = "Sign this message to login to Blurred";
    final msgHex = bytesToHex(
      Uint8List.fromList(message.codeUnits),
      include0x: true,
    );

    final signature = await connector.sendCustomRequest(
      method: "personal_sign",
      params: [msgHex, address],
    );

    final response = await http.post(
      Uri.parse(loginEndpoint),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'login_method': 'web3',
        'wallet_address': address,
        'message': message,
        'signature': signature,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', data['token']);
      return true;
    }

    return false;
  }

  Future<bool> logout() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final fcm = prefs.getString('fcm_token');

    if (token != null && fcm != null && fcm.isNotEmpty) {
      try {
        await http.delete(
          Uri.parse('$_baseUrl/api/auth/device-token'),
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'token': fcm}),
        );
      } catch (_) {}
    }

    if (token == null) return false;

    final response = await http.post(
      Uri.parse('$_baseUrl/api/auth/logout'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    await prefs.remove('token');

    if (response.statusCode == 200) {
      return true;
    } else {
      return false;
    }
  }

  Future<Map<String, dynamic>> signUp(
    String username,
    String email,
    String password,
  ) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/auth/signup'), // replace with your real endpoint
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'email': email,
        'password': password,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return {
        'success': true,
        'message': data['message'] ?? 'Registration successful',
      };
    } else {
      final error = jsonDecode(response.body);
      return {
        'success': false,
        'message': error['message'] ?? 'Registration failed',
      };
    }
  }

  Future<Map<String, dynamic>> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      return {'success': false, 'message': 'Token not found'};
    }

    final response = await http.get(
      Uri.parse('$_baseUrl/api/auth/me'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      final user = body['data'];
      return {'success': true, 'user': user};
    } else {
      // Token is invalid or expired
      await prefs.remove('token');
      return {'success': false, 'message': 'Session expired'};
    }
  }

  Future<void> sendDeviceToken({String? tokenOverride}) async {
    final prefs = await SharedPreferences.getInstance();

    // API auth token
    final authToken = prefs.getString('token');
    if (authToken == null || authToken.isEmpty) {
      return;
    }

    // Get FCM token (override or stored or from Firebase)
    String? fcmToken = tokenOverride;
    fcmToken ??= prefs.getString('fcm_token');
    fcmToken ??= await FirebaseMessaging.instance.getToken();

    if (fcmToken == null || fcmToken.isEmpty) {
      return;
    }

    // Collect device info
    final platform   = DeviceUtils.getPlatform();
    final deviceId   = await DeviceUtils.getDeviceId();
    final appVersion = await DeviceUtils.getAppVersion();

    final body = <String, dynamic>{
      'token': fcmToken,
      'platform': platform,     // 'android' | 'ios'
      'device_id': deviceId,    // can be null
      'app_version': appVersion // e.g. "1.0.3"
    };

    try {
      final resp = await http.post(
        Uri.parse('$_baseUrl/api/auth/device-token'),
        headers: {
          'Authorization': 'Bearer $authToken',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );
      // persist last-sent tokenn
      await prefs.setString('fcm_token', fcmToken);
    } catch (e) {

    }
  }
}

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'views/auth/login_screen.dart';
import 'views/general/home_screen.dart';
import 'views/payment/payment_screen.dart'; // adjust path if different
import 'theme/theme.dart';
import 'views/auth/signup_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../services/auth_service.dart';
import 'package:provider/provider.dart';
import 'providers/user_provider.dart';
import 'package:flutter/services.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    print('Caught Flutter error: ${details.exceptionAsString()}');
    print('Stack trace: ${details.stack}');
  };

  await dotenv.load();

  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // 🔧 Local notification setup
  const AndroidInitializationSettings androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const DarwinInitializationSettings iosSettings =
      DarwinInitializationSettings();

  const InitializationSettings initSettings = InitializationSettings(
    android: androidSettings,
    iOS: iosSettings,
  );

  await flutterLocalNotificationsPlugin.initialize(initSettings);

  // 🔐 FCM token logic
  FirebaseMessaging messaging = FirebaseMessaging.instance;
  await messaging.requestPermission();

  String? fcmToken = await messaging.getToken();
  print('🔥 FCM Token: $fcmToken');

  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('fcm_token', fcmToken ?? '');

  // Make android menu (home, back and open apps) black
  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.black, // bottom navbar background
      systemNavigationBarIconBrightness: Brightness.light, // icon color
      statusBarColor: Colors.transparent, // optional: make status bar blend in
      statusBarIconBrightness: Brightness.light, // status bar icon color
    ),
  );

  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => UserProvider())],
      child: MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String? _token;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadToken();
    _setupFCMListener();
  }

  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();

    final result = await AuthService().getCurrentUser();
    if (result['success']) {
      final userData = result['user'];
      Provider.of<UserProvider>(context, listen: false).setUser(userData);
    }

    if (result['success'] == true) {
      final user = result['user'];
      print("✅ User verified: ${user['email']}");

      await prefs.setString('user', jsonEncode(user));
      await AuthService().sendDeviceToken();

      setState(() {
        _token = prefs.getString('token');
        _loading = false;
      });
    } else {
      print("❌ Token invalid: ${result['message']}");
      await prefs.remove('token');
      await prefs.remove('user');

      setState(() {
        _token = null;
        _loading = false;
      });
    }
  }

  void _setupFCMListener() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      if (message.notification != null) {
        final notification = message.notification!;

        if (message.data['type'] == 'credits_updated') {
          final updatedCredits = int.tryParse(message.data['credits'] ?? '');
          if (updatedCredits != null) {
            Provider.of<UserProvider>(
              context,
              listen: false,
            ).updateCredits(updatedCredits);
          }
        }

        const AndroidNotificationDetails androidDetails =
            AndroidNotificationDetails(
              'blurred_channel',
              'Blurred Notifications',
              importance: Importance.max,
              priority: Priority.high,
            );

        const DarwinNotificationDetails iosDetails =
            DarwinNotificationDetails();

        const NotificationDetails platformDetails = NotificationDetails(
          android: androidDetails,
          iOS: iosDetails,
        );

        await flutterLocalNotificationsPlugin.show(
          notification.hashCode,
          notification.title,
          notification.body,
          platformDetails,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: Center(child: CircularProgressIndicator(color: Colors.white)),
        ),
      );
    }

    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark, // <- force dark always!

      home: _token != null && _token!.isNotEmpty ? HomeScreen() : LoginScreen(),
      routes: {
        '/login': (context) => LoginScreen(),
        '/signup': (context) => SignUpScreen(),
        '/home': (context) => HomeScreen(),
        '/payment': (context) => PaymentScreen(),
      },
      onUnknownRoute: (_) => MaterialPageRoute(builder: (_) => LoginScreen()),
    );
  }
}

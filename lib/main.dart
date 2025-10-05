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
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../services/auth_service.dart';
import 'package:provider/provider.dart';
import 'providers/user_provider.dart';
import 'package:flutter/services.dart';
import 'dart:async';

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
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String? _token;
  bool _loading = true;

  StreamSubscription<RemoteMessage>? _onMessageSub;
  StreamSubscription<String>? _onTokenSub;

  @override
  void initState() {
    super.initState();
    _loadToken();
    _setupFCMListener();
  }

  Future<void> _loadToken() async {
    // capture from context BEFORE awaiting
    final userProvider = context.read<UserProvider>();

    final prefs = await SharedPreferences.getInstance();
    final auth = AuthService(); // reuse the same instance

    final result = await auth.getCurrentUser();

    if (result['success'] == true) {
      final user = result['user'];
      debugPrint("✅ User verified: ${user['email']}");

      // no context used here
      await prefs.setString('user', jsonEncode(user));
      await auth.sendDeviceToken();

      final savedToken = prefs.getString('token');

      if (!mounted) return; // guard before setState
      setState(() {
        _token = savedToken;
        _loading = false;
      });

      // update provider after the awaits using captured ref (no BuildContext)
      userProvider.setUser(user);
    } else {
      debugPrint("❌ Token invalid: ${result['message']}");
      await prefs.remove('token');
      await prefs.remove('user');

      if (!mounted) return; // guard before setState
      setState(() {
        _token = null;
        _loading = false;
      });
    }
  }



  void _setupFCMListener() {
    // capture provider synchronously (no BuildContext after this)
    final userProvider = context.read<UserProvider>();

    // Cancel old subs if re-calling setup
    _onMessageSub?.cancel();
    _onTokenSub?.cancel();

    _onMessageSub = FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      final notif = message.notification;

      // Update credits via captured provider (no context)
      if (message.data['type'] == 'credits_updated') {
        final updatedCredits = int.tryParse(message.data['credits'] ?? '');
        if (updatedCredits != null) {
          userProvider.updateCredits(updatedCredits);
        }
      }

      if (notif != null) {
        const androidDetails = AndroidNotificationDetails(
          'blurred_channel',
          'Blurred Notifications',
          importance: Importance.max,
          priority: Priority.high,
        );
        const iosDetails = DarwinNotificationDetails();
        const platformDetails = NotificationDetails(
          android: androidDetails,
          iOS: iosDetails,
        );

        await flutterLocalNotificationsPlugin.show(
          notif.hashCode,
          notif.title,
          notif.body,
          platformDetails,
        );
      }
    });

    _onTokenSub = FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('fcm_token', newToken);
      await AuthService().sendDeviceToken(tokenOverride: newToken);
    });
  }


  @override
  void dispose() {
    _onMessageSub?.cancel();
    _onTokenSub?.cancel();
    super.dispose();
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

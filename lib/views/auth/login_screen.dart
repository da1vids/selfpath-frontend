import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/gestures.dart';
import '../../services/auth_service.dart';
import '../../widgets/styled_input.dart';
import '../../theme/theme.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _obscureText = true;
  String deviceName = 'Unknown device';

  @override
  void initState() {
    super.initState();
    getDeviceName();
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> getDeviceName() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final android = await deviceInfo.androidInfo;
        setState(() => deviceName = android.model);
      } else if (Platform.isIOS) {
        final ios = await deviceInfo.iosInfo;
        setState(() => deviceName = ios.name);
      }
    } catch (_) {
      setState(() => deviceName = 'Could not retrieve device name');
    }
  }

  Future<void> _handleLogin(
      BuildContext context,
      Future<Map<String, dynamic>> Function() method,
      ) async {
    // Capture everything you'll need from context BEFORE any await
    final nav = Navigator.of(context, rootNavigator: true);
    final messenger = ScaffoldMessenger.of(context);
    final userProvider = context.read<UserProvider>();

    // show loading (allowed: we haven't awaited yet)
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final result = await method(); // <-- async gap, but we won't use context after this

      // Close dialog via captured navigator (no context)
      if (nav.canPop()) nav.pop();

      if (result['success'] == true) {
        final userResult = await _authService.getCurrentUser(); // async gap

        if (userResult['success'] == true) {
          userProvider.setUser(userResult['user']); // uses captured provider, no context
        }

        // Navigate via captured navigator, no context
        nav.pushReplacementNamed('/home');
      } else {
        messenger.showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Login failed')),
        ); // uses captured messenger, no context
      }
    } catch (e) {
      // Close dialog if still open, using captured navigator
      if (nav.canPop()) nav.pop();

      debugPrint('Login error: $e');
      messenger.showSnackBar(
        const SnackBar(content: Text('Something went wrong')),
      ); // uses captured messenger, no context
    }
  }

  Widget _buildSocialIcon(String assetPath, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 10),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle),
        child: SvgPicture.asset(assetPath, height: 24, width: 24),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Image
          Positioned.fill(
            child: Image.asset(
              'assets/backgrounds/background1.png', // <-- Your image path
              fit: BoxFit.cover,
            ),
          ),

          // Gradient overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xFF000000)],
                ),
              ),
            ),
          ),

          // Login content
          LayoutBuilder(
            builder: (context, constraints) {
              return Container(
                height: constraints.maxHeight,
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 40),
                        child: SvgPicture.asset(
                          'assets/logo/logo.svg', // Update path if needed
                          height: 25,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(
                        bottom: 20.0,
                      ), // adjust value as needed
                      child: Center(
                        child: Text(
                          "Welcome Back!",
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    /* Text(
                      "Log In",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ), */
                    SizedBox(height: 30),
                    StyledInput(
                      label: 'Username',
                      icon: Icons.person_outline,
                      controller: emailController,
                    ),
                    SizedBox(height: 20),
                    StyledInput(
                      label: 'Password',
                      icon: Icons.lock_outline,
                      controller: passwordController,
                      obscure: _obscureText,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureText
                              ? Icons.visibility
                              : Icons.visibility_off,
                          color: Color(0xFF565656),
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureText = !_obscureText;
                          });
                        },
                      ),
                    ),
                    /* Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {},
                        child: Text(
                          "Forget Password",
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            color: accentColor,
                          ),
                        ),
                      ),
                    ), */
                    SizedBox(height: 10),
                    ElevatedButton(
                      onPressed:
                          () => _handleLogin(
                            context,
                            () => _authService.loginWithEmail(
                              emailController.text,
                              passwordController.text,
                              deviceName
                            ),
                          ),
                      child: Text("Log In"),
                    ),
                    SizedBox(height: 30),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildSocialIcon('assets/icons/google.svg', () {
                          _handleLogin(
                            context,
                            () => _authService.loginWithGoogle(),
                          );
                        }),
                        _buildSocialIcon('assets/icons/apple.svg', () {
                          _handleLogin(
                            context,
                            () => _authService.loginWithApple(),
                          );
                        }),
                        _buildSocialIcon('assets/icons/facebook.svg', () {
                          _handleLogin(
                            context,
                            () => _authService.loginWithFacebook(),
                          );
                        }),

                      ],
                    ),
                    SizedBox(height: 20),
                    Center(
                      child: RichText(
                        text: TextSpan(
                          text: "Not have an account? ",
                          style: TextStyle(color: Colors.white70),
                          children: [
                            TextSpan(
                              text: "Sign Up",
                              style: TextStyle(color: AppTheme.accentColor),
                              recognizer:
                                  TapGestureRecognizer()
                                    ..onTap = () {
                                      Navigator.pushNamed(context, '/signup');
                                    },
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 30),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/gestures.dart';
import '../../services/auth_service.dart';
import '../../widgets/styled_input.dart';
import '../../theme/theme.dart';

class SignUpScreen extends StatefulWidget {
  @override
  _SignUpScreenState createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final FocusNode _passwordFocusNode = FocusNode();
  bool _obscurePassword = true;
  bool _showPasswordCriteria = false;

  final AuthService _authService = AuthService();

  bool _isValidEmail(String email) {
    return RegExp(r"^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$").hasMatch(email);
  }

  List<bool> _passwordCriteria(String password) {
    return [
      password.length >= 8,
      RegExp(r'[A-Z]').hasMatch(password),
      RegExp(r'[!@#\$%^&*(),.?\":{}|<>_|]').hasMatch(password),
    ];
  }

  Widget _buildPasswordChecklist(String password) {
    final checks = _passwordCriteria(password);
    final List<String> criteria = [
      'At least 8 characters',
      'One uppercase letter',
      'One special character',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(criteria.length, (index) {
        return Row(
          children: [
            Icon(
              checks[index] ? Icons.check_circle : Icons.cancel,
              size: 16,
              color: checks[index] ? Colors.green : Colors.red,
            ),
            SizedBox(width: 8),
            Text(
              criteria[index],
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        );
      }),
    );
  }

  void _handleSignUp(BuildContext context) async {
    final username = usernameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text;

    if (username.isEmpty || email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Please fill all fields')));
      return;
    }

    if (!_isValidEmail(email)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Please enter a valid email')));
      return;
    }

    final checks = _passwordCriteria(password);
    if (checks.contains(false)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Password does not meet all criteria')),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(child: CircularProgressIndicator()),
    );

    try {
      final result = await _authService.signUp(username, email, password);

      Navigator.pop(context);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result['message'])));

      if (result['success']) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unexpected error: $e')));
    }
  }

  @override
  void initState() {
    super.initState();
    _passwordFocusNode.addListener(() {
      setState(() {
        _showPasswordCriteria = _passwordFocusNode.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    usernameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/backgrounds/background1.png',
              fit: BoxFit.cover,
            ),
          ),
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
                          'assets/logo/logo.svg',
                          height: 25,
                        ),
                      ),
                    ),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: Text(
                          "Create Account",
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    StyledInput(
                      label: 'Username',
                      icon: Icons.person_outline,
                      controller: usernameController,
                    ),
                    SizedBox(height: 16),
                    StyledInput(
                      label: 'Email',
                      icon: Icons.email_outlined,
                      controller: emailController,
                      onChanged: (_) => setState(() {}),
                    ),
                    if (emailController.text.isNotEmpty &&
                        !_isValidEmail(emailController.text))
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Please enter a valid email',
                          style: TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      ),
                    SizedBox(height: 16),
                    StyledInput(
                      label: 'Password',
                      icon: Icons.lock_outline,
                      controller: passwordController,
                      focusNode: _passwordFocusNode,
                      obscure: _obscurePassword,
                      onChanged: (_) => setState(() {}),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                          color: Color(0xFF565656),
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                    if (_showPasswordCriteria)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: _buildPasswordChecklist(passwordController.text),
                      ),
                    SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () => _handleSignUp(context),
                      child: Text("Sign Up"),
                    ),
                    SizedBox(height: 20),
                    Center(
                      child: RichText(
                        text: TextSpan(
                          text: "Already have an account? ",
                          style: TextStyle(color: Colors.white70),
                          children: [
                            TextSpan(
                              text: "Log In",
                              style: TextStyle(color: AppTheme.accentColor),
                              recognizer:
                                  TapGestureRecognizer()
                                    ..onTap = () {
                                      Navigator.pushReplacementNamed(
                                        context,
                                        '/login',
                                      );
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

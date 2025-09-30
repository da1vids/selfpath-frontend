import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../home/home_posts_screen.dart';
import '../creators/creators_screen.dart';
import '../post/create_post_screen.dart';

import '../../providers/user_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  int _selectedIndex = 0;

  final List<String> _iconPaths = [
    'assets/icons/home.svg',
    'assets/icons/stats.svg',
    'assets/icons/upload.svg',
    'assets/icons/messages.svg',
    'assets/icons/profile.svg',
  ];

  Future<void> _confirmLogout(BuildContext context) async {
    // Capture before any async gap
    final nav = Navigator.of(context, rootNavigator: true);
    final messenger = ScaffoldMessenger.of(context);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final success = await _authService.logout();

    if (success) {
      nav.pushReplacementNamed('/login'); // safe, no context
    } else {
      messenger.showSnackBar(
        const SnackBar(content: Text('Logout failed')),
      );
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  BottomNavigationBarItem _buildSvgNavItem(String assetPath, int index) {
    final bool isUploadIcon = index == 2;

    return BottomNavigationBarItem(
      icon: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Align(
            alignment: Alignment.center,
            child: SvgPicture.asset(
              assetPath,
              colorFilter: isUploadIcon
                  ? null
                  : ColorFilter.mode(
                _selectedIndex == index ? Colors.white : Colors.grey,
                BlendMode.srcIn,
              ),
              width: isUploadIcon ? 36 : 24,
              height: isUploadIcon ? 36 : 24,
            ),
          ),
          if (_selectedIndex == index && !isUploadIcon)
            Container(
              margin: EdgeInsets.only(top: 10),
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            )
          else if (!isUploadIcon)
            SizedBox(height: 6),
        ],
      ),
      label: '',
    );
  }

  Widget _buildPageContent() {
    switch (_selectedIndex) {
      case 0:
        return HomePostsScreen();
      case 1:
        return CreatorsScreen();
      case 2:
        return CreatePostScreen();
      case 3:
        return Center(child: Text("Messages", style: TextStyle(fontSize: 20)));
      case 4:
        return Center(
          child: Consumer<UserProvider>(
            builder: (context, userProvider, child) {
              final credits = userProvider.credits;
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("You're logged in", style: TextStyle(fontSize: 20)),
                  SizedBox(height: 10),
                  Text(
                    "Credits: $credits",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pushNamed(context, '/payment');
                    },
                    icon: Icon(Icons.payment),
                    label: Text('Buy Credits'),
                  ),
                ],
              );
            },
          ),
        );
      default:
        return Center(child: Text("Unknown Page"));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Welcome!'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () => _confirmLogout(context),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: _buildPageContent(),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.black,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        items: List.generate(
          _iconPaths.length,
          (index) => _buildSvgNavItem(_iconPaths[index], index),
        ),
      ),
    );
  }
}

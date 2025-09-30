// screens/CreatePostScreen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import 'image_video_selector.dart';
import 'tier_editor_screen.dart';
import 'image_tier_editor_screen.dart';
import 'become_a_creator_screen.dart';

class CreatePostScreen extends StatelessWidget {
  const CreatePostScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserProvider>(context).user;

    if (user == null) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (user.role != 'creator') {
      return BecomeCreatorScreen();
    }

    return ImageVideoSelector(
      onMediaSelected: (mediaType, file) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) {
              if (mediaType == 'image') {
                return ImageTierEditorScreen(file: file);
              } else {
                return TierEditorScreen(mediaType: mediaType, file: file);
              }
            },
          ),
        );
      },
    );
  }
}

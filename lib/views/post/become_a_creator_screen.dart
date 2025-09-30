import 'package:flutter/material.dart';

class BecomeCreatorScreen extends StatelessWidget {
  const BecomeCreatorScreen({super.key});

  void _applyAsCreator(BuildContext context) {
    // You can replace this with actual navigation or API call
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Creator application submitted!')));

    // Optionally: navigate to onboarding or request screen
    // Navigator.push(context, MaterialPageRoute(builder: (_) => CreatorOnboardingScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Become a Creator")),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Spacer(),
            Icon(
              Icons.emoji_people_rounded,
              size: 100,
              color: Colors.pinkAccent,
            ),
            SizedBox(height: 24),
            Text(
              "Want to share and monetize your content?",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 12),
            Text(
              "Apply to become a Creator and start uploading exclusive content that your followers can unlock.",
              style: TextStyle(fontSize: 16, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
            Spacer(),
            ElevatedButton.icon(
              onPressed: () => _applyAsCreator(context),
              icon: Icon(Icons.monetization_on),
              label: Text("Apply as Creator"),
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 50),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../../services/creator_service.dart';
import '../../../models/creator_model.dart';
import 'widgets/creator_card.dart'; // import your new widget

class CreatorsScreen extends StatefulWidget {

  const CreatorsScreen({super.key});

  @override
  _CreatorsScreenState createState() => _CreatorsScreenState();
}

class _CreatorsScreenState extends State<CreatorsScreen> {
  List<Creator> _creators = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    loadCreators();
  }

  Future<void> loadCreators() async {
    try {
      final creators = await CreatorService.fetchCreators();
      setState(() {
        _creators = creators;
        _loading = false;
      });
    } catch (e) {
      print('Error: $e');
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> toggleFollow(int index) async {
    if (index < 0 || index >= _creators.length) return;

    final creator = _creators[index];
    final isNowFollowed = !creator.followed;
    final followerDelta = isNowFollowed ? 1 : -1;

    final updatedCreator = creator.copyWith(
      followed: isNowFollowed,
      followersCount: creator.followersCount + followerDelta,
    );

    // Optimistic update
    setState(() {
      _creators[index] = updatedCreator;
    });

    final result = await CreatorService.toggleFollow(creator.id);

    // Revert if failed
    if (result == null || !result.success) {
      setState(() {
        _creators[index] = creator;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text("Creators")),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: Text("Creators"), backgroundColor: Colors.black),
      body: ListView.builder(
        itemCount: _creators.length,
        itemBuilder: (context, index) {
          return CreatorCard(
            creator: _creators[index],
            onToggle: () => toggleFollow(index),
          );
        },
      ),
    );
  }
}

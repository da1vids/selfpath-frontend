import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_xlider/flutter_xlider.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class Tier {
  double start;
  double end;
  int credits;
  Tier(this.start, this.end, this.credits);
}

class TierEditorScreen extends StatefulWidget {
  final String mediaType; // "image" or "video"
  final XFile file;

  TierEditorScreen({required this.mediaType, required this.file});

  @override
  _TierEditorScreenState createState() => _TierEditorScreenState();
}

class _TierEditorScreenState extends State<TierEditorScreen> {
  late VideoPlayerController _videoController;
  List<Tier> _tiers = [];
  double _duration = 60;

  @override
  void initState() {
    super.initState();

    if (widget.mediaType == 'video') {
      _videoController = VideoPlayerController.file(File(widget.file.path))
        ..initialize().then((_) {
          setState(() {
            _duration = _videoController.value.duration.inSeconds.toDouble();
          });
        });
    }
  }

  @override
  void dispose() {
    if (widget.mediaType == 'video') {
      _videoController.dispose();
    }
    super.dispose();
  }

  void _addTier() {
    if (_tiers.isNotEmpty) {
      final lastEnd = _tiers.last.end;
      if (lastEnd >= _duration) return;
      _tiers.add(Tier(lastEnd, _duration, 0));
    } else {
      _tiers.add(Tier(0, _duration, 0));
    }
    setState(() {});
  }

  void _uploadPost() async {
    final uri = Uri.parse('https://yourdomain.com/api/posts');
    final request =
        http.MultipartRequest('POST', uri)
          ..headers['Authorization'] = 'Bearer YOUR_TOKEN_HERE'
          ..fields['text'] = 'My new post'
          ..fields['type'] = widget.mediaType
          ..fields['tiers'] =
              _tiers
                  .map((tier) {
                    return {
                      "label": "${tier.start}-${tier.end}s",
                      "description": "Unlock ${tier.start}-${tier.end}s",
                      "credits": tier.credits,
                    };
                  })
                  .toList()
                  .toString();

    request.files.add(
      await http.MultipartFile.fromPath('media', widget.file.path),
    );

    final res = await request.send();

    if (res.statusCode == 200) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Upload success")));
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Upload failed")));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.mediaType == 'image') {
      return Center(child: Text("Image tier editor coming next..."));
    }

    return Scaffold(
      appBar: AppBar(title: Text("Create Tiers")),
      body: Column(
        children: [
          AspectRatio(
            aspectRatio: _videoController.value.aspectRatio,
            child: VideoPlayer(_videoController),
          ),
          ElevatedButton(
            onPressed:
                _videoController.value.isPlaying
                    ? _videoController.pause
                    : _videoController.play,
            child: Icon(
              _videoController.value.isPlaying ? Icons.pause : Icons.play_arrow,
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _tiers.length,
              itemBuilder: (_, i) {
                return ListTile(
                  title: Text("Tier ${i + 1}"),
                  subtitle: FlutterSlider(
                    values: [_tiers[i].start, _tiers[i].end],
                    max: _duration,
                    min: 0,
                    rangeSlider: true,
                    onDragging: (_, low, high) {
                      setState(() {
                        _tiers[i].start = low;
                        _tiers[i].end = high;
                      });
                    },
                  ),
                  trailing: Container(
                    width: 60,
                    child: TextField(
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: "💰"),
                      onChanged: (val) {
                        _tiers[i].credits = int.tryParse(val) ?? 0;
                      },
                    ),
                  ),
                );
              },
            ),
          ),
          ElevatedButton.icon(
            icon: Icon(Icons.add),
            label: Text("Add Tier"),
            onPressed: _addTier,
          ),
          ElevatedButton(onPressed: _uploadPost, child: Text("Upload Post")),
        ],
      ),
    );
  }
}

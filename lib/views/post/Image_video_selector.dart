import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:photo_manager/photo_manager.dart';
import 'dart:typed_data';

class ImageVideoSelector extends StatefulWidget {
  final Function(String mediaType, XFile file) onMediaSelected;

  const ImageVideoSelector({
    super.key,
    required this.onMediaSelected,
  });

  @override
  State<ImageVideoSelector> createState() => _ImageVideoSelectorState();
}

class _ImageVideoSelectorState extends State<ImageVideoSelector> {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isRear = false;
  bool _isFlashOn = false;
  bool _isInitialized = false;
  bool _isRecording = false;
  String _mode = 'photo'; // 'photo' or 'video'
  Uint8List? _lastMediaThumb;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _setupCamera();
    _loadLastMediaThumb(); // 👈 Add this
  }

  Future<void> _loadLastMediaThumb() async {
    final permission = await PhotoManager.requestPermissionExtend();
    if (!permission.isAuth) return;

    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.common,
      onlyAll: true,
    );

    if (albums.isNotEmpty) {
      final recentAssets = await albums[0].getAssetListRange(start: 0, end: 1);
      if (recentAssets.isNotEmpty) {
        final thumb = await recentAssets[0].thumbnailDataWithSize(
          ThumbnailSize(200, 200),
        );
        setState(() {
          _lastMediaThumb = thumb;
        });
      }
    }
  }

  Future<void> _setupCamera() async {
    _cameras = await availableCameras();
    final camera =
        _isRear
            ? _cameras.firstWhere(
              (c) => c.lensDirection == CameraLensDirection.back,
            )
            : _cameras.firstWhere(
              (c) => c.lensDirection == CameraLensDirection.front,
            );

    _controller = CameraController(camera, ResolutionPreset.high);
    await _controller?.initialize();
    await _controller?.setFlashMode(
      _isFlashOn ? FlashMode.torch : FlashMode.off,
    );

    setState(() => _isInitialized = true);
  }

  void _toggleCamera() async {
    setState(() => _isRear = !_isRear);
    await _setupCamera();
  }

  void _toggleFlash() async {
    setState(() => _isFlashOn = !_isFlashOn);
    await _controller?.setFlashMode(
      _isFlashOn ? FlashMode.torch : FlashMode.off,
    );
  }

  void _switchMode(String newMode) {
    setState(() => _mode = newMode);
  }

  Future<void> _capturePhoto() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    final file = await _controller!.takePicture();
    widget.onMediaSelected('image', file);
  }

  Future<void> _recordVideo() async {
    if (_controller == null || _controller!.value.isRecordingVideo) return;

    try {
      setState(() => _isRecording = true);
      await _controller!.startVideoRecording();

      await Future.delayed(Duration(seconds: 10)); // ⏱️ Auto-stop after 10s

      final file = await _controller!.stopVideoRecording();
      setState(() => _isRecording = false);
      widget.onMediaSelected('video', file);
    } catch (e) {
      print('Error recording video: $e');
      setState(() => _isRecording = false);
    }
  }

  Future<void> _pickFromGallery() async {
    final file = await _picker.pickMedia();
    if (file == null) return;

    final ext = p.extension(file.path).toLowerCase();
    final isVideo = ['.mp4', '.mov', '.avi', '.mkv'].contains(ext);
    widget.onMediaSelected(isVideo ? 'video' : 'image', file);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _controller!.value.previewSize!.height,
                height: _controller!.value.previewSize!.width,
                child: CameraPreview(_controller!),
              ),
            ),
          ),

          // Flash & flip camera
          Positioned(
            top: 100,
            right: 16,
            child: Column(
              children: [
                IconButton(
                  icon: Icon(
                    _isFlashOn ? Icons.flash_on : Icons.flash_off,
                    color: Colors.white,
                  ),
                  onPressed: _toggleFlash,
                ),
                IconButton(
                  icon: Icon(Icons.flip_camera_ios, color: Colors.white),
                  onPressed: _toggleCamera,
                ),
              ],
            ),
          ),

          // Gallery
          Positioned(
            bottom: 110,
            left: 20,
            child: GestureDetector(
              onTap: _pickFromGallery,
              child:
                  _lastMediaThumb != null
                      ? ClipOval(
                        child: Image.memory(
                          _lastMediaThumb!,
                          width: 44,
                          height: 44,
                          fit: BoxFit.cover,
                        ),
                      )
                      : Icon(
                        Icons.photo_library,
                        color: Colors.white,
                        size: 40,
                      ),
            ),
          ),

          // Capture Button
          Positioned(
            bottom: 100,
            left: MediaQuery.of(context).size.width / 2 - 35,
            child: GestureDetector(
              onTap: _mode == 'photo' ? _capturePhoto : _recordVideo,
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _isRecording ? Colors.red : Colors.white,
                    width: 5,
                  ),
                ),
              ),
            ),
          ),

          // Mode toggle
          Positioned(
            bottom: 180,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _modeToggle('photo'),
                SizedBox(width: 20),
                _modeToggle('video'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _modeToggle(String type) {
    final selected = _mode == type;
    return GestureDetector(
      onTap: () => _switchMode(type),
      child: Text(
        type.toUpperCase(),
        style: TextStyle(
          color: selected ? Colors.white : Colors.white54,
          fontSize: 18,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}

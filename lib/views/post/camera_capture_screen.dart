import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class CameraCaptureScreen extends StatefulWidget {
  final Function(String mediaType, XFile file) onMediaSelected;

  const CameraCaptureScreen({super.key, required this.onMediaSelected});

  @override
  State<CameraCaptureScreen> createState() => _CameraCaptureScreenState();
}

class _CameraCaptureScreenState extends State<CameraCaptureScreen> {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isRearCamera = false;
  bool _isFlashOn = false;
  XFile? _latestGalleryFile;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    _cameras = await availableCameras();
    await _initCamera();
    /* await _loadLatestFromGallery(); */
  }

  Future<void> _initCamera() async {
    // Dispose the previous controller if any
    await _controller?.dispose();

    final camera =
        _isRearCamera
            ? _cameras.firstWhere(
              (c) => c.lensDirection == CameraLensDirection.back,
            )
            : _cameras.firstWhere(
              (c) => c.lensDirection == CameraLensDirection.front,
            );

    final newController = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
    );

    _controller = newController;

    await _controller?.initialize();

    await _controller?.setFlashMode(
      _isFlashOn ? FlashMode.torch : FlashMode.off,
    );

    if (!mounted) return;
    setState(() {});
  }

  Future<void> _loadLatestFromGallery() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => _latestGalleryFile = image);
    }
  }

  Future<void> _takePhoto() async {
    if (!(_controller?.value.isInitialized ?? false)) return;

    final photo = await _controller!.takePicture();
    widget.onMediaSelected('image', photo);
  }

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;

    final ext = p.extension(file.path).toLowerCase();
    final isVideo = ['.mp4', '.mov', '.avi'].contains(ext);

    if (isVideo) {
      final videoFile = await picker.pickVideo(source: ImageSource.gallery);
      if (videoFile != null) {
        widget.onMediaSelected('video', videoFile);
      }
    } else {
      widget.onMediaSelected('image', file);
    }
  }

  void _toggleFlash() async {
    setState(() => _isFlashOn = !_isFlashOn);
    if (_controller != null && _controller!.value.isInitialized) {
      await _controller!.setFlashMode(
        _isFlashOn ? FlashMode.torch : FlashMode.off,
      );
    }
  }

  bool _isSwitchingCamera = false;

  Future<void> _flipCamera() async {
    if (_isSwitchingCamera) return;
    _isSwitchingCamera = true;

    setState(() {
      _isRearCamera = !_isRearCamera;
    });

    await _controller?.dispose();
    _controller = null;
    setState(() {});

    await _initCamera();

    _isSwitchingCamera = false;
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!(_controller?.value.isInitialized ?? false)) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          CameraPreview(_controller!),
          Positioned(
            top: 40,
            right: 20,
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
                  icon: Icon(Icons.cameraswitch, color: Colors.white),
                  onPressed: _flipCamera,
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 40),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  GestureDetector(
                    onTap: _pickFromGallery,
                    child:
                        _latestGalleryFile != null
                            ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                File(_latestGalleryFile!.path),
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                              ),
                            )
                            : Icon(
                              Icons.photo_library,
                              size: 40,
                              color: Colors.white,
                            ),
                  ),
                  GestureDetector(
                    onTap: _takePhoto,
                    child: Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                      ),
                      child: CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.white,
                      ),
                    ),
                  ),
                  SizedBox(width: 60), // Empty right side for future buttons
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

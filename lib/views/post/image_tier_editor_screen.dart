import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:ui' as ui;
import 'dart:async';
import '../../../services/create_post.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_cropper/image_cropper.dart';
import 'image_video_selector.dart';

class ImageTier {
  String region;
  int credits;
  String previewUrl;

  ImageTier({
    required this.region,
    required this.credits,
    required this.previewUrl,
  });
}

class ImageTierEditorScreen extends StatefulWidget {
  final XFile file;

  const ImageTierEditorScreen({super.key, required this.file});

  @override
  _ImageTierEditorScreenState createState() => _ImageTierEditorScreenState();
}

class _ImageTierEditorScreenState extends State<ImageTierEditorScreen>
    with WidgetsBindingObserver {
  List<ImageTier> _tiers = [];
  bool _isUploading = false;
  final Set<String> _selectedRegions = {};
  List<Offset> _drawnPoints = [];

  bool get isSelectMode => _selectedRegions.contains('draw');
  ui.Image? _loadedImage;
  double _blurSigma = 10.0;
  bool _isErasing = false;
  double _brushSize = 15.0;
  int _tierCount = 0;

  bool _showSettings = false;

  File? _currentImage;

  int? _postId;

  final List<String> regions = [
    'draw',
    'tits',
    'ass',
    'face',
    'genitals',
    'legs',
    'stomach',
    'feet',
  ];

  final Map<String, IconData> regionIcons = {
    'draw': Icons.draw,
    'tits': Icons.favorite,
    'ass': Icons.circle,
    'face': Icons.face,
    'genitals': Icons.lock,
    'legs': Icons.directions_walk,
    'stomach': Icons.fitness_center,
    'feet': Icons.directions_run,
  };

  Future<File?> cropTo9by16(XFile originalFile) async {
    final cropped = await ImageCropper().cropImage(
      sourcePath: originalFile.path,
      aspectRatio: CropAspectRatio(ratioX: 9, ratioY: 16),
      compressFormat: ImageCompressFormat.png,
      uiSettings: [
        AndroidUiSettings(toolbarTitle: 'Crop Image', lockAspectRatio: true),
        IOSUiSettings(title: 'Crop Image', aspectRatioLockEnabled: true),
      ],
    );

    if (cropped == null) return null;
    return File(cropped.path);
  }

  Future<Map<String, dynamic>?> _showTierDetailsDialog(
    BuildContext context, {
    required bool isFirstTier,
  }) async {
    final TextEditingController labelController = TextEditingController(
      text: "Premium",
    );
    final TextEditingController descriptionController = TextEditingController();
    final TextEditingController creditsController = TextEditingController(
      text: "0",
    );

    File? selectedImage;

    Future<void> _pickImage(ImageSource source) async {
      final picked = await ImagePicker().pickImage(source: source);
      if (picked != null) {
        selectedImage = File(picked.path);
      }
    }

    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.grey[900],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            top: 24,
          ),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _tierCount == 0 ? "Public Preview Tier" : "Tier Details",
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                  SizedBox(height: 16),
                  if (_tierCount > 0) ...[
                    TextField(
                      controller: labelController,
                      style: TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Title',
                        labelStyle: TextStyle(color: Colors.white70),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white),
                        ),
                        filled: true,
                        fillColor: Colors.grey[850],
                      ),
                    ),
                  ],
                  SizedBox(height: 12),
                  TextField(
                    controller: descriptionController,
                    style: TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Description',
                      labelStyle: TextStyle(color: Colors.white70),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white),
                      ),
                      filled: true,
                      fillColor: Colors.grey[850],
                    ),
                  ),
                  SizedBox(height: 12),

                  if (_tierCount > 0) ...[
                    TextField(
                      controller: creditsController,
                      style: TextStyle(color: Colors.white),
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Credits',
                        labelStyle: TextStyle(color: Colors.white70),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white),
                        ),
                        filled: true,
                        fillColor: Colors.grey[850],
                      ),
                    ),
                    SizedBox(height: 20),

                    if (selectedImage != null) ...[
                      SizedBox(height: 8),
                      Text(
                        "Selected Image:",
                        style: TextStyle(color: Colors.white),
                      ),
                      SizedBox(height: 6),
                      Image.file(selectedImage!, height: 150),
                    ],
                  ],

                  SizedBox(height: 20),

                  ElevatedButton(
                    onPressed: () {
                      final label =
                          _tierCount == 0
                              ? "Free"
                              : labelController.text.trim();
                      final description = descriptionController.text.trim();
                      final credits =
                          _tierCount == 0
                              ? 0
                              : int.tryParse(creditsController.text.trim()) ??
                                  0;

                      if (label.isEmpty || credits < 0) {
                        Navigator.pop(context, null); // Validation fail
                      } else {
                        Navigator.pop(context, {
                          'label': label,
                          'description': description,
                          'credits': credits,
                          'image': selectedImage, // may be null
                        });
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      minimumSize: Size(double.infinity, 45),
                    ),
                    child: Text("Continue"),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  void _generateCombinedBlurPreview() async {
    final regionsToBlur = _selectedRegions.toList();

    final blurredUrl = await CreatePostService.generateBlurPreview(
      imageFile: _currentImage!,
      regionsToBlur: regionsToBlur,
    );

    if (blurredUrl != null) {
      setState(() {
        _tiers = [
          ImageTier(
            region: regionsToBlur.join(', '),
            credits: 0,
            previewUrl: blurredUrl,
          ),
        ];
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to generate blur preview.")),
      );
    }
  }

  Future<void> _loadImage() async {
    final completer = Completer<ui.Image>();
    final bytes = await _currentImage!.readAsBytes();
    ui.decodeImageFromList(bytes, (img) => completer.complete(img));
    final image = await completer.future;
    if (!mounted) return;
    setState(() {
      _loadedImage = image;
    });
  }

  Future<File> resizeImageToStandard(File file) async {
    final completer = Completer<ui.Image>();
    final bytes = await file.readAsBytes();
    ui.decodeImageFromList(bytes, (img) => completer.complete(img));
    final originalImage = await completer.future;

    const targetWidth = 1080;
    const targetHeight = 1920;
    final size = Size(targetWidth.toDouble(), targetHeight.toDouble());
    final dstRect = Rect.fromLTWH(0, 0, size.width, size.height);

    final srcAspect = originalImage.width / originalImage.height;
    final dstAspect = targetWidth / targetHeight;

    Rect srcRect;
    if (srcAspect > dstAspect) {
      final newWidth = originalImage.height * dstAspect;
      final offsetX = (originalImage.width - newWidth) / 2;
      srcRect = Rect.fromLTWH(
        offsetX,
        0,
        newWidth,
        originalImage.height.toDouble(),
      );
    } else {
      final newHeight = originalImage.width / dstAspect;
      final offsetY = (originalImage.height - newHeight) / 2;
      srcRect = Rect.fromLTWH(
        0,
        offsetY,
        originalImage.width.toDouble(),
        newHeight,
      );
    }

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawImageRect(originalImage, srcRect, dstRect, Paint());
    final finalImage = await recorder.endRecording().toImage(
      targetWidth,
      targetHeight,
    );

    final byteData = await finalImage.toByteData(
      format: ui.ImageByteFormat.png,
    );
    final buffer = byteData!.buffer.asUint8List();

    final outputFile = File(
      '${(await getTemporaryDirectory()).path}/resized_original.png',
    );
    await outputFile.writeAsBytes(buffer, flush: true);

    return outputFile;
  }

  Future<File> _exportBlurredImage() async {
    // If no blur points, return original
    if (_drawnPoints.where((p) => p != Offset.zero).isEmpty) {
      print("⚠️ No blur points — skipping blur.");
      return _currentImage!; // original unblurred image
    }

    final recorder = ui.PictureRecorder();

    const targetWidth = 1080;
    const targetHeight = 1920;
    final size = Size(targetWidth.toDouble(), targetHeight.toDouble());
    final dstRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final srcAspect = _loadedImage!.width / _loadedImage!.height;
    final dstAspect = targetWidth / targetHeight;

    Rect srcRect;
    if (srcAspect > dstAspect) {
      final newWidth = _loadedImage!.height * dstAspect;
      final offsetX = (_loadedImage!.width - newWidth) / 2;
      srcRect = Rect.fromLTWH(
        offsetX,
        0,
        newWidth,
        _loadedImage!.height.toDouble(),
      );
    } else {
      final newHeight = _loadedImage!.width / dstAspect;
      final offsetY = (_loadedImage!.height - newHeight) / 2;
      srcRect = Rect.fromLTWH(
        0,
        offsetY,
        _loadedImage!.width.toDouble(),
        newHeight,
      );
    }

    final canvas = Canvas(recorder);

    // 1. Draw the base image
    canvas.drawImageRect(
      _loadedImage!,
      Rect.fromLTWH(
        0,
        0,
        _loadedImage!.width.toDouble(),
        _loadedImage!.height.toDouble(),
      ),
      dstRect,
      Paint(),
    );

    // 2. Create a blurred version of the image
    final blurRecorder = ui.PictureRecorder();
    final blurCanvas = Canvas(blurRecorder);
    blurCanvas.drawImageRect(
      _loadedImage!,
      Rect.fromLTWH(
        0,
        0,
        _loadedImage!.width.toDouble(),
        _loadedImage!.height.toDouble(),
      ),
      dstRect,
      Paint()
        ..imageFilter = ui.ImageFilter.blur(
          sigmaX: _blurSigma,
          sigmaY: _blurSigma,
        ),
    );
    final blurredImage = await blurRecorder.endRecording().toImage(
      size.width.toInt(),
      size.height.toInt(),
    );

    // 3. Create a mask from drawn points
    final maskRecorder = ui.PictureRecorder();
    final maskCanvas = Canvas(maskRecorder);
    for (final point in _drawnPoints.where((p) => p != Offset.zero)) {
      final scaled = Offset(
        point.dx * size.width / context.size!.width,
        point.dy * size.height / context.size!.height,
      );
      final gradient = ui.Gradient.radial(
        scaled,
        _brushSize,
        [Colors.white, Colors.transparent],
        [0.0, 1.0],
      );
      final paint = Paint()..shader = gradient;
      maskCanvas.drawCircle(scaled, _brushSize, paint);
    }
    final maskImage = await maskRecorder.endRecording().toImage(
      size.width.toInt(),
      size.height.toInt(),
    );

    // 4. Apply blurred image through mask
    canvas.saveLayer(dstRect, Paint()); // Save base

    canvas.drawImage(blurredImage, Offset.zero, Paint()); // blurred layer
    canvas.drawImage(
      maskImage,
      Offset.zero,
      Paint()..blendMode = BlendMode.dstIn, // use mask
    );

    canvas.restore(); // Apply mask to blurred layer

    final finalImage = await recorder.endRecording().toImage(
      size.width.toInt(),
      size.height.toInt(),
    );
    final byteData = await finalImage.toByteData(
      format: ui.ImageByteFormat.png,
    );
    final buffer = byteData!.buffer.asUint8List();

    final file = File(
      '${(await getTemporaryDirectory()).path}/blurred_final.png',
    );
    await file.writeAsBytes(buffer, flush: true);

    print("✅ Final blurred image saved to: ${file.path}");
    return file;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _selectedRegions.add('draw'); // default to draw mode
    _prepareImage();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _drawnPoints.clear();
    _selectedRegions.clear();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      print('App paused — maybe save work in progress.');
    } else if (state == AppLifecycleState.resumed) {
      print('App resumed — restore any needed state.');
    }
  }

  Future<void> _prepareImage() async {
    final cropped = await cropTo9by16(widget.file);
    if (cropped == null) {
      Navigator.pop(context);
      return;
    }

    final resized = await resizeImageToStandard(cropped);

    if (!mounted) return;

    setState(() {
      _currentImage = resized;
    });

    await _loadImage();
  }

  Future<void> _handleCrop() async {
    final cropped = await ImageCropper().cropImage(
      sourcePath: _currentImage!.path,
      aspectRatio: CropAspectRatio(ratioX: 9, ratioY: 16),
      compressFormat: ImageCompressFormat.png,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Edit Image',
          lockAspectRatio: true,
          showCropGrid: true,
        ),
        IOSUiSettings(title: 'Edit Image', aspectRatioLockEnabled: false),
      ],
    );

    if (cropped == null) return;

    final resized = await resizeImageToStandard(File(cropped.path));
    if (!mounted) return;

    setState(() {
      _currentImage = resized;
      _drawnPoints.clear(); // reset drawing
    });

    await _loadImage();
  }

  @override
  Widget build(BuildContext context) {
    // 🚨 Prevent build from accessing null image before it's ready
    if (_currentImage == null || _loadedImage == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body:
          _isUploading
              ? Center(child: CircularProgressIndicator(color: Colors.white))
              : SafeArea(
                child: Column(
                  children: [
                    Expanded(
                      child: Stack(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: EdgeInsets.all(16),
                                child: Text(
                                  _tierCount == 0
                                      ? "This is your FREE tier. Everyone can see it!"
                                      : "Tier ${_tierCount + 1} – Visible after purchase",
                                  style: TextStyle(color: Colors.white70),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Stack(
                                    children: [
                                      Image.file(_currentImage!),
                                      if (_loadedImage != null)
                                        Positioned.fill(
                                          child: GestureDetector(
                                            onPanUpdate: (details) {
                                              RenderBox box =
                                                  context.findRenderObject()
                                                      as RenderBox;
                                              Offset local = box.globalToLocal(
                                                details.globalPosition,
                                              );
                                              setState(() {
                                                if (_isErasing) {
                                                  _drawnPoints.removeWhere(
                                                    (p) =>
                                                        (p - local).distance <
                                                        20,
                                                  );
                                                } else {
                                                  _drawnPoints = List.from(
                                                    _drawnPoints,
                                                  )..add(local);
                                                }
                                              });
                                            },
                                            onPanEnd:
                                                (_) => setState(
                                                  () => _drawnPoints.add(
                                                    Offset.zero,
                                                  ),
                                                ),
                                            child: CustomPaint(
                                              painter: BlurPainter(
                                                points: _drawnPoints,
                                                backgroundImage: _loadedImage!,
                                                blurSigma: _blurSigma,
                                                brushSize: _brushSize,
                                              ),
                                              child: Container(),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),

                              /*
          // 👇 Commented out body part selection
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: regions.map((region) {
                ...
              }).toList(),
            ),
          ),
          */
                              Expanded(
                                child: SingleChildScrollView(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children:
                                        _tiers.map((tier) {
                                          return Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                "${tier.region.toUpperCase()} Tier",
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              SizedBox(height: 8),
                                              ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                child: Image.network(
                                                  tier.previewUrl,
                                                  height: 150,
                                                ),
                                              ),
                                              SizedBox(height: 8),
                                              TextField(
                                                keyboardType:
                                                    TextInputType.number,
                                                style: TextStyle(
                                                  color: Colors.white,
                                                ),
                                                decoration: InputDecoration(
                                                  labelText: "Credits",
                                                  labelStyle: TextStyle(
                                                    color: Colors.white70,
                                                  ),
                                                  enabledBorder:
                                                      OutlineInputBorder(
                                                        borderSide: BorderSide(
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                  focusedBorder:
                                                      OutlineInputBorder(
                                                        borderSide: BorderSide(
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                ),
                                                onChanged: (val) {
                                                  setState(() {
                                                    tier.credits =
                                                        int.tryParse(val) ?? 0;
                                                  });
                                                },
                                              ),
                                              SizedBox(height: 20),
                                            ],
                                          );
                                        }).toList(),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          if (_showSettings)
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 80, // or adjust as needed
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Material(
                                  color: Colors.grey[900],
                                  elevation: 12,
                                  borderRadius: BorderRadius.circular(12),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          "Blur Strength: ${_blurSigma.toStringAsFixed(1)}",
                                          style: TextStyle(color: Colors.white),
                                        ),
                                        Slider(
                                          value: _blurSigma,
                                          min: 1.0,
                                          max: 30.0,
                                          divisions: 29,
                                          onChanged: (val) {
                                            setState(() {
                                              _blurSigma = val;
                                            });
                                          },
                                        ),
                                        Text(
                                          "Brush Size: ${_brushSize.toStringAsFixed(1)}",
                                          style: TextStyle(color: Colors.white),
                                        ),
                                        Slider(
                                          value: _brushSize,
                                          min: 5.0,
                                          max: 60.0,
                                          divisions: 55,
                                          onChanged: (val) {
                                            setState(() {
                                              _brushSize = val;
                                            });
                                          },
                                        ),
                                        Row(
                                          children: [
                                            TextButton.icon(
                                              onPressed:
                                                  () => setState(
                                                    () => _drawnPoints.clear(),
                                                  ),
                                              icon: Icon(
                                                Icons.clear,
                                                color: Colors.white,
                                              ),
                                              label: Text(
                                                "Clear",
                                                style: TextStyle(
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                            Spacer(),
                                            IconButton(
                                              icon: Icon(
                                                _isErasing
                                                    ? Icons.remove_circle
                                                    : Icons.blur_on,
                                                color:
                                                    _isErasing
                                                        ? Colors.red
                                                        : Colors.white,
                                              ),
                                              onPressed: () {
                                                setState(
                                                  () =>
                                                      _isErasing = !_isErasing,
                                                );
                                              },
                                              tooltip:
                                                  _isErasing
                                                      ? 'Erasing Mode'
                                                      : 'Blurring Mode',
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),

                          // ✅ Floating Action Button for blur settings toggle
                          Positioned(
                            bottom: 16,
                            right: 16,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (_tierCount > 0) ...[
                                  FloatingActionButton(
                                    heroTag: "camera",
                                    backgroundColor: Colors.white,
                                    onPressed: () async {
                                      final picked = await Navigator.of(
                                        context,
                                      ).push<XFile>(
                                        PageRouteBuilder(
                                          pageBuilder: (
                                            BuildContext context,
                                            __,
                                            ___,
                                          ) {
                                            return ImageVideoSelector(
                                              onMediaSelected: (
                                                mediaType,
                                                file,
                                              ) {
                                                if (mediaType == 'image') {
                                                  Navigator.of(context).pop(
                                                    file,
                                                  ); // ✅ use this context!
                                                }
                                              },
                                            );
                                          },
                                          opaque:
                                              false, // ✅ Ensures no white background
                                          fullscreenDialog:
                                              true, // ✅ For fullscreen layout
                                          barrierColor:
                                              Colors
                                                  .black, // ✅ Optional: matches black camera background
                                          transitionsBuilder:
                                              (_, animation, __, child) =>
                                                  FadeTransition(
                                                    opacity: animation,
                                                    child: child,
                                                  ),
                                        ),
                                      );
                                      if (picked != null) {
                                        final cropped = await cropTo9by16(
                                          XFile(picked.path),
                                        );
                                        if (cropped != null) {
                                          final resized =
                                              await resizeImageToStandard(
                                                cropped,
                                              );
                                          setState(() {
                                            _currentImage = resized;
                                            _drawnPoints.clear();
                                          });
                                          await _loadImage();
                                        }
                                      }
                                    },
                                    tooltip: "Take Photo",
                                    child: Icon(
                                      Icons.camera_alt,
                                      color: Colors.black,
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                ],
                                FloatingActionButton(
                                  heroTag: "crop",
                                  backgroundColor: Colors.white,
                                  onPressed: _handleCrop,
                                  tooltip: "Crop",
                                  child: Icon(Icons.crop, color: Colors.black),
                                ),
                                SizedBox(width: 12),
                                FloatingActionButton(
                                  heroTag: "draw",
                                  backgroundColor: Colors.white,
                                  onPressed: () {
                                    setState(
                                      () => _showSettings = !_showSettings,
                                    );
                                  },
                                  tooltip: "Draw",
                                  child: Icon(Icons.draw, color: Colors.black),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: ElevatedButton.icon(
                        icon: Icon(Icons.check, color: Colors.black),
                        label: Text(
                          _tierCount == 0
                              ? "Post Public Preview"
                              : "Add Secret Tier",
                          style: TextStyle(color: Colors.black),
                        ),
                        onPressed: () async {
                          final result = await _showTierDetailsDialog(
                            context,
                            isFirstTier: _tierCount == 0,
                          );
                          if (result == null) return;

                          final String label = result['label'];
                          final String description = result['description'];
                          final int credits = result['credits'];
                          final File? newTierImage = result['image'] as File?;

                          setState(() => _isUploading = true);

                          if (_tierCount == 0) {
                            // 🔓 FREE TIER — always use currentImage + blur
                            final resizedMainImage =
                                await resizeImageToStandard(_currentImage!);
                            final blurredImage = await _exportBlurredImage();

                            final response = await CreatePostService.uploadTier(
                              imageFile: blurredImage,
                              credits: credits,
                              postId: 0,
                              label: label,
                              description: description,
                              mainPostAsset: resizedMainImage,
                              blurSigma: _blurSigma,
                              brushSize: _brushSize,
                              drawnPoints: _drawnPoints,
                            );

                            // parse postId from response
                            if (response != null &&
                                response['post_id'] != null) {
                              setState(() {
                                _postId = response['post_id'];
                              });
                            }

                            print("Free tier uploaded: $response");

                            await showDialog(
                              context: context,
                              builder:
                                  (_) => AlertDialog(
                                    content: Image.file(blurredImage),
                                  ),
                            );
                          } else {
                            // 🔐 PREMIUM TIER

                            File imageToUpload;

                            if (newTierImage != null) {
                              // 🚫 User picked new image — skip blur
                              imageToUpload = await resizeImageToStandard(
                                newTierImage,
                              );
                            } else {
                              // ✅ Use original and apply blur
                              imageToUpload = await _exportBlurredImage();

                              await showDialog(
                                context: context,
                                builder:
                                    (_) => AlertDialog(
                                      content: Image.file(imageToUpload),
                                    ),
                              );
                            }

                            final response = await CreatePostService.uploadTier(
                              imageFile: imageToUpload,
                              credits: credits,
                              postId: _postId ?? 0,
                              label: label,
                              description: description,
                              mainPostAsset: null,
                              blurSigma: _blurSigma,
                              brushSize: _brushSize,
                              drawnPoints: _drawnPoints,
                            );
                            print("Tier uploaded: $response");
                          }

                          setState(() {
                            _tierCount++;
                            _drawnPoints.clear();
                            _selectedRegions.clear();
                            _tiers.clear();
                            _isUploading = false;
                          });

                          _loadImage(); // Only reloads original base image
                        },

                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          minimumSize: Size(double.infinity, 50),
                          disabledBackgroundColor: Colors.grey.shade700,
                        ),
                      ),
                    ),
                    if (_tierCount > 0)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: TextButton(
                          onPressed: () {
                            // Finalize post and navigate away
                            print(
                              "Skipping additional tiers. Finalizing post...",
                            );
                            // TODO: Call CreatePostService.finalizePost() or navigate
                            Navigator.pop(context); // Placeholder
                          },
                          child: Text(
                            "Skip & Post",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
    );
  }
}

class BlurPainter extends CustomPainter {
  final List<Offset> points;
  final double brushSize;
  final double blurSigma;
  final ui.Image backgroundImage;

  BlurPainter({
    required this.points,
    required this.backgroundImage,
    this.brushSize = 15.0,
    this.blurSigma = 10.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;

    canvas.drawImageRect(
      backgroundImage,
      Rect.fromLTWH(
        0,
        0,
        backgroundImage.width.toDouble(),
        backgroundImage.height.toDouble(),
      ),
      bounds,
      Paint(),
    );

    final blurLayer =
        Paint()
          ..imageFilter = ui.ImageFilter.blur(
            sigmaX: blurSigma,
            sigmaY: blurSigma,
          );

    final maskPaint = Paint()..blendMode = BlendMode.srcIn;

    canvas.saveLayer(bounds, Paint());

    for (final point in points) {
      if (point != Offset.zero) {
        final gradient = ui.Gradient.radial(
          point,
          brushSize,
          [Colors.white, Colors.transparent],
          [0.0, 1.0],
        );

        final radialPaint =
            Paint()
              ..shader = gradient
              ..blendMode = BlendMode.srcOver;

        canvas.drawCircle(point, brushSize, radialPaint);
      }
    }

    canvas.saveLayer(bounds, maskPaint);
    canvas.drawImageRect(
      backgroundImage,
      Rect.fromLTWH(
        0,
        0,
        backgroundImage.width.toDouble(),
        backgroundImage.height.toDouble(),
      ),
      bounds,
      blurLayer,
    );

    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'stream2pixel.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Request camera permission
  final status = await Permission.camera.request();
  if (!status.isGranted) {
    debugPrint('Camera permission not granted');
    return;
  }

  CameraDescription camera;
  try {
    final cameras = await availableCameras();
    camera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );
  } catch (e) {
    // If running in test mode or no cameras available, use a mock camera
    camera = CameraDescription(
      name: 'mock_camera',
      lensDirection: CameraLensDirection.front,
      sensorOrientation: 0,
    );
  }

  runApp(MyApp(camera: camera));
}

class MyApp extends StatelessWidget {
  final CameraDescription camera;

  const MyApp({super.key, required this.camera});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Image to Pixel Converter',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: CameraScreen(camera: camera),
    );
  }
}

class CameraScreen extends StatefulWidget {
  final CameraDescription camera;

  const CameraScreen({super.key, required this.camera});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  List<String>? _pixelData;
  bool _isProcessing = false;
  bool _isCapturing = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    _controller = CameraController(
      widget.camera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup:
          Platform.isIOS
              ? ImageFormatGroup
                  .bgra8888 // Use BGRA for iOS
              : ImageFormatGroup.yuv420, // Keep YUV for Android
    );
    _initializeControllerFuture = _controller.initialize();
    setState(() {});
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _captureImage() async {
    if (_isProcessing || _isCapturing) return;

    try {
      setState(() {
        _isCapturing = true;
      });

      await _initializeControllerFuture;

      // Start image stream
      await _controller.startImageStream((CameraImage image) async {
        if (_isProcessing) return;

        setState(() {
          _isProcessing = true;
        });

        try {
          // Convert stream to pixels using the new class
          final pixelData = StreamToPixel.convertStreamToPixels(image);

          setState(() {
            _pixelData = pixelData;
          });

          // Stop the image stream
          await _controller.stopImageStream();

          if (mounted) {
            _showPixelDataDialog();
          }
        } catch (e) {
          debugPrint('Error processing image stream: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Error processing image')),
            );
          }
        } finally {
          setState(() {
            _isProcessing = false;
            _isCapturing = false;
          });
        }
      });
    } catch (e) {
      debugPrint('Error capturing image: $e');
      setState(() {
        _isCapturing = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Error capturing image')));
      }
    }
  }

  void _showPixelDataDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Pixel Data'),
            content: SingleChildScrollView(
              child: Text(
                'Total pixels: ${_pixelData?.length ?? 0}\n'
                'First few pixels: ${_pixelData?.take(5).join(', ')}',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _showReconstructedImage();
                },
                child: const Text('Next'),
              ),
            ],
          ),
    );
  }

  Future<void> _showReconstructedImage() async {
    if (_pixelData == null) return;

    try {
      // Get the dimensions from the camera controller
      final width = _controller.value.previewSize!.width.toInt();
      final height = _controller.value.previewSize!.height.toInt();

      // Create a new image
      final reconstructedImage = img.Image(
        width: height, // Swap width and height
        height: width, // Swap width and height
      );

      // Reconstruct image from pixel data with rotation
      int pixelIndex = 0;
      for (var y = 0; y < height; y++) {
        for (var x = 0; x < width; x++) {
          if (pixelIndex < _pixelData!.length) {
            final pixelStr = _pixelData![pixelIndex];
            final rgba = pixelStr.substring(5, pixelStr.length - 1).split(',');
            final r = int.parse(rgba[0]);
            final g = int.parse(rgba[1]);
            final b = int.parse(rgba[2]);
            final a = int.parse(rgba[3]);
            // Rotate 90 degrees clockwise by swapping x and y coordinates
            reconstructedImage.setPixelRgba(y, width - 1 - x, r, g, b, a);
            pixelIndex++;
          }
        }
      }

      // Convert reconstructed image to bytes
      final reconstructedBytes = img.encodePng(reconstructedImage);

      // Create temporary file for reconstructed image
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/reconstructed.png');
      await tempFile.writeAsBytes(reconstructedBytes);

      if (!mounted) return;

      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Reconstructed Image'),
              content: Image.file(tempFile),
              actions: [
                TextButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    setState(() {
                      _pixelData = null;
                    });
                    // Clean up temporary file
                    await tempFile.delete();
                  },
                  child: const Text('Close'),
                ),
              ],
            ),
      );
    } catch (e) {
      debugPrint('Error showing reconstructed image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error showing reconstructed image')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Image to Pixel Converter')),
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return CameraPreview(_controller);
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: (_isProcessing || _isCapturing) ? null : _captureImage,
        child:
            (_isProcessing || _isCapturing)
                ? const CircularProgressIndicator(color: Colors.white)
                : const Icon(Icons.camera),
      ),
    );
  }
}

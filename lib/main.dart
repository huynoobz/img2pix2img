import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:permission_handler/permission_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Request camera permission
  final status = await Permission.camera.request();
  if (!status.isGranted) {
    print('Camera permission not granted');
    return;
  }

  final cameras = await availableCameras();
  final frontCamera = cameras.firstWhere(
    (camera) => camera.lensDirection == CameraLensDirection.front,
    orElse: () => cameras.first,
  );
  runApp(MyApp(camera: frontCamera));
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
          final int width = image.width;
          final int height = image.height;
          final List<int> rgb = List<int>.filled(width * height * 3, 0);

          if (Platform.isIOS) {
            // Process BGRA format for iOS
            final Uint8List bgraBuffer = image.planes[0].bytes;
            for (int i = 0; i < width * height; i++) {
              final int offset = i * 4;
              // Convert BGRA to RGB
              rgb[i * 3] = bgraBuffer[offset + 2]; // R
              rgb[i * 3 + 1] = bgraBuffer[offset + 1]; // G
              rgb[i * 3 + 2] = bgraBuffer[offset]; // B
            }
          } else {
            // Process YUV format for Android
            final int uvRowStride = image.planes[1].bytesPerRow;
            final int uvPixelStride = image.planes[1].bytesPerPixel!;

            final Uint8List yBuffer = image.planes[0].bytes;
            final Uint8List uBuffer = image.planes[1].bytes;
            final Uint8List vBuffer = image.planes[2].bytes;

            for (int y = 0; y < height; y++) {
              for (int x = 0; x < width; x++) {
                final int uvIndex =
                    uvPixelStride * (x / 2).floor() +
                    uvRowStride * (y / 2).floor();
                final int index = (y * width + x) * 3;

                final int yp = yBuffer[y * width + x];
                final int up = uBuffer[uvIndex];
                final int vp = vBuffer[uvIndex];

                // Convert YUV to RGB
                int r = (yp + vp * 1436 / 1024 - 179).round().clamp(0, 255);
                int g = (yp -
                        up * 46549 / 131072 +
                        44 -
                        vp * 93604 / 131072 +
                        91)
                    .round()
                    .clamp(0, 255);
                int b = (yp + up * 1814 / 1024 - 227).round().clamp(0, 255);

                rgb[index] = r;
                rgb[index + 1] = g;
                rgb[index + 2] = b;
              }
            }
          }

          // Create image from RGB data
          final img.Image rgbImage = img.Image.fromBytes(
            width: width,
            height: height,
            bytes: Uint8List.fromList(rgb).buffer,
            numChannels: 3,
          );

          // Convert to pixel data
          final pixelData = <String>[];
          for (var y = 0; y < height; y++) {
            for (var x = 0; x < width; x++) {
              final pixel = rgbImage.getPixel(x, y);
              final r = pixel.r;
              final g = pixel.g;
              final b = pixel.b;
              final a = 255; // Full opacity
              pixelData.add('RGBA($r,$g,$b,$a)');
            }
          }

          setState(() {
            _pixelData = pixelData;
          });

          // Stop the image stream
          await _controller.stopImageStream();

          if (mounted) {
            _showPixelDataDialog();
          }
        } catch (e) {
          print('Error processing image stream: $e');
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
      print('Error capturing image: $e');
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
      print('Error showing reconstructed image: $e');
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

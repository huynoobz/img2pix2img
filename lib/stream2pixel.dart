import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;

class StreamToPixel {
  /// Converts a camera image stream to pixel data
  /// Returns a list of RGBA pixel values as strings
  static List<String> convertStreamToPixels(CameraImage image) {
    final int width = image.width;
    final int height = image.height;
    final List<int> rgb = List<int>.filled(width * height * 3, 0);

    if (image.format.group == ImageFormatGroup.bgra8888) {
      // Process BGRA format (iOS)
      final Uint8List bgraBuffer = image.planes[0].bytes;
      for (int i = 0; i < width * height; i++) {
        final int offset = i * 4;
        // Convert BGRA to RGB
        rgb[i * 3] = bgraBuffer[offset + 2]; // R
        rgb[i * 3 + 1] = bgraBuffer[offset + 1]; // G
        rgb[i * 3 + 2] = bgraBuffer[offset]; // B
      }
    } else {
      // Process YUV format (Android)
      final int uvRowStride = image.planes[1].bytesPerRow;
      final int uvPixelStride = image.planes[1].bytesPerPixel!;

      final Uint8List yBuffer = image.planes[0].bytes;
      final Uint8List uBuffer = image.planes[1].bytes;
      final Uint8List vBuffer = image.planes[2].bytes;

      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final int uvIndex =
              uvPixelStride * (x / 2).floor() + uvRowStride * (y / 2).floor();
          final int index = (y * width + x) * 3;

          final int yp = yBuffer[y * width + x];
          final int up = uBuffer[uvIndex];
          final int vp = vBuffer[uvIndex];

          // Convert YUV to RGB
          int r = (yp + vp * 1436 / 1024 - 179).round().clamp(0, 255);
          int g = (yp - up * 46549 / 131072 + 44 - vp * 93604 / 131072 + 91)
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

    return pixelData;
  }
}

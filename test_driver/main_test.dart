import 'package:integration_test/integration_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:img2pix2img/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('end-to-end test', () {
    testWidgets('tap on button, verify camera preview', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Verify that the app title is displayed
      expect(find.text('Image to Pixel Converter'), findsOneWidget);

      // Verify that the camera preview is present
      expect(find.byType(CameraPreview), findsOneWidget);

      // Verify that the floating action button is present
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });
  });
}

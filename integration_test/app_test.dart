import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:img2pix2img/main.dart' as app;
import 'package:camera/camera.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('End-to-end test', () {
    testWidgets('App launches successfully', (WidgetTester tester) async {
      // Create a mock camera
      final mockCamera = CameraDescription(
        name: 'mock_camera',
        lensDirection: CameraLensDirection.front,
        sensorOrientation: 0,
      );

      // Initialize the app with mock camera
      app.main();
      await tester.pumpAndSettle();

      // Verify the app title is present
      expect(find.text('Image to Pixel Converter'), findsOneWidget);
    });
  });
}

// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in the test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:camera/camera.dart';
import 'package:img2pix2img/main.dart';

void main() {
  testWidgets('App initialization test', (WidgetTester tester) async {
    // Create a mock camera description
    final mockCamera = CameraDescription(
      name: 'mock_camera',
      lensDirection: CameraLensDirection.front,
      sensorOrientation: 0,
    );

    // Build our app and trigger a frame.
    await tester.pumpWidget(MyApp(camera: mockCamera));

    // Verify that the app title is displayed
    expect(find.text('Image to Pixel Converter'), findsOneWidget);

    // Wait for initial frame
    await tester.pump();

    // Verify that the floating action button is present
    expect(find.byType(FloatingActionButton), findsOneWidget);

    // Verify that the camera screen is present
    expect(find.byType(CameraScreen), findsOneWidget);
  });
}

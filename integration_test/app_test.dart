import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:img2pix2img/main.dart' as app;
import 'package:flutter/material.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('End-to-end test', () {
    testWidgets('App launches successfully', (WidgetTester tester) async {
      // Initialize the app
      app.main();
      await tester.pumpAndSettle();

      // Basic verification that the app is running
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });
}

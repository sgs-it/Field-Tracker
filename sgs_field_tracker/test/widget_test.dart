import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sgs_field_tracker/main.dart';
import 'package:sgs_field_tracker/tracker_state.dart';

void main() {
  testWidgets('SGS Tracker App initialization smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame wrapped in ChangeNotifierProvider.
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (context) => TrackerState(),
        child: const MyApp(),
      ),
    );

    // Verify that the main title exists or the widget mounts
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}

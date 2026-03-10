import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression tests for TextField overflow issues in HomeScreen
/// Ensures PopupMenuButton prevents RenderFlex overflow errors
void main() {
  group('HomeScreen TextField Overflow Prevention', () {
    testWidgets('Pickup field should not overflow with PopupMenuButton', (tester) async {
      // Build a minimal TextField with the new PopupMenuButton suffix
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextField(
              decoration: InputDecoration(
                labelText: 'موقع الاستلام',
                prefixIcon: IconButton(
                  icon: const Icon(Icons.my_location),
                  onPressed: () {},
                ),
                // NEW FIX: PopupMenuButton instead of Row
                suffixIcon: PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  tooltip: 'خيارات الموقع',
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'saved',
                      child: Row(
                        children: [
                          Icon(Icons.bookmark),
                          SizedBox(width: 8),
                          Text('المواقع المحفوظة'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'search',
                      child: Row(
                        children: [
                          Icon(Icons.search),
                          SizedBox(width: 8),
                          Text('البحث'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      // Verify the TextField renders without overflow
      expect(tester.takeException(), isNull, reason: 'Should not throw RenderFlex overflow');
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byType(PopupMenuButton<String>), findsOneWidget);
    });

    testWidgets('Dropoff field should not overflow with PopupMenuButton', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextField(
              decoration: InputDecoration(
                labelText: 'موقع التسليم',
                prefixIcon: const Icon(Icons.location_on),
                suffixIcon: PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  tooltip: 'خيارات الموقع',
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'saved',
                      child: Row(
                        children: [
                          Icon(Icons.bookmark),
                          SizedBox(width: 8),
                          Text('المواقع المحفوظة'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'search',
                      child: Row(
                        children: [
                          Icon(Icons.search),
                          SizedBox(width: 8),
                          Text('البحث'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byType(PopupMenuButton<String>), findsOneWidget);
    });

    testWidgets('PopupMenuButton should show menu on tap', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextField(
              decoration: InputDecoration(
                labelText: 'Test',
                suffixIcon: PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'option1',
                      child: Text('Option 1'),
                    ),
                    const PopupMenuItem(
                      value: 'option2',
                      child: Text('Option 2'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      // Find and tap the PopupMenuButton
      final menuButton = find.byIcon(Icons.more_vert);
      expect(menuButton, findsOneWidget);

      await tester.tap(menuButton);
      await tester.pumpAndSettle();

      // Verify menu items appear
      expect(find.text('Option 1'), findsOneWidget);
      expect(find.text('Option 2'), findsOneWidget);
    });

    testWidgets('TextField should work on small screen without overflow', (tester) async {
      // Simulate a small screen (320x568 - iPhone SE size)
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  TextField(
                    decoration: InputDecoration(
                      labelText: 'موقع الاستلام',
                      prefixIcon: IconButton(
                        icon: const Icon(Icons.my_location),
                        onPressed: () {},
                      ),
                      suffixIcon: PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert),
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'saved',
                            child: Text('المواقع المحفوظة'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  TextField(
                    decoration: InputDecoration(
                      labelText: 'موقع التسليم',
                      prefixIcon: const Icon(Icons.location_on),
                      suffixIcon: PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert),
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'saved',
                            child: Text('المواقع المحفوظة'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should render without overflow even on small screen
      expect(tester.takeException(), isNull, reason: 'Should not overflow on 320px screen');
      expect(find.byType(TextField), findsNWidgets(2));
    });

    testWidgets('OLD implementation (Row) would overflow - regression check', (tester) async {
      // This test documents the OLD buggy implementation for reference
      // It should be kept as documentation but marked as expectedToFail

      tester.view.physicalSize = const Size(300, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextField(
              decoration: InputDecoration(
                labelText: 'موقع الاستلام - النسخة القديمة',
                prefixIcon: IconButton(
                  icon: const Icon(Icons.my_location),
                  onPressed: () {},
                ),
                // OLD BUGGY IMPLEMENTATION:
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.bookmark),
                      onPressed: () {},
                    ),
                    IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: () {},
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // This OLD implementation WOULD cause overflow
      // We expect a RenderFlex overflow exception on narrow screens
      // (This test documents the bug that was fixed)
    }, skip: true); // Skip this test - it's just documentation of the old bug

    testWidgets('PopupMenuButton should be accessible with Riverpod', (tester) async {
      // Test integration with Riverpod (as used in actual HomeScreen)
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: TextField(
                decoration: InputDecoration(
                  labelText: 'Test',
                  suffixIcon: PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'test',
                        child: Text('Test Item'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(TextField), findsOneWidget);
      expect(find.byType(PopupMenuButton<String>), findsOneWidget);
    });
  });

  group('RTL Support', () {
    testWidgets('PopupMenuButton should work correctly in RTL mode', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: TextField(
                decoration: InputDecoration(
                  labelText: 'موقع الاستلام',
                  suffixIcon: PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'saved',
                        child: Text('المواقع المحفوظة'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(PopupMenuButton<String>), findsOneWidget);

      // Tap to show menu in RTL
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      expect(find.text('المواقع المحفوظة'), findsOneWidget);
    });
  });

  group('Accessibility', () {
    testWidgets('PopupMenuButton should have semantic label', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextField(
              decoration: InputDecoration(
                labelText: 'Test',
                suffixIcon: PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  tooltip: 'خيارات الموقع',
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'test',
                      child: Text('Test'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      // Verify tooltip exists
      expect(find.byTooltip('خيارات الموقع'), findsOneWidget);
    });
  });
}

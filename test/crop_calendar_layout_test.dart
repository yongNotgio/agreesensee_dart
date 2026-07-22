import 'package:agrisense/core/theme/app_theme.dart';
import 'package:agrisense/features/farmer/crop_calendar_screen.dart';
import 'package:agrisense/models/crop_declaration.dart';
import 'package:agrisense/models/enums.dart';
import 'package:agrisense/models/planned_activity.dart';
import 'package:agrisense/providers/data_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Calendar tab once rendered as a completely blank page on device.
///
/// The button themes set `minimumSize: Size.fromHeight(52)` — an *infinite*
/// minimum width. That is harmless wherever the incoming maxWidth is finite,
/// but the Skip button sat in a `Row` as a non-flex child, which is laid out
/// with unbounded width. `BoxConstraints forces an infinite width` was thrown
/// during `performLayout`, and a subtree whose layout throws paints nothing.
///
/// These tests pump the screen under the *real* [AppTheme] — under Flutter's
/// default button theme the bug is invisible, which is exactly why it reached a
/// device.
void main() {
  final today = DateTime(2026, 7, 22);

  PlannedActivity activity(String id, int offsetDays) => PlannedActivity(
        id: id,
        declarationId: 'decl-1',
        farmerId: 'farmer-1',
        activity: ActivityType.fertilizing,
        title: 'Apply basal fertilizer',
        scheduledOn: today.add(Duration(days: offsetDays)),
        daysAfterPlanting: offsetDays,
        suggestedInput: 'Complete 14-14-14',
        suggestedQtyPerHa: 100,
        unit: 'kg',
      );

  Widget harness(List<PlannedActivity> activities) => ProviderScope(
        overrides: [
          plannedActivitiesProvider.overrideWith((ref) async => activities),
          declarationsProvider.overrideWith((ref) async => <CropDeclaration>[]),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const CropCalendarScreen(embedded: true),
        ),
      );

  testWidgets('renders the month grid and agenda without a layout error',
      (tester) async {
    // A narrow phone — the size the blank page was reported on.
    tester.view.physicalSize = const Size(720, 1600);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      harness([activity('a', 0), activity('b', 3), activity('c', -2)]),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Next 14 days'), findsOneWidget);
    expect(find.text('Apply basal fertilizer'), findsWidgets);
    expect(find.text('Skip'), findsWidgets);
  });

  testWidgets('an activity tile lays both actions out side by side',
      (tester) async {
    tester.view.physicalSize = const Size(720, 1600);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(harness([activity('a', 1)]));
    await tester.pumpAndSettle();

    final confirm = tester.getRect(find.widgetWithText(FilledButton, 'I did this'));
    final skip = tester.getRect(find.widgetWithText(OutlinedButton, 'Skip'));

    // Finite, non-zero, and genuinely on one row.
    expect(confirm.width, greaterThan(0));
    expect(skip.width, greaterThan(0));
    expect(skip.width.isFinite, isTrue);
    expect(confirm.top, closeTo(skip.top, 0.5));
    expect(skip.left, greaterThan(confirm.right));
  });

  testWidgets('shows the empty state when nothing is scheduled',
      (tester) async {
    await tester.pumpWidget(harness(const []));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('No schedule yet'), findsOneWidget);
  });
}

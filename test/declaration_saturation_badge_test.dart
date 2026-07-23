import 'package:agrisense/core/logic/saturation_engine.dart';
import 'package:agrisense/core/theme/app_colors.dart';
import 'package:agrisense/core/widgets/form_fields.dart';
import 'package:agrisense/models/enums.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The crop picker must flag oversupplied crops inline without a layout error,
/// and the closed field must carry the selected crop's badge.
void main() {
  testWidgets('dropdown shows a saturation badge per crop', (tester) async {
    SaturationResult res(String id, SaturationLevel level) => SaturationResult(
          cropId: id,
          expectedSupplyTons: 100,
          demand: const DemandFigure(tons: 80, source: DemandSource.baseline),
          index: level == SaturationLevel.high ? 1.5 : 0.5,
          level: level,
          contributingDeclarations: 3,
          window: SaturationWindow.next(90),
        );
    final byCrop = {
      'ampalaya': res('ampalaya', SaturationLevel.high),
      'okra': res('okra', SaturationLevel.moderate),
      'tomato': res('tomato', SaturationLevel.low),
    };

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AppDropdown<String>(
          label: 'Crop',
          value: 'ampalaya',
          items: const ['ampalaya', 'okra', 'tomato'],
          itemLabel: (id) => id,
          itemTrailing: (id) => _badge(byCrop[id]),
          onChanged: (_) {},
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // Closed field shows the selected (oversupplied) crop's badge.
    expect(find.text('Oversupplied'), findsOneWidget);

    // Opening the menu lists every crop's badge.
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    expect(find.text('Oversupplied'), findsWidgets);
    expect(find.text('Near limit'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

// Mirror of the private _SaturationBadge to exercise the same rendering path.
Widget _badge(SaturationResult? r) {
  if (r == null) return const SizedBox.shrink();
  final (color, label) = switch (r.level) {
    SaturationLevel.high => (AppColors.riskHigh, 'Oversupplied'),
    SaturationLevel.moderate => (AppColors.riskModerate, 'Near limit'),
    SaturationLevel.low => (AppColors.riskLow, null),
  };
  final dot = Container(
    width: 8,
    height: 8,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
  if (label == null) return dot;
  return Row(mainAxisSize: MainAxisSize.min, children: [
    dot,
    const SizedBox(width: 5),
    Text(label,
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w700, color: color)),
  ]);
}

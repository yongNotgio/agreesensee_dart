import 'package:flutter/material.dart';

/// One cell of a [HeatmapGrid].
class HeatmapCell {
  const HeatmapCell({
    required this.value,
    required this.color,
    this.label,
    this.tooltip,
  });

  /// Underlying magnitude — used by the caller for ordering and intensity.
  final double value;
  final Color color;

  /// Text printed inside the cell. Meaning is never carried by colour alone,
  /// so this should normally be set.
  final String? label;
  final String? tooltip;
}

/// A scrollable matrix with a fixed first column, colour-coded cells, and a
/// legend.
///
/// Colour encodes magnitude but every cell also prints its number: hue alone
/// is unreadable for colour-blind users and unreliable in direct sunlight,
/// which is where this app is actually used.
class HeatmapGrid extends StatelessWidget {
  const HeatmapGrid({
    super.key,
    required this.rowLabels,
    required this.columnLabels,
    required this.cellBuilder,
    this.rowHeaderWidth = 116,
    this.cellWidth = 62,
    this.cellHeight = 44,
    this.onCellTap,
    this.highlightRow,
  });

  final List<String> rowLabels;
  final List<String> columnLabels;

  /// Resolves the cell at (row, column), or null when there is no datum.
  final HeatmapCell? Function(int row, int column) cellBuilder;

  final double rowHeaderWidth;
  final double cellWidth;
  final double cellHeight;
  final void Function(int row, int column)? onCellTap;

  /// Row index to emphasise — e.g. the farmer's own barangay.
  final int? highlightRow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (rowLabels.isEmpty || columnLabels.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text('No data to chart yet.',
            style: theme.textTheme.bodySmall),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Column headers.
          Row(
            children: [
              SizedBox(width: rowHeaderWidth),
              for (final label in columnLabels)
                SizedBox(
                  width: cellWidth,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          for (var r = 0; r < rowLabels.length; r++)
            Row(
              children: [
                SizedBox(
                  width: rowHeaderWidth,
                  height: cellHeight,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      rowLabels[r],
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: highlightRow == r
                            ? FontWeight.w800
                            : FontWeight.w500,
                        color: highlightRow == r
                            ? theme.colorScheme.primary
                            : null,
                      ),
                    ),
                  ),
                ),
                for (var c = 0; c < columnLabels.length; c++)
                  _Cell(
                    cell: cellBuilder(r, c),
                    width: cellWidth,
                    height: cellHeight,
                    onTap: onCellTap == null ? null : () => onCellTap!(r, c),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.cell,
    required this.width,
    required this.height,
    this.onTap,
  });

  final HeatmapCell? cell;
  final double width;
  final double height;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = cell;

    final content = Container(
      width: width - 4,
      height: height - 4,
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: c == null
            ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4)
            : c.color.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(7),
        border: c == null
            ? null
            : Border.all(color: c.color.withValues(alpha: 0.55)),
      ),
      alignment: Alignment.center,
      child: Text(
        c?.label ?? '–',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: c == null ? theme.colorScheme.onSurfaceVariant : c.color,
        ),
      ),
    );

    final tapped = onTap == null
        ? content
        : InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(7),
            child: content,
          );

    return c?.tooltip == null
        ? tapped
        : Tooltip(message: c!.tooltip!, child: tapped);
  }
}

/// A colour key for a [HeatmapGrid].
class HeatmapLegend extends StatelessWidget {
  const HeatmapLegend({super.key, required this.entries});

  /// Ordered label → colour pairs.
  final List<({String label, Color color})> entries;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 6,
      children: [
        for (final e in entries)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 11,
                height: 11,
                decoration: BoxDecoration(
                  color: e.color.withValues(alpha: 0.25),
                  border: Border.all(color: e.color),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 5),
              Text(e.label,
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600)),
            ],
          ),
      ],
    );
  }
}

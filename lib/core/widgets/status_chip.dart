import 'package:flutter/material.dart';

import '../../models/enums.dart';
import '../theme/app_colors.dart';

/// A compact, color-coded status pill used for declaration statuses, saturation
/// levels, and verification states.
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.dense = false,
  });

  /// Build a chip for a [DeclarationStatus].
  factory StatusChip.declaration(DeclarationStatus status, {bool dense = false}) {
    final color = switch (status) {
      DeclarationStatus.approved ||
      DeclarationStatus.harvested =>
        AppColors.success,
      DeclarationStatus.pending => AppColors.pending,
      DeclarationStatus.bawApproved ||
      DeclarationStatus.technicianVerified =>
        AppColors.info,
      DeclarationStatus.correctionRequested => AppColors.warning,
      DeclarationStatus.rejected => AppColors.danger,
      DeclarationStatus.draft => Colors.blueGrey,
    };
    return StatusChip(
      label: status.label,
      color: color,
      icon: status.icon,
      dense: dense,
    );
  }

  /// Build a chip for a [SaturationLevel].
  factory StatusChip.saturation(SaturationLevel level, {bool dense = false}) {
    final color = switch (level) {
      SaturationLevel.low => AppColors.riskLow,
      SaturationLevel.moderate => AppColors.riskModerate,
      SaturationLevel.high => AppColors.riskHigh,
    };
    final icon = switch (level) {
      SaturationLevel.low => Icons.trending_down,
      SaturationLevel.moderate => Icons.trending_flat,
      SaturationLevel.high => Icons.trending_up,
    };
    return StatusChip(label: level.label, color: color, icon: icon, dense: dense);
  }

  /// Build a chip for a [VerificationStatus].
  factory StatusChip.verification(VerificationStatus status,
      {bool dense = false}) {
    final color = switch (status) {
      VerificationStatus.verified ||
      VerificationStatus.endorsed =>
        AppColors.success,
      VerificationStatus.underReview => AppColors.info,
      VerificationStatus.submitted => AppColors.pending,
      VerificationStatus.declined => AppColors.danger,
    };
    return StatusChip(label: status.label, color: color, dense: dense);
  }

  final String label;
  final Color color;
  final IconData? icon;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 8 : 10,
        vertical: dense ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 12 : 14, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: dense ? 11 : 12,
            ),
          ),
        ],
      ),
    );
  }
}

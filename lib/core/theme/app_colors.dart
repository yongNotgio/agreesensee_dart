import 'package:flutter/material.dart';

/// AgriSense palette — an agricultural green seed with high-contrast accents
/// tuned for outdoor readability on low-to-mid-tier devices.
class AppColors {
  const AppColors._();

  static const Color seed = Color(0xFF2E7D32); // forest green
  static const Color primary = Color(0xFF2E7D32);
  static const Color secondary = Color(0xFF00796B); // teal
  static const Color tertiary = Color(0xFFF9A825); // harvest gold

  // Saturation / risk signal colors.
  static const Color riskLow = Color(0xFF2E7D32);
  static const Color riskModerate = Color(0xFFF9A825);
  static const Color riskHigh = Color(0xFFC62828);

  // Status signal colors.
  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFEF6C00);
  static const Color danger = Color(0xFFC62828);
  static const Color info = Color(0xFF1565C0);
  static const Color pending = Color(0xFF6A4C93);

  static const Color surfaceTint = Color(0xFFF1F8E9);
}

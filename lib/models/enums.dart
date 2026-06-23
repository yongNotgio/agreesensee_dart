/// Domain enumerations shared across models, repositories, and UI.
///
/// Every enum is paired with `wire` (the snake_case value persisted to
/// Postgres / Supabase) and a `fromWire` parser so serialization stays in one
/// place and survives unknown/legacy values gracefully.
library;

import 'package:flutter/material.dart';

/// Application roles. The mobile client surfaces the Farmer and Cooperative
/// portals; MAO/admin roles authenticate into the web dashboard but are still
/// modeled here so role routing degrades gracefully.
enum UserRole {
  farmer('farmer', 'Farmer'),
  cooperative('cooperative', 'Cooperative'),
  mao('mao', 'MAO Administrator'),
  technician('technician', 'Agricultural Technician'),
  baw('baw', 'Barangay Agricultural Worker');

  const UserRole(this.wire, this.label);
  final String wire;
  final String label;

  static UserRole fromWire(String? value) => UserRole.values.firstWhere(
        (r) => r.wire == value,
        orElse: () => UserRole.farmer,
      );
}

/// Lifecycle of a crop declaration as it moves through the validation chain
/// (BAW → Technician → MAO) described in the workflow.
enum DeclarationStatus {
  draft('draft', 'Draft', Icons.edit_note),
  pending('pending', 'Pending Validation', Icons.hourglass_top),
  bawApproved('baw_approved', 'BAW Approved', Icons.verified_user),
  technicianVerified(
      'technician_verified', 'Technician Verified', Icons.fact_check),
  approved('approved', 'MAO Approved', Icons.check_circle),
  correctionRequested(
      'correction_requested', 'Correction Requested', Icons.report_problem),
  rejected('rejected', 'Rejected', Icons.cancel),
  harvested('harvested', 'Harvested', Icons.agriculture);

  const DeclarationStatus(this.wire, this.label, this.icon);
  final String wire;
  final String label;
  final IconData icon;

  static DeclarationStatus fromWire(String? value) =>
      DeclarationStatus.values.firstWhere(
        (s) => s.wire == value,
        orElse: () => DeclarationStatus.pending,
      );

  bool get isActive =>
      this != DeclarationStatus.rejected &&
      this != DeclarationStatus.harvested &&
      this != DeclarationStatus.draft;
}

/// Market Saturation Index banding (Phase 5 of the workflow).
enum SaturationLevel {
  low('low', 'Low Risk'),
  moderate('moderate', 'Moderate Risk'),
  high('high', 'High Risk');

  const SaturationLevel(this.wire, this.label);
  final String wire;
  final String label;

  static SaturationLevel fromWire(String? value) =>
      SaturationLevel.values.firstWhere(
        (s) => s.wire == value,
        orElse: () => SaturationLevel.moderate,
      );
}

/// Categories of farm expenses captured for the P&L / ROI ledger (Phase 7).
enum ExpenseCategory {
  seed('seed', 'Seeds & Planting Material', Icons.spa),
  fertilizer('fertilizer', 'Fertilizer', Icons.science),
  labor('labor', 'Labor', Icons.groups),
  irrigation('irrigation', 'Irrigation', Icons.water_drop),
  transport('transport', 'Transportation', Icons.local_shipping),
  pesticide('pesticide', 'Pesticide / Protection', Icons.pest_control),
  equipment('equipment', 'Equipment & Rental', Icons.agriculture),
  other('other', 'Other', Icons.receipt_long);

  const ExpenseCategory(this.wire, this.label, this.icon);
  final String wire;
  final String label;
  final IconData icon;

  static ExpenseCategory fromWire(String? value) =>
      ExpenseCategory.values.firstWhere(
        (c) => c.wire == value,
        orElse: () => ExpenseCategory.other,
      );
}

/// Calamity types for the incident reporting mechanism (Phase: digital logbook
/// & incident reporting / subsidy verification).
enum CalamityType {
  typhoon('typhoon', 'Typhoon', Icons.cyclone),
  flood('flood', 'Flooding', Icons.flood),
  drought('drought', 'Drought', Icons.wb_sunny),
  pest('pest', 'Pest Infestation', Icons.bug_report),
  disease('disease', 'Crop Disease', Icons.coronavirus),
  landslide('landslide', 'Landslide', Icons.terrain),
  other('other', 'Other', Icons.warning_amber);

  const CalamityType(this.wire, this.label, this.icon);
  final String wire;
  final String label;
  final IconData icon;

  static CalamityType fromWire(String? value) =>
      CalamityType.values.firstWhere(
        (c) => c.wire == value,
        orElse: () => CalamityType.other,
      );
}

/// Verification status of a calamity report used by the MAO for subsidy
/// allocation.
enum VerificationStatus {
  submitted('submitted', 'Submitted'),
  underReview('under_review', 'Under Review'),
  verified('verified', 'Verified'),
  endorsed('endorsed', 'Endorsed for Subsidy'),
  declined('declined', 'Declined');

  const VerificationStatus(this.wire, this.label);
  final String wire;
  final String label;

  static VerificationStatus fromWire(String? value) =>
      VerificationStatus.values.firstWhere(
        (s) => s.wire == value,
        orElse: () => VerificationStatus.submitted,
      );
}

/// Logbook activity classifications (Phase: digital agronomic logbook).
enum ActivityType {
  landPrep('land_prep', 'Land Preparation', Icons.landscape),
  planting('planting', 'Planting / Sowing', Icons.grass),
  fertilizing('fertilizing', 'Fertilizer Application', Icons.science),
  irrigation('irrigation', 'Irrigation', Icons.water_drop),
  weeding('weeding', 'Weeding', Icons.cleaning_services),
  pestControl('pest_control', 'Pest / Disease Control', Icons.pest_control),
  scouting('scouting', 'Field Scouting', Icons.search),
  harvesting('harvesting', 'Harvesting', Icons.agriculture),
  other('other', 'Other', Icons.notes);

  const ActivityType(this.wire, this.label, this.icon);
  final String wire;
  final String label;
  final IconData icon;

  static ActivityType fromWire(String? value) =>
      ActivityType.values.firstWhere(
        (a) => a.wire == value,
        orElse: () => ActivityType.other,
      );
}

/// The two growing seasons used by the recommendation engine for seasonal
/// suitability scoring.
enum Season {
  dry('dry', 'Dry Season'),
  wet('wet', 'Wet Season');

  const Season(this.wire, this.label);
  final String wire;
  final String label;

  static Season fromWire(String? value) => Season.values.firstWhere(
        (s) => s.wire == value,
        orElse: () => Season.dry,
      );

  /// In Iloilo the dry season runs roughly November–April, wet May–October.
  static Season forMonth(int month) =>
      (month >= 11 || month <= 4) ? Season.dry : Season.wet;
}

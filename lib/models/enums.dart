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

/// Lifecycle of a crop declaration.
///
/// A declaration is a **record of intent, not an application**. The MAO has no
/// authority to approve or deny what a farmer plants on their own land, so the
/// former BAW → Technician → MAO approval chain was removed: AgriSense advises
/// before planting and records afterwards. Legacy approval states still parse
/// (see [fromWire]) so rows written under the old model keep working.
enum DeclarationStatus {
  active('active', 'Growing', Icons.eco),
  harvested('harvested', 'Harvested', Icons.agriculture),
  cancelled('cancelled', 'Cancelled', Icons.cancel);

  const DeclarationStatus(this.wire, this.label, this.icon);
  final String wire;
  final String label;
  final IconData icon;

  /// Retired approval-chain values, mapped onto the surviving states so
  /// previously-persisted declarations still load.
  static const Map<String, DeclarationStatus> _legacy = {
    'draft': DeclarationStatus.active,
    'pending': DeclarationStatus.active,
    'baw_approved': DeclarationStatus.active,
    'technician_verified': DeclarationStatus.active,
    'approved': DeclarationStatus.active,
    'correction_requested': DeclarationStatus.active,
    'rejected': DeclarationStatus.cancelled,
  };

  static DeclarationStatus fromWire(String? value) {
    for (final s in DeclarationStatus.values) {
      if (s.wire == value) return s;
    }
    return _legacy[value] ?? DeclarationStatus.active;
  }

  /// Counts toward projected supply — i.e. still standing in the field.
  bool get isActive => this == DeclarationStatus.active;
}

/// Land-suitability banding for a crop in a given barangay.
///
/// Bands are expressed on the **yield index**: observed yield as a share of the
/// crop's attainable yield in the pilot area. Thresholds follow the adviser's
/// brief (50 % / 70 % / 80 %) and are named constants so a single edit re-bands
/// the whole app if the definition changes.
enum SuitabilityBand {
  marginal('marginal', 'Marginally Suitable'),
  moderate('moderate', 'Moderately Suitable'),
  suitable('suitable', 'Suitable'),
  verySuitable('very_suitable', 'Very Suitable');

  const SuitabilityBand(this.wire, this.label);
  final String wire;
  final String label;

  static const double moderateFloor = 0.50;
  static const double suitableFloor = 0.70;
  static const double verySuitableFloor = 0.80;

  static SuitabilityBand forIndex(double index) {
    if (index >= verySuitableFloor) return SuitabilityBand.verySuitable;
    if (index >= suitableFloor) return SuitabilityBand.suitable;
    if (index >= moderateFloor) return SuitabilityBand.moderate;
    return SuitabilityBand.marginal;
  }

  static SuitabilityBand fromWire(String? value) =>
      SuitabilityBand.values.firstWhere(
        (b) => b.wire == value,
        orElse: () => SuitabilityBand.moderate,
      );
}

/// Where the demand figure behind a Market Saturation Index came from. Shown in
/// the UI so the number is defensible rather than anonymous.
enum DemandSource {
  cooperative('cooperative', 'Declared by cooperatives'),
  baseline('baseline', 'Municipal monthly baseline'),
  catalog('catalog', 'Catalog fallback');

  const DemandSource(this.wire, this.label);
  final String wire;
  final String label;
}

/// Lifecycle of a system-scheduled farm operation on the crop calendar.
enum PlannedActivityStatus {
  pending('pending', 'Scheduled'),
  done('done', 'Done'),
  skipped('skipped', 'Skipped');

  const PlannedActivityStatus(this.wire, this.label);
  final String wire;
  final String label;

  static PlannedActivityStatus fromWire(String? value) =>
      PlannedActivityStatus.values.firstWhere(
        (s) => s.wire == value,
        orElse: () => PlannedActivityStatus.pending,
      );
}

/// Buyer categories a cooperative declares demand against.
enum BuyerType {
  bagsakan('bagsakan', 'Bagsakan / Trading Post'),
  institutional('institutional', 'Institutional Buyer'),
  processor('processor', 'Processor / Agri-business'),
  trader('trader', 'Trader / Consolidator'),
  retail('retail', 'Public Market / Retail');

  const BuyerType(this.wire, this.label);
  final String wire;
  final String label;

  static BuyerType fromWire(String? value) => BuyerType.values.firstWhere(
        (b) => b.wire == value,
        orElse: () => BuyerType.bagsakan,
      );
}

/// Where a harvest was actually sold. Captured on the production report so the
/// MAO web portal can trace supply that never reached the bagsakan — the
/// "diin nagkadto ang supply" question.
enum SalesChannel {
  bagsakan('bagsakan', 'Bagsakan / Trading Post'),
  cooperative('cooperative', 'Cooperative Buy-back'),
  trader('trader', 'Trader / Consolidator'),
  directMarket('direct_market', 'Direct to Market / Consumer'),
  neighbouringMunicipality(
      'neighbouring_municipality', 'Buyer from Another Municipality'),
  ownConsumption('own_consumption', 'Own Consumption / Not Sold'),
  other('other', 'Other');

  const SalesChannel(this.wire, this.label);
  final String wire;
  final String label;

  static SalesChannel fromWire(String? value) => SalesChannel.values.firstWhere(
        (c) => c.wire == value,
        orElse: () => SalesChannel.other,
      );

  /// Channels that move produce out of the municipality's monitored supply.
  bool get leavesMunicipality =>
      this == SalesChannel.neighbouringMunicipality ||
      this == SalesChannel.trader;
}

/// Residency / identity verification state of an account. Farmers register with
/// an RSBSA number and barangay; a cooperative officer or technician confirms
/// them against the MAO roster.
enum AccountVerification {
  unverified('unverified', 'Unverified', Icons.gpp_maybe),
  pending('pending', 'Pending Verification', Icons.hourglass_top),
  verified('verified', 'Verified Resident', Icons.verified),
  rejected('rejected', 'Verification Rejected', Icons.gpp_bad);

  const AccountVerification(this.wire, this.label, this.icon);
  final String wire;
  final String label;
  final IconData icon;

  static AccountVerification fromWire(String? value) =>
      AccountVerification.values.firstWhere(
        (v) => v.wire == value,
        orElse: () => AccountVerification.unverified,
      );
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

  /// The expense category a cost incurred by this activity naturally falls
  /// under. Pre-selects the category when a farmer attaches a cost to a logged
  /// activity, so the usual case is "type the amount and save".
  ExpenseCategory get defaultExpenseCategory => switch (this) {
        ActivityType.landPrep => ExpenseCategory.labor,
        ActivityType.planting => ExpenseCategory.seed,
        ActivityType.fertilizing => ExpenseCategory.fertilizer,
        ActivityType.irrigation => ExpenseCategory.irrigation,
        ActivityType.weeding => ExpenseCategory.labor,
        ActivityType.pestControl => ExpenseCategory.pesticide,
        ActivityType.scouting => ExpenseCategory.other,
        ActivityType.harvesting => ExpenseCategory.labor,
        ActivityType.other => ExpenseCategory.other,
      };
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

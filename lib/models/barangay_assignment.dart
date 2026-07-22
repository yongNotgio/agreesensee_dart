import 'package:equatable/equatable.dart';

import '../core/utils/parsing.dart';
import 'enums.dart';

/// Assignment of an agricultural technician or barangay agricultural worker to
/// a barangay (Supabase `barangay_assignments` table).
///
/// With declarations no longer passing through an approval chain, the
/// technician's role is **advisory support, not gatekeeping**: the farmer needs
/// to know who to call about their crop, and this is what surfaces that contact
/// on their dashboard.
class BarangayAssignment extends Equatable {
  const BarangayAssignment({
    required this.id,
    required this.barangay,
    required this.technicianId,
    required this.role,
    this.technicianName,
    this.contactNumber,
    this.assignedAt,
  });

  final String id;
  final String barangay;

  /// Profile id of the assigned technician or BAW.
  final String technicianId;
  final UserRole role;

  /// Denormalized for display so the dashboard needs one read, not two.
  final String? technicianName;
  final String? contactNumber;
  final DateTime? assignedAt;

  factory BarangayAssignment.fromMap(Map<String, dynamic> map) =>
      BarangayAssignment(
        id: asString(map['id']),
        barangay: asString(map['barangay']),
        technicianId: asString(map['technician_id']),
        role: UserRole.fromWire(asStringOrNull(map['role'])),
        technicianName: asStringOrNull(map['technician_name']),
        contactNumber: asStringOrNull(map['contact_number']),
        assignedAt: asDate(map['assigned_at']),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'barangay': barangay,
        'technician_id': technicianId,
        'role': role.wire,
        'technician_name': technicianName,
        'contact_number': contactNumber,
        'assigned_at': dateToWire(assignedAt),
      };

  String get displayName => technicianName ?? role.label;

  @override
  List<Object?> get props =>
      [id, barangay, technicianId, role, technicianName, contactNumber];
}

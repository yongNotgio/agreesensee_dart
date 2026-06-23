import 'package:equatable/equatable.dart';

import '../core/utils/parsing.dart';
import 'enums.dart';

/// A user account profile (Supabase `profiles` table, 1:1 with `auth.users`).
class Profile extends Equatable {
  const Profile({
    required this.id,
    required this.fullName,
    required this.role,
    this.email,
    this.contactNumber,
    this.barangay,
    this.cooperativeId,
    this.avatarUrl,
    this.createdAt,
  });

  final String id;
  final String fullName;
  final UserRole role;
  final String? email;
  final String? contactNumber;
  final String? barangay;

  /// For farmers: the cooperative they belong to. For a cooperative account:
  /// the cooperative they administer.
  final String? cooperativeId;
  final String? avatarUrl;
  final DateTime? createdAt;

  factory Profile.fromMap(Map<String, dynamic> map) => Profile(
        id: asString(map['id']),
        fullName: asString(map['full_name'], 'AgriSense User'),
        role: UserRole.fromWire(asStringOrNull(map['role'])),
        email: asStringOrNull(map['email']),
        contactNumber: asStringOrNull(map['contact_number']),
        barangay: asStringOrNull(map['barangay']),
        cooperativeId: asStringOrNull(map['cooperative_id']),
        avatarUrl: asStringOrNull(map['avatar_url']),
        createdAt: asDate(map['created_at']),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'full_name': fullName,
        'role': role.wire,
        'email': email,
        'contact_number': contactNumber,
        'barangay': barangay,
        'cooperative_id': cooperativeId,
        'avatar_url': avatarUrl,
        'created_at': dateToWire(createdAt),
      };

  Profile copyWith({
    String? fullName,
    UserRole? role,
    String? email,
    String? contactNumber,
    String? barangay,
    String? cooperativeId,
    String? avatarUrl,
  }) =>
      Profile(
        id: id,
        fullName: fullName ?? this.fullName,
        role: role ?? this.role,
        email: email ?? this.email,
        contactNumber: contactNumber ?? this.contactNumber,
        barangay: barangay ?? this.barangay,
        cooperativeId: cooperativeId ?? this.cooperativeId,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        createdAt: createdAt,
      );

  String get initials {
    final parts =
        fullName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'A';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  @override
  List<Object?> get props => [
        id,
        fullName,
        role,
        email,
        contactNumber,
        barangay,
        cooperativeId,
        avatarUrl,
      ];
}

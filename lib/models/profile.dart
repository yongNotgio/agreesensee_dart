import 'package:equatable/equatable.dart';

import '../core/utils/parsing.dart';
import 'enums.dart';

/// A user account profile (Supabase `profiles` table).
///
/// The name is stored as discrete parts rather than one free-text field so it
/// can be matched against the MAO's RSBSA roster during residency verification,
/// and sorted/searched properly in the cooperative portal.
class Profile extends Equatable {
  const Profile({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.role,
    this.middleName,
    this.username,
    this.email,
    this.contactNumber,
    this.barangay,
    this.cooperativeId,
    this.avatarUrl,
    this.rsbsaNumber,
    this.verification = AccountVerification.unverified,
    this.verifiedBy,
    this.verifiedAt,
    this.createdAt,
  });

  final String id;
  final String firstName;
  final String lastName;
  final String? middleName;

  /// Unique handle shown on the dashboard and used for sign-in.
  final String? username;

  final UserRole role;
  final String? email;
  final String? contactNumber;
  final String? barangay;

  /// For farmers: the cooperative they belong to. For a cooperative account:
  /// the cooperative they administer.
  final String? cooperativeId;
  final String? avatarUrl;

  /// Registry System for Basic Sectors in Agriculture number — the national
  /// farmer registry ID the MAO holds a roster of. This is what proves the
  /// account belongs to a Tubungan farmer.
  final String? rsbsaNumber;

  final AccountVerification verification;

  /// Profile id of the cooperative officer or technician who confirmed the
  /// account against the roster.
  final String? verifiedBy;
  final DateTime? verifiedAt;
  final DateTime? createdAt;

  factory Profile.fromMap(Map<String, dynamic> map) {
    // Tolerate rows written before the name was split: fall back to splitting
    // the legacy `full_name` on its last whitespace.
    var first = asStringOrNull(map['first_name']);
    var last = asStringOrNull(map['last_name']);
    if ((first == null || first.isEmpty) && (last == null || last.isEmpty)) {
      final legacy = asString(map['full_name'], 'AgriSense User').trim();
      final parts = legacy.split(RegExp(r'\s+'));
      if (parts.length == 1) {
        first = parts.first;
        last = '';
      } else {
        first = parts.sublist(0, parts.length - 1).join(' ');
        last = parts.last;
      }
    }
    return Profile(
      id: asString(map['id']),
      firstName: first ?? '',
      lastName: last ?? '',
      middleName: asStringOrNull(map['middle_name']),
      username: asStringOrNull(map['username']),
      role: UserRole.fromWire(asStringOrNull(map['role'])),
      email: asStringOrNull(map['email']),
      contactNumber: asStringOrNull(map['contact_number']),
      barangay: asStringOrNull(map['barangay']),
      cooperativeId: asStringOrNull(map['cooperative_id']),
      avatarUrl: asStringOrNull(map['avatar_url']),
      rsbsaNumber: asStringOrNull(map['rsbsa_number']),
      verification:
          AccountVerification.fromWire(asStringOrNull(map['verification'])),
      verifiedBy: asStringOrNull(map['verified_by']),
      verifiedAt: asDate(map['verified_at']),
      createdAt: asDate(map['created_at']),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'first_name': firstName,
        'last_name': lastName,
        'middle_name': middleName,
        'username': username,
        'role': role.wire,
        'email': email,
        'contact_number': contactNumber,
        'barangay': barangay,
        'cooperative_id': cooperativeId,
        'avatar_url': avatarUrl,
        'rsbsa_number': rsbsaNumber,
        'verification': verification.wire,
        'verified_by': verifiedBy,
        'verified_at': dateToWire(verifiedAt),
        'created_at': dateToWire(createdAt),
      };

  Profile copyWith({
    String? firstName,
    String? lastName,
    String? middleName,
    String? username,
    UserRole? role,
    String? email,
    String? contactNumber,
    String? barangay,
    String? cooperativeId,
    String? avatarUrl,
    String? rsbsaNumber,
    AccountVerification? verification,
    String? verifiedBy,
    DateTime? verifiedAt,
  }) =>
      Profile(
        id: id,
        firstName: firstName ?? this.firstName,
        lastName: lastName ?? this.lastName,
        middleName: middleName ?? this.middleName,
        username: username ?? this.username,
        role: role ?? this.role,
        email: email ?? this.email,
        contactNumber: contactNumber ?? this.contactNumber,
        barangay: barangay ?? this.barangay,
        cooperativeId: cooperativeId ?? this.cooperativeId,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        rsbsaNumber: rsbsaNumber ?? this.rsbsaNumber,
        verification: verification ?? this.verification,
        verifiedBy: verifiedBy ?? this.verifiedBy,
        verifiedAt: verifiedAt ?? this.verifiedAt,
        createdAt: createdAt,
      );

  /// Display name — "Juan Dela Cruz".
  String get fullName =>
      [firstName, lastName].where((p) => p.trim().isNotEmpty).join(' ').trim();

  /// Formal name including the middle initial — "Dela Cruz, Juan M."
  String get formalName {
    final mi = (middleName ?? '').trim().isEmpty
        ? ''
        : ' ${middleName!.trim()[0].toUpperCase()}.';
    if (lastName.trim().isEmpty) return '$firstName$mi';
    return '$lastName, $firstName$mi';
  }

  /// The handle shown on the dashboard, falling back to a name-derived one.
  String get displayHandle =>
      username ?? '@${fullName.toLowerCase().replaceAll(RegExp(r'\s+'), '.')}';

  bool get isVerified => verification == AccountVerification.verified;

  String get initials {
    final f = firstName.trim();
    final l = lastName.trim();
    if (f.isEmpty && l.isEmpty) return 'A';
    if (l.isEmpty) return f.substring(0, 1).toUpperCase();
    if (f.isEmpty) return l.substring(0, 1).toUpperCase();
    return (f.substring(0, 1) + l.substring(0, 1)).toUpperCase();
  }

  @override
  List<Object?> get props => [
        id,
        firstName,
        lastName,
        middleName,
        username,
        role,
        email,
        contactNumber,
        barangay,
        cooperativeId,
        avatarUrl,
        rsbsaNumber,
        verification,
      ];
}

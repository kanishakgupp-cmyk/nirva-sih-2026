enum ProfileRole {
  officer('OFFICER'),
  supervisor('SUPERVISOR'),
  admin('ADMIN');

  const ProfileRole(this.value);

  final String value;

  static ProfileRole fromValue(String? value) {
    return ProfileRole.values.firstWhere(
      (role) => role.value == value,
      orElse: () => ProfileRole.officer,
    );
  }
}

class Profile {
  const Profile({
    required this.id,
    required this.displayName,
    required this.role,
  });

  final String id;
  final String displayName;
  final ProfileRole role;

  factory Profile.fromMap(Map<String, dynamic> map) {
    return Profile(
      id: map['id'] as String,
      displayName: (map['display_name'] as String?) ?? 'NIRVA Officer',
      role: ProfileRole.fromValue(map['role'] as String?),
    );
  }
}

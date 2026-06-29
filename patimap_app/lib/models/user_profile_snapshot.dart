/// Profil ekranında gösterilen özet (auth + isteğe bağlı `profiles` satırı).
final class UserProfileSnapshot {
  const UserProfileSnapshot({
    required this.displayName,
    required this.email,
    required this.userId,
    this.firstName,
    this.lastName,
    this.roleLabel,
    this.accountCreatedAt,
    this.hasProfileRow = false,
    this.avatarUrl,
  });

  final String displayName;
  final String email;
  final String userId;
  final String? firstName;
  final String? lastName;
  /// `profiles.avatar_url` veya auth metadata.
  final String? avatarUrl;
  final String? roleLabel;
  final DateTime? accountCreatedAt;
  final bool hasProfileRow;

  String get fullName => '${firstName ?? ''} ${lastName ?? ''}'.trim();

  static UserProfileSnapshot fallbackEmail(String email) {
    return UserProfileSnapshot(
      displayName: email,
      email: email,
      userId: '',
      avatarUrl: null,
    );
  }
}

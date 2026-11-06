/// Representation of the authenticated MailMind user
class AppUser {
  final String email;
  final String? displayName;
  final String? photoUrl;
  final String? accessToken;
  final String? idToken;

  const AppUser({
    required this.email,
    this.displayName,
    this.photoUrl,
    this.accessToken,
    this.idToken,
  });

  Map<String, dynamic> toMap() => {
        'email': email,
        'displayName': displayName,
        'photoUrl': photoUrl,
      };

  factory AppUser.fromMap(Map<String, dynamic> map) => AppUser(
        email: map['email'] as String,
        displayName: map['displayName'] as String?,
        photoUrl: map['photoUrl'] as String?,
      );
}


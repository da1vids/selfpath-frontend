class UserModel {
  final String id;
  final String? username; // ✅ make nullable
  final String? profilePicture;
  final int credits;
  final String? role;

  UserModel({
    required this.id,
    this.username,
    this.profilePicture,
    this.credits = 0,
    this.role,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      username: json['username'], // now safe if null
      profilePicture: json['profile_picture'],
      credits: json['credits'] ?? 0,
      role: json['role'],
    );
  }
}

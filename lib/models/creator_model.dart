class Creator {
  final String id;
  final String name;
  final String username;
  final String? bio;
  final String? profilePicture;
  final int followersCount;
  final bool followed;
  final List<String> tags;

  Creator({
    required this.id,
    required this.name,
    required this.username,
    this.bio,
    this.profilePicture,
    required this.followersCount,
    required this.followed,
    required this.tags,
  });

  factory Creator.fromJson(Map<String, dynamic> json) {
    return Creator(
      id: json['id'],
      name: json['name'],
      username: json['username'],
      bio: json['bio'],
      profilePicture: json['profile_picture'],
      followersCount: json['followers_count'] ?? 0,
      followed: json['followed'] ?? false,
      tags: List<String>.from(json['tags'] ?? []),
    );
  }

  Creator copyWith({
    String? id,
    String? name,
    String? username,
    String? bio,
    String? profilePicture,
    int? followersCount,
    bool? followed,
    List<String>? tags,
  }) {
    return Creator(
      id: id ?? this.id,
      name: name ?? this.name,
      username: username ?? this.username,
      bio: bio ?? this.bio,
      profilePicture: profilePicture ?? this.profilePicture,
      followersCount: followersCount ?? this.followersCount,
      followed: followed ?? this.followed,
      tags: tags ?? this.tags,
    );
  }
}

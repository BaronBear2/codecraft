class UserProgress {
  final int highestLevel;
  final int totalAttempt;
  final int totalTimeSpent;
  final String? photoUrl; 

  UserProgress({
    required this.highestLevel,
    required this.totalAttempt,
    required this.totalTimeSpent,
    this.photoUrl,
  });

  factory UserProgress.fromMap(Map<String, dynamic> data) {
    return UserProgress(
      highestLevel: data['highestLevel'] ?? 1,
      totalAttempt: data['totalAttempt'] ?? 0,
      totalTimeSpent: data['totalTimeSpent'] ?? 0,
      photoUrl: data['photoUrl'], 
    );
  }
}
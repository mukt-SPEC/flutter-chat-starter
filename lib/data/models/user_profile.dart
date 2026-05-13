import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserProfile {
  final String uid;
  final String email;
  final String displayName;
  final String? photoUrl;
  final Timestamp? createdAt;
  final Timestamp? lastSeenAt;

  const UserProfile({
    required this.uid,
    required this.email,
    required this.displayName,
    this.photoUrl,
    this.createdAt,
    this.lastSeenAt,
  });

  factory UserProfile.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return UserProfile(
      uid: (data['uid'] as String?) ?? doc.id,
      email: (data['email'] as String?) ?? '',
      displayName: (data['displayName'] as String?) ?? '',
      photoUrl: data['photoUrl'] as String?,
      createdAt: data['createdAt'] as Timestamp?,
      lastSeenAt: data['lastSeenAt'] as Timestamp?,
    );
  }

  factory UserProfile.fromFirebaseUser(User user) {
    final email = user.email ?? '';
    final fallbackDisplayName = email.contains('@') ? email.split('@').first : '';
    return UserProfile(
      uid: user.uid,
      email: email,
      displayName: (user.displayName ?? '').trim().isEmpty
          ? fallbackDisplayName
          : user.displayName!.trim(),
      photoUrl: user.photoURL,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'createdAt': createdAt,
      'lastSeenAt': lastSeenAt,
    };
  }
}

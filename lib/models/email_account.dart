class EmailAccount {
  final String id;
  final String provider; // 'gmail', 'outlook', etc.
  final String email;
  final String displayName;
  final String? photoUrl;
  final DateTime connectedAt;
  final DateTime? lastSyncedAt;
  final bool isActive;
  final int emailsProcessed;

  const EmailAccount({
    required this.id,
    required this.provider,
    required this.email,
    required this.displayName,
    this.photoUrl,
    required this.connectedAt,
    this.lastSyncedAt,
    this.isActive = true,
    this.emailsProcessed = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'provider': provider,
      'email': email,
      'display_name': displayName,
      'photo_url': photoUrl,
      'connected_at': connectedAt.toIso8601String(),
      'last_synced_at': lastSyncedAt?.toIso8601String(),
      'is_active': isActive ? 1 : 0,
      'emails_processed': emailsProcessed,
    };
  }

  factory EmailAccount.fromMap(Map<String, dynamic> map) {
    return EmailAccount(
      id: map['id'] as String,
      provider: map['provider'] as String,
      email: map['email'] as String,
      displayName: map['display_name'] as String,
      photoUrl: map['photo_url'] as String?,
      connectedAt: DateTime.parse(map['connected_at'] as String),
      lastSyncedAt: map['last_synced_at'] != null
          ? DateTime.parse(map['last_synced_at'] as String)
          : null,
      isActive: (map['is_active'] as int) == 1,
      emailsProcessed: (map['emails_processed'] as int?) ?? 0,
    );
  }

  EmailAccount copyWith({
    String? id,
    String? provider,
    String? email,
    String? displayName,
    String? photoUrl,
    DateTime? connectedAt,
    DateTime? lastSyncedAt,
    bool? isActive,
    int? emailsProcessed,
  }) {
    return EmailAccount(
      id: id ?? this.id,
      provider: provider ?? this.provider,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      connectedAt: connectedAt ?? this.connectedAt,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      isActive: isActive ?? this.isActive,
      emailsProcessed: emailsProcessed ?? this.emailsProcessed,
    );
  }
}

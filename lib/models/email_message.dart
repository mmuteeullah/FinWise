class EmailMessage {
  final String id; // Gmail message ID
  final String accountId; // Foreign key to email_accounts
  final String from;
  final String fromName;
  final String subject;
  final String? snippet; // Preview text
  final String? textBody;
  final String? htmlBody;
  final DateTime receivedAt;
  final bool isProcessed;
  final bool isTransactional; // Flagged as financial/transactional
  final String? transactionId; // If converted to transaction
  final String? labels; // JSON array of labels
  final DateTime createdAt;

  const EmailMessage({
    required this.id,
    required this.accountId,
    required this.from,
    required this.fromName,
    required this.subject,
    this.snippet,
    this.textBody,
    this.htmlBody,
    required this.receivedAt,
    this.isProcessed = false,
    this.isTransactional = false,
    this.transactionId,
    this.labels,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'account_id': accountId,
      'from_email': from,
      'from_name': fromName,
      'subject': subject,
      'snippet': snippet,
      'text_body': textBody,
      'html_body': htmlBody,
      'received_at': receivedAt.toIso8601String(),
      'is_processed': isProcessed ? 1 : 0,
      'is_transactional': isTransactional ? 1 : 0,
      'transaction_id': transactionId,
      'labels': labels,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory EmailMessage.fromMap(Map<String, dynamic> map) {
    return EmailMessage(
      id: map['id'] as String,
      accountId: map['account_id'] as String,
      from: map['from_email'] as String,
      fromName: map['from_name'] as String,
      subject: map['subject'] as String,
      snippet: map['snippet'] as String?,
      textBody: map['text_body'] as String?,
      htmlBody: map['html_body'] as String?,
      receivedAt: DateTime.parse(map['received_at'] as String),
      isProcessed: (map['is_processed'] as int) == 1,
      isTransactional: (map['is_transactional'] as int) == 1,
      transactionId: map['transaction_id'] as String?,
      labels: map['labels'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  EmailMessage copyWith({
    String? id,
    String? accountId,
    String? from,
    String? fromName,
    String? subject,
    String? snippet,
    String? textBody,
    String? htmlBody,
    DateTime? receivedAt,
    bool? isProcessed,
    bool? isTransactional,
    String? transactionId,
    String? labels,
    DateTime? createdAt,
  }) {
    return EmailMessage(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      from: from ?? this.from,
      fromName: fromName ?? this.fromName,
      subject: subject ?? this.subject,
      snippet: snippet ?? this.snippet,
      textBody: textBody ?? this.textBody,
      htmlBody: htmlBody ?? this.htmlBody,
      receivedAt: receivedAt ?? this.receivedAt,
      isProcessed: isProcessed ?? this.isProcessed,
      isTransactional: isTransactional ?? this.isTransactional,
      transactionId: transactionId ?? this.transactionId,
      labels: labels ?? this.labels,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

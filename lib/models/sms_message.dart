class SmsMessage {
  final String id;
  final String text;
  final String sender;
  final String receivedAt;

  SmsMessage({
    required this.id,
    required this.text,
    required this.sender,
    required this.receivedAt,
  });

  factory SmsMessage.fromMap(Map<dynamic, dynamic> map) {
    return SmsMessage(
      id: map['id'] as String,
      text: map['text'] as String,
      sender: map['sender'] as String,
      receivedAt: map['receivedAt'] as String,
    );
  }
}

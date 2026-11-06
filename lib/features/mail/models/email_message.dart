class EmailMessage {
  const EmailMessage({
    required this.id,
    required this.threadId,
    required this.from,
    required this.subject,
    required this.date,
    required this.body,
  });

  final String id;
  final String threadId;
  final String from;
  final String subject;
  final DateTime date;
  final String body;
}

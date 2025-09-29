class Message {
  final String id;
  final String text;
  final bool isUser;
  final Map<String, dynamic>? data;

  Message({
    required this.id,
    required this.text,
    required this.isUser,
    this.data,
  });
}
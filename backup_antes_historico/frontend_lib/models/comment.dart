import 'user.dart';

class TicketCommentModel {
  final int id;
  final int ticketId;
  final String content;
  final DateTime createdAt;
  final User? author;

  const TicketCommentModel({
    required this.id,
    required this.ticketId,
    required this.content,
    required this.createdAt,
    this.author,
  });

  factory TicketCommentModel.fromJson(Map<String, dynamic> json) => TicketCommentModel(
        id: json['id'],
        ticketId: json['ticket_id'],
        content: json['content'],
        createdAt: DateTime.parse(json['created_at']),
        author: json['author'] != null ? User.fromJson(json['author']) : null,
      );
}

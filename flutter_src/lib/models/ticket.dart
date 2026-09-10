import 'user.dart';

class Ticket {
  final int id;
  final String title;
  final String description;
  final String category;
  final String priority;
  final String status;
  final int creatorId;
  final int? assigneeId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final User? creator;
  final User? assignee;

  const Ticket({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.priority,
    required this.status,
    required this.creatorId,
    required this.assigneeId,
    required this.createdAt,
    required this.updatedAt,
    this.creator,
    this.assignee,
  });

  factory Ticket.fromJson(Map<String, dynamic> json) => Ticket(
        id: json['id'],
        title: json['title'],
        description: json['description'],
        category: json['category'],
        priority: json['priority'],
        status: json['status'],
        creatorId: json['creator_id'],
        assigneeId: json['assignee_id'],
        createdAt: DateTime.parse(json['created_at']),
        updatedAt: DateTime.parse(json['updated_at']),
        creator: json['creator'] != null ? User.fromJson(json['creator']) : null,
        assignee: json['assignee'] != null ? User.fromJson(json['assignee']) : null,
      );
}

class TicketPage {
  final List<Ticket> items;
  final int total;
  final int skip;
  final int limit;

  const TicketPage({required this.items, required this.total, required this.skip, required this.limit});

  factory TicketPage.fromJson(Map<String, dynamic> json) => TicketPage(
        items: (json['items'] as List).map((e) => Ticket.fromJson(e)).toList(),
        total: json['total'],
        skip: json['skip'],
        limit: json['limit'],
      );
}

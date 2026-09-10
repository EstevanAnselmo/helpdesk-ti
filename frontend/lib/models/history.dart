import 'user.dart';

class TicketHistoryModel {
  final int id;
  final int ticketId;
  final int actorId;
  final String action;
  final String? oldValue;
  final String? newValue;
  final DateTime createdAt;
  final User? actor;

  const TicketHistoryModel({
    required this.id,
    required this.ticketId,
    required this.actorId,
    required this.action,
    required this.oldValue,
    required this.newValue,
    required this.createdAt,
    this.actor,
  });

  factory TicketHistoryModel.fromJson(Map<String, dynamic> json) {
    return TicketHistoryModel(
      id: json['id'],
      ticketId: json['ticket_id'],
      actorId: json['actor_id'],
      action: json['action'],
      oldValue: json['old_value'],
      newValue: json['new_value'],
      createdAt: DateTime.parse(json['created_at']),
      actor: json['actor'] != null ? User.fromJson(json['actor']) : null,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/ticket.dart';

class TicketTile extends StatelessWidget {
  final Ticket ticket;
  final VoidCallback? onTap;

  const TicketTile({super.key, required this.ticket, this.onTap});

  static final _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  static const _statusLabels = {
    'open': 'Aberto',
    'in_progress': 'Em andamento',
    'resolved': 'Resolvido',
    'closed': 'Fechado',
  };

  static const _priorityLabels = {'low': 'Baixa', 'medium': 'Média', 'high': 'Alta', 'critical': 'Crítica'};

  Color _statusColor(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return switch (ticket.status) {
      'open' => scheme.primary,
      'in_progress' => Colors.orange,
      'resolved' => Colors.green,
      'closed' => scheme.outline,
      _ => scheme.primary,
    };
  }

  IconData _icon(String category) => switch (category.toLowerCase()) {
        'hardware' => Icons.computer,
        'software' => Icons.apps,
        'rede' => Icons.wifi,
        'acesso' => Icons.key,
        _ => Icons.help_outline,
      };

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(child: Icon(_icon(ticket.category))),
        title: Text(ticket.title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${ticket.category} • Prioridade ${_priorityLabels[ticket.priority] ?? ticket.priority}'),
            Text(
              '${ticket.assignee != null ? "Responsável: ${ticket.assignee!.name} • " : ""}${_dateFormat.format(ticket.createdAt.toLocal())}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        isThreeLine: true,
        trailing: Chip(
          label: Text(_statusLabels[ticket.status] ?? ticket.status),
          backgroundColor: statusColor.withValues(alpha: 0.12),
          labelStyle: TextStyle(color: statusColor, fontWeight: FontWeight.w600),
          side: BorderSide.none,
        ),
      ),
    );
  }
}

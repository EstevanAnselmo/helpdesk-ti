import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/comment.dart';
import '../../models/history.dart';
import '../../models/ticket.dart';
import '../../models/user.dart';
import '../../services/api_service.dart';

class TicketDetailScreen extends StatefulWidget {
  final ApiService api;
  final int ticketId;

  const TicketDetailScreen({
    super.key,
    required this.api,
    required this.ticketId,
  });

  @override
  State<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<TicketDetailScreen> {
  static final _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  static const _statusLabels = {
    'open': 'Aberto',
    'in_progress': 'Em andamento',
    'resolved': 'Resolvido',
    'closed': 'Fechado',
  };

  static const _priorityLabels = {
    'low': 'Baixa',
    'medium': 'Média',
    'high': 'Alta',
    'critical': 'Crítica',
  };

  Ticket? ticket;
  List<TicketCommentModel> comments = [];
  List<TicketHistoryModel> history = [];
  List<User> staff = [];
  bool loading = true;
  String? error;
  bool updating = false;
  bool sendingComment = false;
  final commentController = TextEditingController();

  bool get isStaff => widget.api.currentUser?.isStaff ?? false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    commentController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        loading = true;
        error = null;
      });
    }

    try {
      final futures = <Future<dynamic>>[
        widget.api.getTicket(widget.ticketId),
        widget.api.getComments(widget.ticketId),
        widget.api.getHistory(widget.ticketId),
      ];

      if (isStaff) {
        futures.add(widget.api.getStaffUsers());
      }

      final results = await Future.wait(futures);

      if (!mounted) return;

      setState(() {
        ticket = results[0] as Ticket;
        comments = results[1] as List<TicketCommentModel>;
        history = results[2] as List<TicketHistoryModel>;
        if (isStaff) {
          staff = results[3] as List<User>;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (!mounted) return;
      setState(() {
        loading = false;
      });
    }
  }

  Future<void> _updateTicket(Map<String, dynamic> data) async {
    setState(() => updating = true);
    try {
      final updated = await widget.api.updateTicket(widget.ticketId, data);
      await _load();
      if (!mounted) return;
      setState(() => ticket = updated);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (!mounted) return;
      setState(() => updating = false);
    }
  }

  Future<void> _sendComment() async {
    final text = commentController.text.trim();
    if (text.isEmpty) return;

    setState(() => sendingComment = true);
    try {
      final comment = await widget.api.addComment(widget.ticketId, text);
      setState(() {
        comments = [...comments, comment];
        commentController.clear();
      });
      final updatedHistory = await widget.api.getHistory(widget.ticketId);
      if (!mounted) return;
      setState(() => history = updatedHistory);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (!mounted) return;
      setState(() => sendingComment = false);
    }
  }

  String _statusLabel(String value) => _statusLabels[value] ?? value;

  String _priorityLabel(String value) => _priorityLabels[value] ?? value;

  String _historyText(TicketHistoryModel item) {
    final actor = item.actor?.name ?? 'Usuário';

    return switch (item.action) {
      'created' => '$actor abriu o chamado.',
      'status_changed' =>
        '$actor alterou o status de ${_statusLabel(item.oldValue ?? '')} para ${_statusLabel(item.newValue ?? '')}.',
      'priority_changed' =>
        '$actor alterou a prioridade de ${_priorityLabel(item.oldValue ?? '')} para ${_priorityLabel(item.newValue ?? '')}.',
      'assignee_changed' => '$actor atribuiu o chamado a ${_assigneeName(item.newValue)}.',
      'comment_added' => '$actor adicionou um comentário.',
      _ => '$actor realizou uma alteração no chamado.',
    };
  }

  String _assigneeName(String? id) {
    if (id == null) return 'um responsável';
    final numericId = int.tryParse(id);
    if (numericId == null) return 'um responsável';
    final match = staff.where((u) => u.id == numericId);
    if (match.isNotEmpty) return match.first.name;
    if (ticket?.assignee?.id == numericId) return ticket!.assignee!.name;
    return 'um responsável';
  }

  IconData _historyIcon(String action) {
    return switch (action) {
      'created' => Icons.add_circle_outline,
      'status_changed' => Icons.swap_horiz,
      'priority_changed' => Icons.flag_outlined,
      'assignee_changed' => Icons.person_outline,
      'comment_added' => Icons.chat_bubble_outline,
      _ => Icons.history,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          ticket != null ? '#${ticket!.id} ${ticket!.title}' : 'Chamado',
        ),
        actions: [
          IconButton(
            onPressed: loading ? null : _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar',
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(child: Text(error!))
              : _content(),
    );
  }

  Widget _content() {
    final t = ticket!;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          t.title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        Text(
          t.description,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Chip(label: Text('Categoria: ${t.category}')),
            Chip(label: Text('Prioridade: ${_priorityLabel(t.priority)}')),
            Chip(label: Text('Status: ${_statusLabel(t.status)}')),
            Chip(label: Text('Criado em ${_dateFormat.format(t.createdAt.toLocal())}')),
            if (t.creator != null) Chip(label: Text('Aberto por ${t.creator!.name}')),
            if (t.assignee != null) Chip(label: Text('Responsável: ${t.assignee!.name}')),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          'Status',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _statusLabels.entries
              .map(
                (entry) => ChoiceChip(
                  label: Text(entry.value),
                  selected: t.status == entry.key,
                  onSelected: updating
                      ? null
                      : (_) => _updateTicket({'status': entry.key}),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 20),
        if (isStaff) ...[
          Text(
            'Prioridade',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _priorityLabels.entries
                .map(
                  (entry) => ChoiceChip(
                    label: Text(entry.value),
                    selected: t.priority == entry.key,
                    onSelected: updating
                        ? null
                        : (_) => _updateTicket({'priority': entry.key}),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 20),
          Text(
            'Responsável',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            initialValue: t.assigneeId,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
            ),
            hint: const Text('Sem responsável'),
            items: staff
                .map(
                  (user) => DropdownMenuItem(
                    value: user.id,
                    child: Text(user.name),
                  ),
                )
                .toList(),
            onChanged: updating
                ? null
                : (value) {
                    if (value != null) {
                      _updateTicket({'assignee_id': value});
                    }
                  },
          ),
          const SizedBox(height: 24),
        ],
        const Divider(),
        const SizedBox(height: 12),
        Text(
          'Conversa',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        if (comments.isEmpty) const Text('Nenhum comentário ainda.'),
        ...comments.map(
          (comment) => Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          comment.author?.name ?? 'Usuário',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Text(
                        _dateFormat.format(comment.createdAt.toLocal()),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(comment.content),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: commentController,
                decoration: const InputDecoration(
                  hintText: 'Escreva um comentário...',
                  border: OutlineInputBorder(),
                ),
                minLines: 1,
                maxLines: 4,
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: sendingComment ? null : _sendComment,
              icon: sendingComment
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              tooltip: 'Enviar comentário',
            ),
          ],
        ),
        const SizedBox(height: 28),
        const Divider(),
        const SizedBox(height: 12),
        Text(
          'Histórico do atendimento',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        if (history.isEmpty)
          const Text('Nenhum evento registrado.'),
        ...history.map(
          (item) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              child: Icon(_historyIcon(item.action), size: 18),
            ),
            title: Text(_historyText(item)),
            subtitle: Text(
              _dateFormat.format(item.createdAt.toLocal()),
            ),
          ),
        ),
      ],
    );
  }
}

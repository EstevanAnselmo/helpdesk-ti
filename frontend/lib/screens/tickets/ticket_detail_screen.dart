import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/comment.dart';
import '../../models/ticket.dart';
import '../../models/user.dart';
import '../../services/api_service.dart';

class TicketDetailScreen extends StatefulWidget {
  final ApiService api;
  final int ticketId;
  const TicketDetailScreen({super.key, required this.api, required this.ticketId});

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
  static const _priorityLabels = {'low': 'Baixa', 'medium': 'Média', 'high': 'Alta', 'critical': 'Crítica'};

  Ticket? ticket;
  List<TicketCommentModel> comments = [];
  List<User> staff = [];
  bool loading = true;
  String? error;
  bool updating = false;
  final commentController = TextEditingController();
  bool sendingComment = false;

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
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final futures = <Future>[widget.api.getTicket(widget.ticketId), widget.api.getComments(widget.ticketId)];
      if (isStaff) futures.add(widget.api.getStaffUsers());
      final results = await Future.wait(futures);
      setState(() {
        ticket = results[0] as Ticket;
        comments = results[1] as List<TicketCommentModel>;
        if (isStaff) staff = results[2] as List<User>;
      });
    } catch (e) {
      setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _updateTicket(Map<String, dynamic> data) async {
    setState(() => updating = true);
    try {
      final updated = await widget.api.updateTicket(widget.ticketId, data);
      setState(() => ticket = updated);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => updating = false);
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => sendingComment = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(ticket != null ? '#${ticket!.id} ${ticket!.title}' : 'Chamado')),
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
        Text(t.description, style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          Chip(label: Text('Categoria: ${t.category}')),
          Chip(label: Text('Criado em ${_dateFormat.format(t.createdAt.toLocal())}')),
          if (t.creator != null) Chip(label: Text('Aberto por ${t.creator!.name}')),
        ]),
        const SizedBox(height: 24),
        Text('Status', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: _statusLabels.entries
              .map((e) => ChoiceChip(
                    label: Text(e.value),
                    selected: t.status == e.key,
                    onSelected: updating ? null : (_) => _updateTicket({'status': e.key}),
                  ))
              .toList(),
        ),
        const SizedBox(height: 20),
        if (isStaff) ...[
          Text('Prioridade (equipe de suporte)', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _priorityLabels.entries
                .map((e) => ChoiceChip(
                      label: Text(e.value),
                      selected: t.priority == e.key,
                      onSelected: updating ? null : (_) => _updateTicket({'priority': e.key}),
                    ))
                .toList(),
          ),
          const SizedBox(height: 20),
          Text('Responsável', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            initialValue: t.assigneeId,
            decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
            hint: const Text('Sem responsável'),
            items: staff.map((u) => DropdownMenuItem(value: u.id, child: Text(u.name))).toList(),
            onChanged: updating ? null : (value) => _updateTicket({'assignee_id': value}),
          ),
          const SizedBox(height: 24),
        ] else ...[
          Text('Prioridade: ${_priorityLabels[t.priority] ?? t.priority}', style: Theme.of(context).textTheme.titleMedium),
          if (t.assignee != null) Text('Responsável: ${t.assignee!.name}'),
          const SizedBox(height: 24),
        ],
        const Divider(),
        const SizedBox(height: 12),
        Text('Comentários', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        if (comments.isEmpty) const Text('Nenhum comentário ainda.'),
        ...comments.map((c) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(c.author?.name ?? 'Usuário', style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text(_dateFormat.format(c.createdAt.toLocal()), style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(c.content),
                  ],
                ),
              ),
            )),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: commentController,
                decoration: const InputDecoration(hintText: 'Escreva um comentário...', border: OutlineInputBorder(), isDense: true),
                minLines: 1,
                maxLines: 4,
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: sendingComment ? null : _sendComment,
              icon: sendingComment
                  ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.send),
            ),
          ],
        ),
      ],
    );
  }
}

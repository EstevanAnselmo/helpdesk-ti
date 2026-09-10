import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/ticket.dart';
import '../../services/api_service.dart';
import '../../widgets/ticket_tile.dart';
import 'new_ticket_dialog.dart';

class TicketsScreen extends StatefulWidget {
  final ApiService api;
  final void Function(int ticketId) onOpenTicket;
  const TicketsScreen({super.key, required this.api, required this.onOpenTicket});

  @override
  State<TicketsScreen> createState() => _TicketsScreenState();
}

class _TicketsScreenState extends State<TicketsScreen> {
  static const _statusFilters = {
    null: 'Todos',
    'open': 'Aberto',
    'in_progress': 'Em andamento',
    'resolved': 'Resolvido',
    'closed': 'Fechado',
  };

  String? statusFilter;
  final searchController = TextEditingController();
  Timer? _debounce;

  bool loading = true;
  String? error;
  TicketPage? page;
  int skip = 0;
  static const limit = 15;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    searchController.dispose();
    super.dispose();
  }

  Future<void> _load({bool resetPage = false}) async {
    if (resetPage) skip = 0;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await widget.api.getTickets(
        status: statusFilter,
        search: searchController.text.trim().isEmpty ? null : searchController.text.trim(),
        skip: skip,
        limit: limit,
      );
      setState(() => page = result);
    } catch (e) {
      setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _load(resetPage: true));
  }

  Future<void> _openNewTicketDialog() async {
    final created = await showDialog(context: context, builder: (_) => NewTicketDialog(api: widget.api));
    if (created != null) _load(resetPage: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openNewTicketDialog,
        icon: const Icon(Icons.add),
        label: const Text('Novo chamado'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: searchController,
              onChanged: _onSearchChanged,
              decoration: const InputDecoration(
                hintText: 'Buscar por título ou descrição...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: _statusFilters.entries.map((entry) {
                final selected = statusFilter == entry.key;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(entry.value),
                    selected: selected,
                    onSelected: (_) {
                      setState(() => statusFilter = entry.key);
                      _load(resetPage: true);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) return Center(child: Text(error!));
    final items = page?.items ?? [];
    if (items.isEmpty) {
      return const Center(child: Text('Nenhum chamado encontrado com esses filtros.'));
    }
    final total = page?.total ?? 0;
    return RefreshIndicator(
      onRefresh: () => _load(),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          ...items.map((t) => TicketTile(ticket: t, onTap: () => widget.onOpenTicket(t.id))),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton.icon(
                onPressed: skip > 0
                    ? () {
                        setState(() => skip = (skip - limit).clamp(0, total));
                        _load();
                      }
                    : null,
                icon: const Icon(Icons.chevron_left),
                label: const Text('Anteriores'),
              ),
              Text('${skip + 1}-${(skip + items.length).clamp(0, total)} de $total'),
              TextButton.icon(
                onPressed: (skip + limit) < total
                    ? () {
                        setState(() => skip += limit);
                        _load();
                      }
                    : null,
                icon: const Icon(Icons.chevron_right),
                label: const Text('Próximos'),
              ),
            ],
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

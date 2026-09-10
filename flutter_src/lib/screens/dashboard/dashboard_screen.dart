import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../widgets/metric_card.dart';
import '../../widgets/ticket_tile.dart';
import '../auth/login_screen.dart';
import '../tickets/ticket_detail_screen.dart';
import '../tickets/tickets_screen.dart';

class DashboardScreen extends StatefulWidget {
  final ApiService api;
  const DashboardScreen({super.key, required this.api});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int tab = 0;
  bool loading = true;
  String? error;
  List tickets = [];
  Map<String, dynamic> stats = {};

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final results = await Future.wait([widget.api.getTickets(limit: 5), widget.api.getStats()]);
      tickets = results[0].items;
      stats = results[1] as Map<String, dynamic>;
    } catch (e) {
      error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> _logout() async {
    await widget.api.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => LoginScreen(api: widget.api)),
      (route) => false,
    );
  }

  void _openTicket(int id) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => TicketDetailScreen(api: widget.api, ticketId: id)));
    load();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _dashboard(),
      TicketsScreen(api: widget.api, onOpenTicket: _openTicket),
    ];
    final user = widget.api.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: const Text('HelpDesk TI'),
        actions: [
          IconButton(onPressed: load, icon: const Icon(Icons.refresh), tooltip: 'Atualizar'),
          PopupMenuButton<String>(
            icon: const Icon(Icons.account_circle_outlined),
            onSelected: (value) {
              if (value == 'logout') _logout();
            },
            itemBuilder: (_) => [
              PopupMenuItem(enabled: false, child: Text(user?.name ?? '', style: const TextStyle(fontWeight: FontWeight.bold))),
              if (user != null) PopupMenuItem(enabled: false, child: Text(_roleLabel(user.role.name))),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'logout', child: Text('Sair')),
            ],
          ),
        ],
      ),
      body: tab == 0
          ? (loading
              ? const Center(child: CircularProgressIndicator())
              : error != null
                  ? Center(child: Text(error!))
                  : pages[0])
          : pages[1],
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Dashboard'),
          NavigationDestination(
            icon: Icon(Icons.confirmation_number_outlined),
            selectedIcon: Icon(Icons.confirmation_number),
            label: 'Chamados',
          ),
        ],
      ),
    );
  }

  String _roleLabel(String role) => switch (role) {
        'admin' => 'Administrador',
        'agent' => 'Agente de suporte',
        _ => 'Usuário',
      };

  Widget _dashboard() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Olá, ${widget.api.currentUser?.name ?? 'usuário'}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        const Text('Acompanhe o status do suporte de TI.'),
        const SizedBox(height: 24),
        Wrap(spacing: 12, runSpacing: 12, children: [
          MetricCard(title: 'Abertos', value: '${stats['open'] ?? 0}', icon: Icons.radio_button_checked),
          MetricCard(title: 'Em andamento', value: '${stats['in_progress'] ?? 0}', icon: Icons.timelapse, color: Colors.orange),
          MetricCard(title: 'Resolvidos', value: '${stats['resolved'] ?? 0}', icon: Icons.check_circle_outline, color: Colors.green),
          MetricCard(title: 'Total', value: '${stats['total'] ?? 0}', icon: Icons.confirmation_number_outlined),
        ]),
        const SizedBox(height: 28),
        const Text('Chamados recentes', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        if (tickets.isEmpty) const Text('Nenhum chamado por aqui ainda.'),
        ...tickets.map((ticket) => TicketTile(ticket: ticket, onTap: () => _openTicket(ticket.id))),
      ],
    );
  }
}

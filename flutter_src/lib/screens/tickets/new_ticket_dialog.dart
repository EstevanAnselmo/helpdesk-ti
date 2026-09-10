import 'package:flutter/material.dart';

import '../../services/api_service.dart';

class NewTicketDialog extends StatefulWidget {
  final ApiService api;
  const NewTicketDialog({super.key, required this.api});

  @override
  State<NewTicketDialog> createState() => _NewTicketDialogState();
}

class _NewTicketDialogState extends State<NewTicketDialog> {
  final _formKey = GlobalKey<FormState>();
  final title = TextEditingController();
  final description = TextEditingController();
  final category = TextEditingController();
  String priority = 'medium';
  bool saving = false;
  String? error;

  static const _categories = ['Hardware', 'Software', 'Rede', 'Acesso', 'Outro'];
  static const _priorities = {'low': 'Baixa', 'medium': 'Média', 'high': 'Alta', 'critical': 'Crítica'};

  @override
  void dispose() {
    title.dispose();
    description.dispose();
    category.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final ticket = await widget.api.createTicket(
        title: title.text.trim(),
        description: description.text.trim(),
        category: category.text.trim(),
        priority: priority,
      );
      if (!mounted) return;
      Navigator.pop(context, ticket);
    } catch (e) {
      setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Abrir novo chamado'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: title,
                  decoration: const InputDecoration(labelText: 'Título'),
                  validator: (v) => (v == null || v.trim().length < 3) ? 'Mínimo de 3 caracteres' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: description,
                  decoration: const InputDecoration(labelText: 'Descrição'),
                  maxLines: 4,
                  validator: (v) => (v == null || v.trim().length < 5) ? 'Descreva melhor o problema' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _categories.contains(category.text) ? category.text : null,
                  decoration: const InputDecoration(labelText: 'Categoria'),
                  items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) => category.text = v ?? '',
                  validator: (v) => (category.text.trim().isEmpty) ? 'Selecione uma categoria' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: priority,
                  decoration: const InputDecoration(labelText: 'Prioridade'),
                  items: _priorities.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                  onChanged: (v) => setState(() => priority = v ?? 'medium'),
                ),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: saving ? null : () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: saving ? null : _submit,
          child: saving
              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Abrir chamado'),
        ),
      ],
    );
  }
}

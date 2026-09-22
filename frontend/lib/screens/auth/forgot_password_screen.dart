import 'package:flutter/material.dart';

import '../../services/api_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  final ApiService api;
  final String initialEmail;

  const ForgotPasswordScreen({
    super.key,
    required this.api,
    this.initialEmail = '',
  });

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController emailController;

  bool loading = false;
  bool sent = false;

  String? error;
  String? message;

  @override
  void initState() {
    super.initState();

    emailController = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      loading = true;
      error = null;
      message = null;
    });

    try {
      final result = await widget.api.forgotPassword(
        emailController.text.trim(),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        message = result;
        sent = true;
      });
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        error = e.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        error = 'Não foi possível solicitar a recuperação de senha.';
      });
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  void _goBack() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recuperar senha')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(
                        sent
                            ? Icons.mark_email_read_outlined
                            : Icons.lock_reset,
                        size: 64,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        sent ? 'Verifique seu e-mail' : 'Esqueceu sua senha?',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        sent
                            ? 'Se existir uma conta vinculada '
                                  'a este e-mail, enviaremos um '
                                  'link para redefinir sua senha.'
                            : 'Informe o e-mail cadastrado '
                                  'na sua conta do HelpDesk.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: emailController,
                        enabled: !sent,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        decoration: const InputDecoration(
                          labelText: 'E-mail',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        validator: (value) {
                          final email = value?.trim() ?? '';

                          if (email.isEmpty || !email.contains('@')) {
                            return 'Informe um e-mail válido';
                          }

                          return null;
                        },
                        onFieldSubmitted: (_) {
                          if (!loading && !sent) {
                            _submit();
                          }
                        },
                      ),
                      if (error != null) ...[
                        const SizedBox(height: 14),
                        Text(
                          error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      if (message != null && sent) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            message!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      if (!sent)
                        FilledButton.icon(
                          onPressed: loading ? null : _submit,
                          icon: loading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.send_outlined),
                          label: Text(
                            loading
                                ? 'Enviando...'
                                : 'Enviar link de recuperação',
                          ),
                        ),
                      if (sent)
                        FilledButton(
                          onPressed: _goBack,
                          child: const Text('Voltar para o login'),
                        ),
                      if (!sent) ...[
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: loading ? null : _goBack,
                          child: const Text('Voltar para o login'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

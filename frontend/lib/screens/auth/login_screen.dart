import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../dashboard/dashboard_screen.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  final ApiService api;

  const LoginScreen({super.key, required this.api});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();

  final email = TextEditingController();
  final password = TextEditingController();

  bool loading = false;
  bool resending = false;

  String? error;
  bool needsEmailVerification = false;

  @override
  void dispose() {
    email.dispose();
    password.dispose();

    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      loading = true;
      error = null;
      needsEmailVerification = false;
    });

    try {
      await widget.api.login(email.text.trim(), password.text);

      if (!mounted) {
        return;
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => DashboardScreen(api: widget.api)),
      );
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        error = e.message;
        needsEmailVerification = e.statusCode == 403;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  Future<void> _resendVerification() async {
    if (email.text.trim().isEmpty) {
      return;
    }

    setState(() {
      resending = true;
    });

    try {
      final message = await widget.api.resendVerification(email.text.trim());

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() {
          resending = false;
        });
      }
    }
  }

  void _openForgotPassword() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ForgotPasswordScreen(
          api: widget.api,
          initialEmail: email.text.trim(),
        ),
      ),
    );
  }

  void _openRegister() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RegisterScreen(api: widget.api)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                    children: [
                      const Icon(Icons.support_agent, size: 64),
                      const SizedBox(height: 16),
                      const Text(
                        'HelpDesk TI',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text('Acesse sua central de suporte'),
                      const SizedBox(height: 24),

                      TextFormField(
                        controller: email,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        decoration: const InputDecoration(
                          labelText: 'E-mail',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        validator: (value) {
                          if (value == null || !value.contains('@')) {
                            return 'Informe um e-mail válido';
                          }

                          return null;
                        },
                      ),

                      const SizedBox(height: 12),

                      TextFormField(
                        controller: password,
                        obscureText: true,
                        autofillHints: const [AutofillHints.password],
                        decoration: const InputDecoration(
                          labelText: 'Senha',
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Informe sua senha';
                          }

                          return null;
                        },
                        onFieldSubmitted: (_) {
                          if (!loading) {
                            _login();
                          }
                        },
                      ),

                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: loading ? null : _openForgotPassword,
                          child: const Text('Esqueci minha senha'),
                        ),
                      ),

                      if (error != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),

                        if (needsEmailVerification) ...[
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: resending ? null : _resendVerification,
                            icon: resending
                                ? const SizedBox(
                                    height: 14,
                                    width: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.mail_outline, size: 18),
                            label: const Text('Reenviar e-mail de confirmação'),
                          ),
                        ],
                      ],

                      const SizedBox(height: 20),

                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: loading ? null : _login,
                          child: loading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Entrar'),
                        ),
                      ),

                      const SizedBox(height: 8),

                      TextButton(
                        onPressed: loading ? null : _openRegister,
                        child: const Text('Ainda não tem conta? Cadastre-se'),
                      ),
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

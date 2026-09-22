import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/api_config.dart';
import '../core/session_store.dart';
import '../models/comment.dart';
import '../models/history.dart';
import '../models/ticket.dart';
import '../models/user.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

/// Camada única de acesso à API + estado de sessão do app.
class ApiService extends ChangeNotifier {
  final SessionStore _sessionStore = SessionStore();

  String? _token;
  User? _currentUser;
  bool _restoring = true;

  void Function()? onSessionExpired;

  User? get currentUser => _currentUser;

  bool get isAuthenticated => _token != null && _currentUser != null;

  bool get isRestoringSession => _restoring;

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  Future<void> restoreSession() async {
    final saved = await _sessionStore.readToken();

    if (saved == null) {
      _restoring = false;
      notifyListeners();
      return;
    }

    _token = saved;

    try {
      _currentUser = await _fetchMe();
    } catch (_) {
      _token = null;
      _currentUser = null;

      await _sessionStore.clear();
    }

    _restoring = false;
    notifyListeners();
  }

  Future<User> _fetchMe() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/auth/me'),
      headers: _headers,
    );

    _throwIfError(response);

    return User.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/auth/login'),
      headers: _headers,
      body: jsonEncode({'email': email.trim(), 'password': password}),
    );

    _throwIfError(response, fallback: 'Falha no login');

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    final accessToken = data['access_token'];

    if (accessToken is! String || accessToken.isEmpty) {
      throw ApiException('Resposta de login inválida');
    }

    final userData = data['user'];

    if (userData is! Map<String, dynamic>) {
      throw ApiException('Usuário ausente na resposta de login');
    }

    _token = accessToken;
    _currentUser = User.fromJson(userData);

    await _sessionStore.saveToken(accessToken);

    notifyListeners();
  }

  Future<String> register(String name, String email, String password) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/auth/register'),
      headers: _headers,
      body: jsonEncode({
        'name': name.trim(),
        'email': email.trim(),
        'password': password,
      }),
    );

    _throwIfError(response, fallback: 'Falha no cadastro');

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    final message = data['message'];

    if (message is String && message.trim().isNotEmpty) {
      return message;
    }

    return 'Cadastro realizado. '
        'Verifique seu e-mail antes de fazer login.';
  }

  Future<String> resendVerification(String email) async {
    final response = await http.post(
      Uri.parse(
        '${ApiConfig.baseUrl}'
        '/auth/resend-verification',
      ),
      headers: _headers,
      body: jsonEncode({'email': email.trim()}),
    );

    _throwIfError(
      response,
      fallback: 'Falha ao reenviar o e-mail de confirmação',
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    final message = data['message'];

    if (message is String && message.trim().isNotEmpty) {
      return message;
    }

    return 'Se o e-mail estiver pendente '
        'de confirmação, um novo link será enviado.';
  }

  Future<String> forgotPassword(String email) async {
    final response = await http.post(
      Uri.parse(
        '${ApiConfig.baseUrl}'
        '/auth/forgot-password',
      ),
      headers: _headers,
      body: jsonEncode({'email': email.trim()}),
    );

    _throwIfError(
      response,
      fallback: 'Falha ao solicitar recuperação de senha',
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    final message = data['message'];

    if (message is String && message.trim().isNotEmpty) {
      return message;
    }

    return 'Se o e-mail estiver cadastrado, '
        'enviaremos um link para redefinir sua senha.';
  }

  Future<void> logout() async {
    _token = null;
    _currentUser = null;

    await _sessionStore.clear();

    notifyListeners();
  }

  Future<TicketPage> getTickets({
    String? status,
    String? priority,
    String? category,
    String? search,
    bool mine = false,
    int skip = 0,
    int limit = 20,
  }) async {
    final query = <String, String>{
      'skip': '$skip',
      'limit': '$limit',
      'status': ?status,
      'priority': ?priority,
      if (category != null && category.isNotEmpty) 'category': category,
      if (search != null && search.isNotEmpty) 'search': search,
      if (mine) 'mine': 'true',
    };

    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/tickets',
    ).replace(queryParameters: query);

    final response = await http.get(uri, headers: _headers);

    _throwIfError(response, fallback: 'Falha ao carregar chamados');

    return TicketPage.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<Ticket> getTicket(int id) async {
    final response = await http.get(
      Uri.parse(
        '${ApiConfig.baseUrl}'
        '/tickets/$id',
      ),
      headers: _headers,
    );

    _throwIfError(response, fallback: 'Falha ao carregar chamado');

    return Ticket.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<Ticket> createTicket({
    required String title,
    required String description,
    required String category,
    required String priority,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/tickets'),
      headers: _headers,
      body: jsonEncode({
        'title': title,
        'description': description,
        'category': category,
        'priority': priority,
      }),
    );

    _throwIfError(response, fallback: 'Falha ao criar chamado');

    return Ticket.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<Ticket> updateTicket(int id, Map<String, dynamic> data) async {
    final response = await http.patch(
      Uri.parse(
        '${ApiConfig.baseUrl}'
        '/tickets/$id',
      ),
      headers: _headers,
      body: jsonEncode(data),
    );

    _throwIfError(response, fallback: 'Falha ao atualizar chamado');

    return Ticket.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> getStats() async {
    final response = await http.get(
      Uri.parse(
        '${ApiConfig.baseUrl}'
        '/tickets/stats/summary',
      ),
      headers: _headers,
    );

    _throwIfError(response, fallback: 'Falha ao carregar métricas');

    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  Future<List<TicketHistoryModel>> getHistory(int ticketId) async {
    final response = await http.get(
      Uri.parse(
        '${ApiConfig.baseUrl}'
        '/tickets/$ticketId/history',
      ),
      headers: _headers,
    );

    _throwIfError(response, fallback: 'Falha ao carregar histórico');

    return (jsonDecode(response.body) as List)
        .map(
          (item) => TicketHistoryModel.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  Future<List<TicketCommentModel>> getComments(int ticketId) async {
    final response = await http.get(
      Uri.parse(
        '${ApiConfig.baseUrl}'
        '/tickets/$ticketId/comments',
      ),
      headers: _headers,
    );

    _throwIfError(response, fallback: 'Falha ao carregar comentários');

    return (jsonDecode(response.body) as List)
        .map(
          (item) => TicketCommentModel.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  Future<TicketCommentModel> addComment(int ticketId, String content) async {
    final response = await http.post(
      Uri.parse(
        '${ApiConfig.baseUrl}'
        '/tickets/$ticketId/comments',
      ),
      headers: _headers,
      body: jsonEncode({'content': content}),
    );

    _throwIfError(response, fallback: 'Falha ao comentar');

    return TicketCommentModel.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<List<User>> getStaffUsers() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/users'),
      headers: _headers,
    );

    _throwIfError(response, fallback: 'Falha ao carregar equipe de suporte');

    return (jsonDecode(response.body) as List)
        .map((item) => User.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  void _throwIfError(
    http.Response response, {
    String fallback = 'Erro inesperado',
  }) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    String detail = fallback;

    try {
      final body = jsonDecode(response.body);

      if (body is Map && body['detail'] != null) {
        detail = body['detail'] is String
            ? body['detail'] as String
            : body['detail'].toString();
      }
    } catch (_) {
      // Mantém a mensagem padrão caso
      // a resposta não seja JSON.
    }

    if (response.statusCode == 401) {
      final hadSession = _token != null;

      _token = null;
      _currentUser = null;

      unawaited(_sessionStore.clear());

      notifyListeners();

      if (hadSession) {
        onSessionExpired?.call();
      }
    }

    throw ApiException(detail, statusCode: response.statusCode);
  }
}

void unawaited(Future<void> future) {}

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/api_config.dart';
import '../core/session_store.dart';
import '../models/comment.dart';
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
///
/// É um [ChangeNotifier] para que qualquer tela possa reagir a login/logout
/// sem precisar repassar callbacks manualmente por todos os widgets.
class ApiService extends ChangeNotifier {
  final SessionStore _sessionStore = SessionStore();
  String? _token;
  User? _currentUser;
  bool _restoring = true;

  /// Chamado quando uma sessão que já estava autenticada é invalidada
  /// (token expirado/revogado) — permite que a tela de login seja aberta
  /// mesmo se o usuário estiver em uma tela profunda de navegação.
  void Function()? onSessionExpired;

  User? get currentUser => _currentUser;
  bool get isAuthenticated => _token != null && _currentUser != null;
  bool get isRestoringSession => _restoring;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  /// Tenta restaurar uma sessão salva (chamado uma vez, na inicialização do app).
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
      // Token expirado/inválido: limpa e volta para o login.
      _token = null;
      await _sessionStore.clear();
    }
    _restoring = false;
    notifyListeners();
  }

  Future<User> _fetchMe() async {
    final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/auth/me'), headers: _headers);
    _throwIfError(response);
    return User.fromJson(jsonDecode(response.body));
  }

  Future<void> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/auth/login'),
      headers: _headers,
      body: jsonEncode({'email': email, 'password': password}),
    );
    _throwIfError(response, fallback: 'Falha no login');
    final data = jsonDecode(response.body);
    _token = data['access_token'];
    _currentUser = User.fromJson(data['user']);
    await _sessionStore.saveToken(_token!);
    notifyListeners();
  }

  Future<void> register(String name, String email, String password) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/auth/register'),
      headers: _headers,
      body: jsonEncode({'name': name, 'email': email, 'password': password}),
    );
    _throwIfError(response, fallback: 'Falha no cadastro');
    // Após cadastrar, já faz login automaticamente para não pedir os dados de novo.
    await login(email, password);
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
      if (status != null) 'status': status,
      if (priority != null) 'priority': priority,
      if (category != null && category.isNotEmpty) 'category': category,
      if (search != null && search.isNotEmpty) 'search': search,
      if (mine) 'mine': 'true',
    };
    final uri = Uri.parse('${ApiConfig.baseUrl}/tickets').replace(queryParameters: query);
    final response = await http.get(uri, headers: _headers);
    _throwIfError(response, fallback: 'Falha ao carregar chamados');
    return TicketPage.fromJson(jsonDecode(response.body));
  }

  Future<Ticket> getTicket(int id) async {
    final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/tickets/$id'), headers: _headers);
    _throwIfError(response, fallback: 'Falha ao carregar chamado');
    return Ticket.fromJson(jsonDecode(response.body));
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
      body: jsonEncode({'title': title, 'description': description, 'category': category, 'priority': priority}),
    );
    _throwIfError(response, fallback: 'Falha ao criar chamado');
    return Ticket.fromJson(jsonDecode(response.body));
  }

  Future<Ticket> updateTicket(int id, Map<String, dynamic> data) async {
    final response = await http.patch(
      Uri.parse('${ApiConfig.baseUrl}/tickets/$id'),
      headers: _headers,
      body: jsonEncode(data),
    );
    _throwIfError(response, fallback: 'Falha ao atualizar chamado');
    return Ticket.fromJson(jsonDecode(response.body));
  }

  Future<Map<String, dynamic>> getStats() async {
    final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/tickets/stats/summary'), headers: _headers);
    _throwIfError(response, fallback: 'Falha ao carregar métricas');
    return Map<String, dynamic>.from(jsonDecode(response.body));
  }

  Future<List<TicketCommentModel>> getComments(int ticketId) async {
    final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/tickets/$ticketId/comments'), headers: _headers);
    _throwIfError(response, fallback: 'Falha ao carregar comentários');
    return (jsonDecode(response.body) as List).map((e) => TicketCommentModel.fromJson(e)).toList();
  }

  Future<TicketCommentModel> addComment(int ticketId, String content) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/tickets/$ticketId/comments'),
      headers: _headers,
      body: jsonEncode({'content': content}),
    );
    _throwIfError(response, fallback: 'Falha ao comentar');
    return TicketCommentModel.fromJson(jsonDecode(response.body));
  }

  /// Lista agentes/admins ativos — usada para preencher o seletor de responsável.
  Future<List<User>> getStaffUsers() async {
    final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/users'), headers: _headers);
    _throwIfError(response, fallback: 'Falha ao carregar equipe de suporte');
    return (jsonDecode(response.body) as List).map((e) => User.fromJson(e)).toList();
  }

  void _throwIfError(http.Response response, {String fallback = 'Erro inesperado'}) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    String detail = fallback;
    try {
      final body = jsonDecode(response.body);
      if (body is Map && body['detail'] != null) {
        detail = body['detail'] is String ? body['detail'] : body['detail'].toString();
      }
    } catch (_) {
      // corpo não era JSON (ex: erro de proxy/servidor fora do ar) — mantém o fallback.
    }
    if (response.statusCode == 401) {
      final hadSession = _token != null;
      // Sessão expirada/token inválido: derruba a sessão local para a UI voltar ao login.
      _token = null;
      _currentUser = null;
      unawaited(_sessionStore.clear());
      notifyListeners();
      if (hadSession) onSessionExpired?.call();
    }
    throw ApiException(detail, statusCode: response.statusCode);
  }
}

void unawaited(Future<void> future) {}

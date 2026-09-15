import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/conso.dart';
import '../models/invoice.dart';
import '../models/line_info.dart';
import '../storage/secure_store.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.sessionLost = false});

  final String message;

  /// Session cleared; [YoupriceApi.session] already switched to inactive.
  final bool sessionLost;

  @override
  String toString() => message;
}

enum LoginResult { loggedIn, codeRequired }

class Session {
  const Session.active() : active = true, message = null;
  const Session.inactive({this.message}) : active = false;

  final bool active;

  /// Reason shown on the login screen, if any.
  final String? message;
}

class YoupriceApi {
  YoupriceApi(this._store, {http.Client? client})
    : _client = client ?? http.Client();

  static const baseUrl = 'https://api.youprice.fr/Vitrine';
  static const _jsonHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };
  static final _random = Random();

  final SecureStore _store;
  final http.Client _client;

  /// Single source of truth for the logged-in state.
  final session = ValueNotifier<Session>(const Session.inactive());

  /// Loads the stored session. Unreadable storage leaves it inactive.
  Future<void> init() async {
    try {
      final token = await _store.token;
      if (token != null && token.isNotEmpty) {
        session.value = const Session.active();
      }
    } catch (_) {}
  }

  Future<void> logout() async {
    await _store.clearSession();
    session.value = const Session.inactive();
  }

  Future<LoginResult> login(String username, String password) async {
    final response = await _auth('/Auth/authenticate', {
      'username': username,
      'password': password,
      'publicKey': await _store.publicKey ?? '',
    });
    final data = _decode(response);
    if (await _storeSession(data, username, password)) {
      return LoginResult.loggedIn;
    }
    if (response.statusCode == 200) return LoginResult.codeRequired;
    throw ApiException(_messageOf(data, response.statusCode));
  }

  Future<void> loginWithCode(
    String username,
    String password,
    String code,
  ) async {
    final response = await _auth('/Auth/authenticateWithCode', {
      'username': username,
      'password': password,
      'code': code,
    });
    final data = _decode(response);
    if (await _storeSession(data, username, password)) return;
    throw ApiException(
      response.statusCode == 200
          ? 'Code invalide ou expiré.'
          : _messageOf(data, response.statusCode),
    );
  }

  Future<void> resendCode(String username, String password) async {
    final response = await _auth('/Auth/ResendCode', {
      'username': username,
      'password': password,
      'publicKey': await _store.publicKey ?? '',
    });
    if (response.statusCode >= 400) {
      throw ApiException(_messageOf(_decode(response), response.statusCode));
    }
  }

  Future<String?> customerName() async {
    final data = await _get('/Customer/GetCustomerBrefInfoById');
    final result = data is Map ? data['result'] : null;
    if (result is! Map) return null;
    final name = '${result['firstName'] ?? ''} ${result['lastName'] ?? ''}'
        .trim();
    return name.isEmpty ? null : name;
  }

  Future<List<String>> activeNumbers() async {
    final data = await _get('/msisdn/getActiveNumero');
    return [for (final item in _list(data)) item.toString()];
  }

  Future<Conso> conso(String phoneNumber) async {
    final data = await _authed(
      (headers) => _client.post(
        _uri('/invoice/getSuiviConsoInfo', {'phoneNumber': phoneNumber}),
        headers: headers,
        body: jsonEncode(phoneNumber),
      ),
    );
    return Conso.fromJson(data);
  }

  Future<LineInfo> lineInfo(String phoneNumber) async {
    final data = await _get('/msisdn/getLigneGsm', {
      'phoneNumber': phoneNumber,
    });
    return LineInfo.fromJson(data is Map ? data : const {});
  }

  Future<Uint8List> invoicePdf(String invoiceId) async {
    final response = await _authedResponse(
      (headers) => _client.post(
        _uri('/invoice/getFileOfInvoices', {'id': invoiceId}),
        headers: {...headers, 'Accept': 'application/pdf'},
        body: '{}',
      ),
    );
    final bytes = response.bodyBytes;
    if (bytes.length < 5 || String.fromCharCodes(bytes.take(4)) != '%PDF') {
      throw ApiException(
        'Youprice n\'a pas renvoyé de PDF pour cette facture.',
      );
    }
    return bytes;
  }

  Future<List<Invoice>> invoices() async {
    final data = await _get('/invoice/getMonthlyInvoices');
    final invoices = [
      for (final item in _list(data))
        if (item is Map) Invoice.fromJson(item),
    ];
    invoices.sort((a, b) {
      final da = a.date, db = b.date;
      if (da == null || db == null) return 0;
      return db.compareTo(da);
    });
    return invoices;
  }

  Future<http.Response> _auth(String path, Map<String, String> body) => _send(
    () =>
        _client.post(_uri(path), headers: _jsonHeaders, body: jsonEncode(body)),
  );

  Future<bool> _storeSession(
    dynamic data,
    String username,
    String password,
  ) async {
    if (data is! Map) return false;
    final token = data['access_token'];
    if (token is! String || token.isEmpty) return false;
    await _store.saveSession(
      token: token,
      username: username,
      password: password,
    );
    final publicKey = data['publicKey'];
    if (publicKey is String && publicKey.isNotEmpty) {
      await _store.setPublicKey(publicKey);
    }
    session.value = const Session.active();
    return true;
  }

  /// Concurrent 401s share one relogin attempt.
  Future<bool> _silentRelogin() =>
      _relogin ??= _doSilentRelogin().whenComplete(() => _relogin = null);

  Future<bool>? _relogin;

  Future<bool> _doSilentRelogin() async {
    final username = await _store.username;
    final password = await _store.password;
    if (username == null || password == null) return false;
    try {
      return await login(username, password) == LoginResult.loggedIn;
    } on ApiException {
      return false;
    }
  }

  Future<dynamic> _get(String path, [Map<String, String>? query]) =>
      _authed((headers) => _client.get(_uri(path, query), headers: headers));

  Future<dynamic> _authed(
    Future<http.Response> Function(Map<String, String> headers) send,
  ) async => _decode(await _authedResponse(send));

  Future<http.Response> _authedResponse(
    Future<http.Response> Function(Map<String, String> headers) send, {
    bool retry = true,
  }) async {
    final token = await _store.token;
    if (token == null || token.isEmpty) {
      await _endSession('Vous n\'êtes pas connecté.');
    }
    final response = await _send(
      () => send({
        ..._jsonHeaders,
        'authorization': 'Bearer $token',
        'x-requestid': _guid(),
      }),
    );
    if (response.statusCode == 401 || response.statusCode == 403) {
      if (retry && await _silentRelogin()) {
        return _authedResponse(send, retry: false);
      }
      await _endSession('Session expirée, veuillez vous reconnecter.');
    }
    if (response.statusCode >= 400) {
      throw ApiException(_messageOf(_decode(response), response.statusCode));
    }
    return response;
  }

  Future<Never> _endSession(String message) async {
    await _store.clearSession();
    session.value = Session.inactive(message: message);
    throw ApiException(message, sessionLost: true);
  }

  Future<http.Response> _send(Future<http.Response> Function() request) async {
    try {
      return await request().timeout(const Duration(seconds: 30));
    } on SocketException {
      throw ApiException('Pas de connexion réseau.');
    } on http.ClientException catch (e) {
      throw ApiException('Erreur réseau : ${e.message}');
    } catch (e) {
      throw ApiException('Erreur réseau : $e');
    }
  }

  Uri _uri(String path, [Map<String, String>? query]) {
    final uri = Uri.parse('$baseUrl$path');
    return query == null ? uri : uri.replace(queryParameters: query);
  }

  static List _list(dynamic data) {
    if (data is List) return data;
    if (data is Map && data['result'] is List) return data['result'];
    return const [];
  }

  static dynamic _decode(http.Response response) {
    if (response.bodyBytes.isEmpty) return null;
    final text = utf8.decode(response.bodyBytes, allowMalformed: true);
    try {
      return jsonDecode(text);
    } on FormatException {
      return text;
    }
  }

  static String _messageOf(dynamic data, int statusCode) {
    final description = data is Map ? data['errorDescription'] : null;
    if (description is String && description.isNotEmpty) return description;
    if (data is String && data.isNotEmpty && data.length < 200) return data;
    return switch (statusCode) {
      400 => 'Requête refusée (400).',
      401 || 403 => 'Identifiant ou mot de passe incorrect.',
      404 => 'Service introuvable (404).',
      >= 500 => 'Le serveur Youprice est indisponible ($statusCode).',
      _ => 'Erreur HTTP $statusCode.',
    };
  }

  static String _guid() {
    String hex(int n) =>
        List.generate(n, (_) => _random.nextInt(16).toRadixString(16)).join();
    return '${hex(8)}-${hex(4)}-4${hex(3)}-${hex(4)}-${hex(12)}';
  }
}

import 'dart:convert';

import 'package:http/http.dart' as http;

import 'config.dart';
import 'protocol.dart';

class ApiException implements Exception {
  final int status;
  final String message;
  ApiException(this.status, this.message);
  @override
  String toString() => message;
}

/// In-memory session (token persistence across restarts comes later — not needed
/// to prove sync).
class AuthStore {
  AuthUser? user;
  String? accessToken;
  String? refreshToken;

  void setSession(AuthResponse r) {
    user = r.user;
    accessToken = r.accessToken;
    refreshToken = r.refreshToken;
  }

  void setTokens(String access, String refresh) {
    accessToken = access;
    refreshToken = refresh;
  }

  void clear() {
    user = null;
    accessToken = null;
    refreshToken = null;
  }
}

/// Mirror of the web client's http.ts: Bearer auth + single 401→refresh→retry.
class ApiClient {
  final AuthStore auth;
  ApiClient(this.auth);

  Uri _u(String path) => Uri.parse('${Config.apiBaseUrl}$path');

  Future<http.Response> _raw(String method, String path, Object? body, String? token) {
    final headers = <String, String>{};
    if (body != null) headers['Content-Type'] = 'application/json';
    if (token != null) headers['Authorization'] = 'Bearer $token';
    final encoded = body == null ? null : jsonEncode(body);
    switch (method) {
      case 'POST':
        return http.post(_u(path), headers: headers, body: encoded);
      case 'DELETE':
        return http.delete(_u(path), headers: headers, body: encoded);
      default:
        return http.get(_u(path), headers: headers);
    }
  }

  Future<bool> _refresh() async {
    final rt = auth.refreshToken;
    if (rt == null) return false;
    final res = await _raw('POST', '/api/auth/refresh', {'refreshToken': rt}, null);
    if (res.statusCode >= 400) {
      auth.clear();
      return false;
    }
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    auth.setTokens(j['accessToken'] as String, j['refreshToken'] as String);
    return true;
  }

  String _msg(http.Response res) {
    try {
      final j = jsonDecode(res.body);
      if (j is Map && j['message'] is String) return j['message'] as String;
    } catch (_) {/* non-JSON body */}
    return 'Request failed (${res.statusCode})';
  }

  Future<Map<String, dynamic>> _authed(String method, String path, [Object? body]) async {
    var res = await _raw(method, path, body, auth.accessToken);
    if (res.statusCode == 401) {
      if (await _refresh()) res = await _raw(method, path, body, auth.accessToken);
    }
    if (res.statusCode >= 400) throw ApiException(res.statusCode, _msg(res));
    if (res.statusCode == 204 || res.body.isEmpty) return {};
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ---- auth ----

  Future<AuthResponse> login(String email, String password) async {
    final res = await _raw('POST', '/api/auth/login', {'email': email, 'password': password}, null);
    if (res.statusCode >= 400) throw ApiException(res.statusCode, _msg(res));
    return AuthResponse.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<AuthResponse> signup(String email, String password, String displayName) async {
    final res = await _raw(
        'POST', '/api/auth/signup', {'email': email, 'password': password, 'displayName': displayName}, null);
    if (res.statusCode >= 400) throw ApiException(res.statusCode, _msg(res));
    return AuthResponse.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  // ---- rooms ----

  Future<RoomSummaryData> createRoom({
    String visibility = 'PRIVATE',
    String playbackControl = 'EVERYONE',
  }) async {
    final j = await _authed('POST', '/api/rooms', {
      'visibility': visibility,
      'playbackControl': playbackControl,
    });
    return RoomSummaryData.fromJson(asMap(j['room']));
  }

  Future<RoomSummaryData> joinRoom(String code, {String? password}) async {
    final j = await _authed(
        'POST', '/api/rooms/${code.toUpperCase()}/join', password != null ? {'password': password} : {});
    return RoomSummaryData.fromJson(asMap(j['room']));
  }
}

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/config/app_config.dart';

/// Fixes DEF-407: Full REST client bound to Mizan v2.2 OpenAPI 3.1 contract
/// (Auth login/register/refresh/logout, Org onboarding, Ledger, Features & City-Pilot Meters/Custody).
class MizanApiClient {
  final http.Client _http;
  String? _jwtToken;
  String? _refreshToken;
  String? _activeOrgId;

  MizanApiClient({http.Client? client}) : _http = client ?? http.Client();

  String? get activeOrgId => _activeOrgId;
  bool get hasSession => _jwtToken != null && _jwtToken!.isNotEmpty;

  void configureSession({required String jwtToken, String? refreshToken, String? activeOrgId}) {
    _jwtToken = jwtToken;
    if (refreshToken != null) _refreshToken = refreshToken;
    if (activeOrgId != null) _activeOrgId = activeOrgId;
  }

  Map<String, String> _headers({String? idempotencyKey, String? overrideOrgId}) {
    final map = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (_jwtToken != null) map['Authorization'] = 'Bearer $_jwtToken';
    final org = overrideOrgId ?? _activeOrgId;
    if (org != null && org.isNotEmpty) map['X-Org-Id'] = org;
    if (idempotencyKey != null) map['Idempotency-Key'] = idempotencyKey;
    return map;
  }

  Future<Map<String, dynamic>> login({required String emailOrPhone, required String password, String? deviceLabel}) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/api/v1/auth/login');
    final res = await _http.post(
      uri,
      headers: _headers(),
      body: jsonEncode({'emailOrPhone': emailOrPhone, 'password': password, 'deviceLabel': deviceLabel ?? 'mizan-flutter'}),
    );
    if (res.statusCode != 200) throw Exception('AUTH_LOGIN_FAILED:${res.statusCode}');
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    configureSession(jwtToken: body['accessToken'] as String, refreshToken: body['refreshToken'] as String?);
    return body;
  }

  Future<Map<String, dynamic>> refreshSession() async {
    if (_refreshToken == null) throw StateError('NO_REFRESH_TOKEN');
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/api/v1/auth/refresh');
    final res = await _http.post(uri, headers: _headers(), body: jsonEncode({'refreshToken': _refreshToken}));
    if (res.statusCode != 200) throw Exception('AUTH_REFRESH_FAILED:${res.statusCode}');
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    configureSession(jwtToken: body['accessToken'] as String, refreshToken: body['refreshToken'] as String?);
    return body;
  }

  Future<List<dynamic>> fetchEffectiveFeatures() async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/api/v1/preferences/features');
    final res = await _http.get(uri, headers: _headers());
    if (res.statusCode != 200) throw Exception('FETCH_FEATURES_FAILED:${res.statusCode}');
    return jsonDecode(res.body) as List<dynamic>;
  }

  Future<Map<String, dynamic>> recordMeterReading(Map<String, dynamic> payload, String idempotencyKey) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/api/v1/pilot/meters');
    final res = await _http.post(uri, headers: _headers(idempotencyKey: idempotencyKey), body: jsonEncode(payload));
    if (res.statusCode < 200 || res.statusCode >= 300) throw Exception('METER_POST_FAILED:${res.statusCode}');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<http.Response> sendRaw({
    required String method,
    required String endpoint,
    required String orgId,
    required String idempotencyKey,
    required String payloadJson,
  }) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}$endpoint');
    final headers = _headers(idempotencyKey: idempotencyKey, overrideOrgId: orgId);
    switch (method.toUpperCase()) {
      case 'POST':
        return _http.post(uri, headers: headers, body: payloadJson);
      case 'PUT':
        return _http.put(uri, headers: headers, body: payloadJson);
      default:
        throw UnsupportedError('Unsupported outbox method: $method');
    }
  }

  Future<Map<String, dynamic>> getTrialBalanceVariance() async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/api/v1/ledger/trial-balance/variance');
    final res = await _http.get(uri, headers: _headers());
    if (res.statusCode != 200) throw Exception('TB_VARIANCE_FAILED:${res.statusCode}');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}

import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/usuario.dart';
import 'session.dart';

class ApiService {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );

  final _storage = const FlutterSecureStorage();

  /// HU-10: registro de usuario.
  Future<Map<String, dynamic>> registrar({
    required String nombreCompleto,
    required String correo,
    required String password,
    String rol = 'aprendiz',
  }) async {
    final resp = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'nombre_completo': nombreCompleto,
        'correo': correo,
        'password': password,
        'rol': rol,
      }),
    );

    if (resp.statusCode == 201) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }
    throw ApiException(_extraerError(resp));
  }

  Future<Map<String, dynamic>> login({
    required String correo,
    required String password,
  }) async {
    final resp = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'correo': correo, 'password': password}),
    );

    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      await _storage.write(key: 'access_token', value: data['access_token'] as String);
      Session.instance.usuario =
          Usuario.fromJson(data['usuario'] as Map<String, dynamic>);
      return data;
    }
    throw ApiException(_extraerError(resp));
  }

  Future<String?> obtenerToken() => _storage.read(key: 'access_token');

  Future<void> cerrarSesion() async {
    await _storage.delete(key: 'access_token');
    Session.instance.usuario = null;
  }

  // ---- Peticiones autenticadas (JWT en el header Authorization) ----

  Future<Map<String, String>> _headers({bool json = true}) async {
    final token = await obtenerToken();
    return {
      if (json) 'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Uri _uri(String path, [Map<String, String?>? query]) {
    final limpio = <String, String>{
      for (final e in (query ?? {}).entries)
        if (e.value != null && e.value!.isNotEmpty) e.key: e.value!,
    };
    return Uri.parse('$baseUrl$path').replace(
      queryParameters: limpio.isEmpty ? null : limpio,
    );
  }

  /// Decodifica el cuerpo o lanza ApiException con el `detail` del backend.
  dynamic _procesar(http.Response resp, {List<int> ok = const [200, 201]}) {
    if (ok.contains(resp.statusCode)) {
      if (resp.statusCode == 204 || resp.body.isEmpty) return null;
      return jsonDecode(utf8.decode(resp.bodyBytes));
    }
    if (resp.statusCode == 401) {
      cerrarSesion();
      throw ApiException('Tu sesión expiró. Inicia sesión de nuevo.');
    }
    throw ApiException(_extraerError(resp));
  }

  Future<dynamic> get(String path, {Map<String, String?>? query}) async =>
      _procesar(await http.get(_uri(path, query), headers: await _headers()));

  Future<dynamic> post(String path, Map<String, dynamic> body) async =>
      _procesar(await http.post(_uri(path),
          headers: await _headers(), body: jsonEncode(body)));

  Future<dynamic> put(String path, Map<String, dynamic> body) async =>
      _procesar(await http.put(_uri(path),
          headers: await _headers(), body: jsonEncode(body)));

  Future<void> delete(String path) async => _procesar(
        await http.delete(_uri(path), headers: await _headers()),
        ok: const [200, 204],
      );

  /// Descarga binaria (PDF del analisis).
  Future<Uint8List> descargar(String path, {Map<String, String?>? query}) async {
    final resp = await http.get(_uri(path, query),
        headers: await _headers(json: false));
    if (resp.statusCode != 200) throw ApiException(_extraerError(resp));
    return resp.bodyBytes;
  }

  String _extraerError(http.Response resp) {
    try {
      final body = jsonDecode(utf8.decode(resp.bodyBytes));
      final detail = body['detail'];
      if (detail is List && detail.isNotEmpty) {
        return detail.map((e) => e['msg']).join(', ');
      }
      return detail?.toString() ?? 'Ocurrio un error inesperado';
    } catch (_) {
      return 'Ocurrio un error inesperado (${resp.statusCode})';
    }
  }
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

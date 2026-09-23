import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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
      return data;
    }
    throw ApiException(_extraerError(resp));
  }

  Future<String?> obtenerToken() => _storage.read(key: 'access_token');

  Future<void> cerrarSesion() => _storage.delete(key: 'access_token');

  String _extraerError(http.Response resp) {
    try {
      final body = jsonDecode(resp.body);
      return body['detail']?.toString() ?? 'Ocurrio un error inesperado';
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

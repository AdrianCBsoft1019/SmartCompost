import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../models/rol_usuario.dart';
import '../models/usuario.dart';
import '../services/api_service.dart';
import '../services/session.dart';

/// Perfiles: lista y CRUD (solo instructor) + edicion del perfil propio.
class UsuarioProvider extends ChangeNotifier {
  final ApiService _api;
  UsuarioProvider([ApiService? api]) : _api = api ?? ApiService();

  List<Usuario> usuarios = [];
  bool cargando = false;
  String? error;

  Future<void> cargar() async {
    cargando = true;
    error = null;
    notifyListeners();
    try {
      final data = await _api.get('/usuarios/');
      usuarios = (data as List)
          .map((e) => Usuario.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      error = e.toString();
    } finally {
      cargando = false;
      notifyListeners();
    }
  }

  Future<void> crear({
    required String nombre,
    required String correo,
    required String password,
    required RolUsuario rol,
  }) async {
    await _api.post('/usuarios/', {
      'nombre_completo': nombre,
      'correo': correo,
      'password': password,
      'rol': rol.value,
    });
    await cargar();
  }

  Future<void> actualizar(
    String id, {
    String? nombre,
    String? correo,
    RolUsuario? rol,
    bool? activo,
    String? password,
  }) async {
    await _api.put('/usuarios/$id', {
      if (nombre != null) 'nombre_completo': nombre,
      if (correo != null) 'correo': correo,
      if (rol != null) 'rol': rol.value,
      if (activo != null) 'activo': activo,
      if (password != null && password.isNotEmpty) 'password': password,
    });
    await cargar();
  }

  Future<void> desactivar(String id) async {
    await _api.delete('/usuarios/$id');
    await cargar();
  }

  /// Sube una foto desde el dispositivo (la API la recorta a 256x256).
  Future<void> subirMiFoto(Uint8List bytes, String nombre) async {
    final data = await _api.subirArchivo('/usuarios/me/foto', bytes, nombre);
    Session.instance.usuario = Usuario.fromJson(data as Map<String, dynamic>);
    Session.instance.fotoCambiada();
  }

  Future<void> quitarMiFoto() async {
    await _api.delete('/usuarios/me/foto');
    final data = await _api.get('/usuarios/me');
    Session.instance.usuario = Usuario.fromJson(data as Map<String, dynamic>);
    Session.instance.fotoCambiada();
  }

  /// Edicion del propio perfil (clic en el logo de usuario).
  Future<void> editarMiPerfil({
    String? nombre,
    String? correo,
    String? passwordActual,
    String? passwordNueva,
  }) async {
    final data = await _api.put('/usuarios/me', {
      if (nombre != null) 'nombre_completo': nombre,
      if (correo != null) 'correo': correo,
      if (passwordNueva != null && passwordNueva.isNotEmpty) ...{
        'password_actual': passwordActual,
        'password_nueva': passwordNueva,
      },
    });
    Session.instance.usuario = Usuario.fromJson(data as Map<String, dynamic>);
  }
}

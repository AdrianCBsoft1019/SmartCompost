import 'rol_usuario.dart';

class Usuario {
  final String id;
  final String nombreCompleto;
  final String correo;
  final RolUsuario rol;
  final bool activo;
  final bool tieneFoto;

  const Usuario({
    required this.id,
    required this.nombreCompleto,
    required this.correo,
    required this.rol,
    required this.activo,
    this.tieneFoto = false,
  });

  factory Usuario.fromJson(Map<String, dynamic> j) => Usuario(
        id: j['id'] as String,
        nombreCompleto: j['nombre_completo'] as String,
        correo: j['correo'] as String,
        rol: RolUsuario.values.firstWhere((r) => r.value == j['rol']),
        activo: j['activo'] as bool,
        tieneFoto: (j['tiene_foto'] as bool?) ?? false,
      );

  /// El instructor es el "Administrador" del sistema.
  bool get esAdmin => rol == RolUsuario.instructor;

  String get iniciales {
    final partes = nombreCompleto.trim().split(RegExp(r'\s+'));
    final a = partes.first.isNotEmpty ? partes.first[0] : '?';
    final b = partes.length > 1 ? partes.last[0] : '';
    return (a + b).toUpperCase();
  }
}

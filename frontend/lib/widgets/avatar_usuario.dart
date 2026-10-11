import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/usuario.dart';
import '../services/api_service.dart';
import '../services/session.dart';
import '../theme/app_theme.dart';

/// Avatar circular: muestra la foto del usuario si la tiene y, si no, sus
/// iniciales. La imagen se pide a la API con el JWT (GET /usuarios/{id}/foto)
/// y se guarda en memoria para no repetir la descarga.
class AvatarUsuario extends StatefulWidget {
  final Usuario usuario;
  final double radius;
  const AvatarUsuario({super.key, required this.usuario, this.radius = 18});

  @override
  State<AvatarUsuario> createState() => _AvatarUsuarioState();
}

class _AvatarUsuarioState extends State<AvatarUsuario> {
  static final Map<String, Uint8List> _cache = {};
  Uint8List? _bytes;
  int _turno = 0;

  String get _clave => '${widget.usuario.id}:${Session.instance.fotoVersion}';

  @override
  void initState() {
    super.initState();
    Session.instance.addListener(_alCambiarSesion);
    _sincronizar(conSetState: false);
  }

  @override
  void didUpdateWidget(AvatarUsuario anterior) {
    super.didUpdateWidget(anterior);
    if (anterior.usuario.id != widget.usuario.id ||
        anterior.usuario.tieneFoto != widget.usuario.tieneFoto) {
      _sincronizar(conSetState: false);
    }
  }

  @override
  void dispose() {
    Session.instance.removeListener(_alCambiarSesion);
    super.dispose();
  }

  void _alCambiarSesion() => _sincronizar(conSetState: true);

  void _aplicar(Uint8List? bytes, bool conSetState) {
    if (conSetState && mounted) {
      setState(() => _bytes = bytes);
    } else {
      _bytes = bytes;
    }
  }

  void _sincronizar({required bool conSetState}) {
    if (!widget.usuario.tieneFoto) {
      _aplicar(null, conSetState);
      return;
    }
    final guardada = _cache[_clave];
    if (guardada != null) {
      _aplicar(guardada, conSetState);
      return;
    }
    _descargar(widget.usuario.id, _clave);
  }

  Future<void> _descargar(String id, String clave) async {
    final turno = ++_turno;
    try {
      final datos = await ApiService().descargar('/usuarios/$id/foto');
      _cache[clave] = datos;
      if (mounted && turno == _turno) setState(() => _bytes = datos);
    } catch (_) {
      if (mounted && turno == _turno) setState(() => _bytes = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: widget.radius,
      backgroundColor: AppColors.accentDark,
      foregroundImage: _bytes == null ? null : MemoryImage(_bytes!),
      child: Text(
        widget.usuario.iniciales,
        style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w800,
            fontSize: widget.radius * 0.62),
      ),
    );
  }
}

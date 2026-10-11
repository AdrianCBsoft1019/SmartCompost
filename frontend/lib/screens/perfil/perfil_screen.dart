import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/usuario_provider.dart';
import '../../services/api_service.dart';
import '../../services/session.dart';
import '../../theme/app_theme.dart';
import '../../widgets/avatar_usuario.dart';
import '../../widgets/panel_card.dart';
import '../login_screen.dart';

/// Edicion del perfil propio. Se abre al hacer clic en el logo/avatar del
/// usuario. El rol se muestra pero no se edita (solo lo cambia el instructor).
class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  final _formKey = GlobalKey<FormState>();
  final _provider = UsuarioProvider();
  late final TextEditingController _nombre;
  late final TextEditingController _correo;
  final _actual = TextEditingController();
  final _nueva = TextEditingController();
  final _picker = ImagePicker();
  bool _guardando = false;
  bool _subiendoFoto = false;
  String? _error;
  String? _errorFoto;

  @override
  void initState() {
    super.initState();
    final u = Session.instance.usuario!;
    _nombre = TextEditingController(text: u.nombreCompleto);
    _correo = TextEditingController(text: u.correo);
  }

  @override
  void dispose() {
    for (final c in [_nombre, _correo, _actual, _nueva]) {
      c.dispose();
    }
    _provider.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await _provider.editarMiPerfil(
        nombre: _nombre.text.trim(),
        correo: _correo.text.trim(),
        passwordActual: _actual.text,
        passwordNueva: _nueva.text,
      );
      _actual.clear();
      _nueva.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Perfil actualizado')));
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  /// Abre el selector de archivos del dispositivo y sube la imagen elegida.
  Future<void> _cambiarFoto() async {
    setState(() => _errorFoto = null);
    try {
      final archivo = await _picker.pickImage(source: ImageSource.gallery);
      if (archivo == null) return; // el usuario cancelo
      final bytes = await archivo.readAsBytes();
      if (bytes.length > 5 * 1024 * 1024) {
        setState(() => _errorFoto = 'La imagen supera el máximo de 5 MB');
        return;
      }
      setState(() => _subiendoFoto = true);
      await _provider.subirMiFoto(bytes, archivo.name);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Foto actualizada')));
    } catch (e) {
      if (mounted) setState(() => _errorFoto = e.toString());
    } finally {
      if (mounted) setState(() => _subiendoFoto = false);
    }
  }

  Future<void> _quitarFoto() async {
    setState(() {
      _subiendoFoto = true;
      _errorFoto = null;
    });
    try {
      await _provider.quitarMiFoto();
    } catch (e) {
      if (mounted) setState(() => _errorFoto = e.toString());
    } finally {
      if (mounted) setState(() => _subiendoFoto = false);
    }
  }

  Future<void> _cerrarSesion() async {
    await ApiService().cerrarSesion();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final u = Session.instance.usuario!;
    return Scaffold(
      appBar: AppBar(
          backgroundColor: AppColors.background, title: const Text('Mi perfil')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: PanelCard(
              child: Form(
                key: _formKey,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    AvatarUsuario(usuario: u, radius: 36),
                    const SizedBox(width: 16),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(u.nombreCompleto,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w800)),
                      Text(
                          u.esAdmin
                              ? 'Administrador (${u.rol.label})'
                              : 'Estudiante (${u.rol.label})',
                          style: const TextStyle(color: AppColors.accent)),
                    ]),
                  ]),
                  const SizedBox(height: 14),
                  Wrap(spacing: 10, runSpacing: 8, children: [
                    OutlinedButton.icon(
                      onPressed: _subiendoFoto ? null : _cambiarFoto,
                      icon: _subiendoFoto
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.photo_camera_outlined, size: 18),
                      label: const Text('Cambiar foto'),
                    ),
                    if (u.tieneFoto)
                      TextButton(
                        onPressed: _subiendoFoto ? null : _quitarFoto,
                        child: const Text('Quitar foto'),
                      ),
                  ]),
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text('PNG, JPG o WEBP · máximo 5 MB',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 11.5)),
                  ),
                  if (_errorFoto != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(_errorFoto!,
                          style: const TextStyle(color: Colors.redAccent)),
                    ),
                  const SizedBox(height: 22),
                  TextFormField(
                    controller: _nombre,
                    decoration: const InputDecoration(labelText: 'Nombre completo'),
                    validator: (v) => (v == null || v.trim().length < 3)
                        ? 'Mínimo 3 caracteres'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _correo,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Correo electrónico'),
                    validator: (v) => (v == null || !v.contains('@'))
                        ? 'Ingresa un correo válido'
                        : null,
                  ),
                  const SizedBox(height: 22),
                  const Text('Cambiar contraseña (opcional)',
                      style: TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _actual,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Contraseña actual'),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _nueva,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Nueva contraseña'),
                    validator: (v) {
                      if (v == null || v.isEmpty) return null;
                      if (v.length < 8) return 'Mínimo 8 caracteres';
                      if (_actual.text.isEmpty) return 'Ingresa tu contraseña actual';
                      return null;
                    },
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                  ],
                  const SizedBox(height: 20),
                  ElevatedButton(
                      onPressed: _guardando ? null : _guardar,
                      child: Text(_guardando ? 'Guardando...' : 'Guardar cambios')),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _cerrarSesion,
                    icon: const Icon(Icons.logout, size: 18),
                    label: const Text('Cerrar sesión'),
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(46)),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

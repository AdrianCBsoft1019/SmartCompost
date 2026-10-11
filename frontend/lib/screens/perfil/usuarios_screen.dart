import 'package:flutter/material.dart';
import '../../models/rol_usuario.dart';
import '../../models/usuario.dart';
import '../../providers/usuario_provider.dart';
import '../../services/session.dart';
import '../../theme/app_theme.dart';
import '../../widgets/avatar_usuario.dart';
import '../../widgets/estado_chip.dart';
import '../../widgets/panel_card.dart';

/// Gestion de perfiles (solo Administrador): crear, editar, asignar rol y
/// desactivar. El backend tambien valida el rol (403 si no es instructor).
class UsuariosScreen extends StatefulWidget {
  const UsuariosScreen({super.key});

  @override
  State<UsuariosScreen> createState() => _UsuariosScreenState();
}

class _UsuariosScreenState extends State<UsuariosScreen> {
  final _provider = UsuarioProvider();

  @override
  void initState() {
    super.initState();
    _provider.cargar();
  }

  @override
  void dispose() {
    _provider.dispose();
    super.dispose();
  }

  void _mensaje(String t, {bool error = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(t), backgroundColor: error ? Colors.red.shade700 : null));

  Future<void> _formulario([Usuario? usuario]) async {
    final datos = await showDialog<_DatosUsuario>(
      context: context,
      builder: (_) => _UsuarioDialog(usuario: usuario),
    );
    if (datos == null) return;
    try {
      if (usuario == null) {
        await _provider.crear(
            nombre: datos.nombre,
            correo: datos.correo,
            password: datos.password,
            rol: datos.rol);
        _mensaje('Perfil creado');
      } else {
        await _provider.actualizar(usuario.id,
            nombre: datos.nombre,
            correo: datos.correo,
            rol: datos.rol,
            activo: datos.activo,
            password: datos.password);
        _mensaje('Perfil actualizado');
      }
    } catch (e) {
      _mensaje(e.toString(), error: true);
    }
  }

  Future<void> _desactivar(Usuario u) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Desactivar perfil'),
        content: Text('${u.nombreCompleto} ya no podrá iniciar sesión. '
            'Puedes reactivarlo editando el perfil.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Desactivar',
                  style: TextStyle(color: EstadoColores.rojo))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _provider.desactivar(u.id);
      _mensaje('Perfil desactivado');
    } catch (e) {
      _mensaje(e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!Session.instance.esAdmin) {
      return const EstadoVacio('Solo el Administrador puede gestionar perfiles.');
    }
    return ListenableBuilder(
      listenable: _provider,
      builder: (context, _) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(spacing: 14, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
            const Text('Perfiles de usuario',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            SizedBox(
              width: 170,
              child: ElevatedButton.icon(
                onPressed: () => _formulario(),
                icon: const Icon(Icons.person_add_alt, size: 18),
                label: const Text('Nuevo perfil'),
              ),
            ),
          ]),
          const SizedBox(height: 16),
          Expanded(child: _contenido()),
        ]),
      ),
    );
  }

  Widget _contenido() {
    if (_provider.cargando && _provider.usuarios.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_provider.error != null) {
      return EstadoVacio(_provider.error!, onReintentar: _provider.cargar);
    }
    final yo = Session.instance.usuario?.id;
    return SingleChildScrollView(
      child: PanelCard(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingTextStyle: const TextStyle(
                color: AppColors.textSecondary, fontWeight: FontWeight.w700),
            columns: const [
              DataColumn(label: Text('Nombre')),
              DataColumn(label: Text('Correo')),
              DataColumn(label: Text('Rol')),
              DataColumn(label: Text('Estado')),
              DataColumn(label: Text('Acciones')),
            ],
            rows: [
              for (final u in _provider.usuarios)
                DataRow(cells: [
                  DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                    AvatarUsuario(usuario: u, radius: 14),
                    const SizedBox(width: 10),
                    Text(u.id == yo ? '${u.nombreCompleto} (tú)' : u.nombreCompleto),
                  ])),
                  DataCell(Text(u.correo)),
                  DataCell(Text(u.esAdmin ? 'Administrador' : 'Estudiante')),
                  DataCell(Text(u.activo ? 'Activo' : 'Inactivo',
                      style: TextStyle(
                          color: u.activo ? EstadoColores.verde : EstadoColores.rojo))),
                  DataCell(Row(children: [
                    IconButton(
                        tooltip: 'Editar',
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        onPressed: () => _formulario(u)),
                    if (u.id != yo && u.activo)
                      IconButton(
                          tooltip: 'Desactivar',
                          icon: const Icon(Icons.person_off_outlined,
                              size: 20, color: EstadoColores.rojo),
                          onPressed: () => _desactivar(u)),
                  ])),
                ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _DatosUsuario {
  final String nombre, correo, password;
  final RolUsuario rol;
  final bool activo;
  const _DatosUsuario(this.nombre, this.correo, this.password, this.rol, this.activo);
}

class _UsuarioDialog extends StatefulWidget {
  final Usuario? usuario;
  const _UsuarioDialog({this.usuario});

  @override
  State<_UsuarioDialog> createState() => _UsuarioDialogState();
}

class _UsuarioDialogState extends State<_UsuarioDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombre;
  late final TextEditingController _correo;
  final _password = TextEditingController();
  late RolUsuario _rol;
  late bool _activo;

  bool get _edicion => widget.usuario != null;

  @override
  void initState() {
    super.initState();
    final u = widget.usuario;
    _nombre = TextEditingController(text: u?.nombreCompleto ?? '');
    _correo = TextEditingController(text: u?.correo ?? '');
    _rol = u?.rol ?? RolUsuario.aprendiz;
    _activo = u?.activo ?? true;
  }

  @override
  void dispose() {
    _nombre.dispose();
    _correo.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final esUnoMismo = widget.usuario?.id == Session.instance.usuario?.id;
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(_edicion ? 'Editar perfil' : 'Nuevo perfil'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextFormField(
                controller: _nombre,
                decoration: const InputDecoration(labelText: 'Nombre completo'),
                validator: (v) =>
                    (v == null || v.trim().length < 3) ? 'Mínimo 3 caracteres' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _correo,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Correo electrónico'),
                validator: (v) =>
                    (v == null || !v.contains('@')) ? 'Correo no válido' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _password,
                obscureText: true,
                decoration: InputDecoration(
                    labelText: _edicion
                        ? 'Nueva contraseña (dejar vacío para no cambiar)'
                        : 'Contraseña (mín. 8)'),
                validator: (v) {
                  if (!_edicion && (v == null || v.length < 8)) {
                    return 'Mínimo 8 caracteres';
                  }
                  if (_edicion && v != null && v.isNotEmpty && v.length < 8) {
                    return 'Mínimo 8 caracteres';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<RolUsuario>(
                value: _rol,
                decoration: const InputDecoration(labelText: 'Rol'),
                items: const [
                  DropdownMenuItem(
                      value: RolUsuario.instructor,
                      child: Text('Administrador (instructor)')),
                  DropdownMenuItem(
                      value: RolUsuario.aprendiz, child: Text('Estudiante (aprendiz)')),
                ],
                onChanged: esUnoMismo ? null : (v) => setState(() => _rol = v!),
              ),
              if (_edicion && !esUnoMismo)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Perfil activo'),
                  value: _activo,
                  activeColor: AppColors.accent,
                  onChanged: (v) => setState(() => _activo = v),
                ),
            ]),
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        SizedBox(
          width: 130,
          child: ElevatedButton(
            onPressed: () {
              if (!_formKey.currentState!.validate()) return;
              Navigator.pop(
                  context,
                  _DatosUsuario(_nombre.text.trim(), _correo.text.trim(),
                      _password.text, _rol, _activo));
            },
            child: Text(_edicion ? 'Guardar' : 'Crear'),
          ),
        ),
      ],
    );
  }
}

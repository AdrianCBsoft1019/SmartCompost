import 'package:flutter/material.dart';
import '../../models/pila.dart';
import '../../models/sensor.dart';
import '../../theme/app_theme.dart';


Future<SensorForm?> mostrarFormularioSensor(
  BuildContext context, {
  Sensor? sensor,
  required List<Pila> pilas,
  Set<String> codigosExistentes = const {},
}) {
  return showDialog<SensorForm>(
    context: context,
    builder: (_) => _SensorFormDialog(
      sensor: sensor,
      pilas: pilas,
      codigosExistentes: codigosExistentes,
    ),
  );
}

class _SensorFormDialog extends StatefulWidget {
  final Sensor? sensor;
  final List<Pila> pilas;


  final Set<String> codigosExistentes;
  const _SensorFormDialog({
    this.sensor,
    required this.pilas,
    this.codigosExistentes = const {},
  });

  @override
  State<_SensorFormDialog> createState() => _SensorFormDialogState();
}

class _SensorFormDialogState extends State<_SensorFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _codigo;
  late String _tipo;
  String? _pilaId;
  late bool _activo;

  /// true cuando el usuario escribió el código él mismo (ya no se sobrescribe).
  bool _codigoEditado = false;

  bool get _edicion => widget.sensor != null;

  @override
  void initState() {
    super.initState();
    final s = widget.sensor;
    _codigo = TextEditingController(text: s?.codigo ?? '');
    _tipo = s?.tipo ?? 'temperatura';
    _activo = s?.activo ?? true;
    // Sensor nuevo: arranca con un código libre según el tipo.
    if (s == null) {
      _codigo.text = Sensor.codigoSugerido(_tipo, widget.codigosExistentes);
    }
    // Solo preselecciona la pila si todavia existe en la lista.
    if (s != null && widget.pilas.any((p) => p.id == s.pilaId)) {
      _pilaId = s.pilaId;
    }
  }

  @override
  void dispose() {
    _codigo.dispose();
    super.dispose();
  }

  void _cambiarTipo(String? v) {
    if (v == null) return;
    setState(() {
      _tipo = v;
      // En un sensor nuevo el código sugerido sigue al tipo mientras el
      // usuario no lo haya escrito él mismo.
      if (!_edicion && !_codigoEditado) {
        _codigo.text = Sensor.codigoSugerido(v, widget.codigosExistentes);
      }
    });
  }

  void _guardar() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(SensorForm(
      tipo: _tipo,
      codigo: _codigo.text.trim(),
      pilaId: _pilaId!,
      activo: _activo,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(_edicion ? 'Editar sensor' : 'Nuevo sensor'),
      content: SizedBox(
        width: 420,
        child: widget.pilas.isEmpty
            ? const Text(
                'Todavía no hay pilas. Crea una pila primero para poder '
                'asignarle un sensor.',
                style: TextStyle(color: AppColors.textSecondary),
              )
            : Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: _codigo,
                        decoration: InputDecoration(
                          labelText: 'Código del dispositivo (ej. TMP-A102)',
                          helperText: !_edicion && !_codigoEditado
                              ? 'Sugerido según el tipo; puedes cambiarlo'
                              : null,
                        ),
                        onChanged: (v) =>
                            setState(() => _codigoEditado = v.trim().isNotEmpty),
                        validator: (v) {
                          final t = (v ?? '').trim();
                          if (t.length < 3) return 'Mínimo 3 caracteres';
                          if (t.length > 60) return 'Máximo 60 caracteres';
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        initialValue: _tipo,
                        decoration:
                            const InputDecoration(labelText: 'Tipo de sensor'),
                        dropdownColor: AppColors.surfaceInput,
                        items: [
                          for (final e in Sensor.tipos.entries)
                            DropdownMenuItem(value: e.key, child: Text(e.value)),
                        ],
                        onChanged: _cambiarTipo,
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        initialValue : _pilaId,
                        isExpanded: true,
                        decoration:
                            const InputDecoration(labelText: 'Pila asignada'),
                        dropdownColor: AppColors.surfaceInput,
                        items: [
                          for (final p in widget.pilas)
                            DropdownMenuItem(
                              value: p.id,
                              child: Text(
                                '${p.nombre} · ${p.ubicacion ?? 'Sin ubicación'}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        validator: (v) => v == null ? 'Selecciona una pila' : null,
                        onChanged: (v) => setState(() => _pilaId = v),
                      ),
                      const SizedBox(height: 6),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Sensor activo'),
                        value: _activo,
                        activeThumbColor: Colors.green,
                        onChanged: (v) => setState(() => _activo = v),
                      ),
                    ],
                  ),
                ),
              ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar')),
        if (widget.pilas.isNotEmpty)
          SizedBox(
            width: 150,
            child: ElevatedButton(
                onPressed: _guardar,
                child: Text(_edicion ? 'Guardar' : 'Crear sensor')),
          ),
      ],
    );
  }
}

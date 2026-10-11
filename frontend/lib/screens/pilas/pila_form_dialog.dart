import 'package:flutter/material.dart';
import '../../models/pila.dart';
import '../../theme/app_theme.dart';

/// Dialogo para crear o editar una pila. Devuelve un [PilaForm] o null
/// si se cancela. Con `pila != null` entra en modo edicion.
Future<PilaForm?> mostrarFormularioPila(
  BuildContext context, {
  Pila? pila,
  List<String> ubicaciones = const [],
}) {
  return showDialog<PilaForm>(
    context: context,
    builder: (_) => _PilaFormDialog(pila: pila, ubicaciones: ubicaciones),
  );
}

class _PilaFormDialog extends StatefulWidget {
  final Pila? pila;
  final List<String> ubicaciones;
  const _PilaFormDialog({this.pila, required this.ubicaciones});

  @override
  State<_PilaFormDialog> createState() => _PilaFormDialogState();
}

class _PilaFormDialogState extends State<_PilaFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombre;
  late final TextEditingController _ubicacion;
  late final TextEditingController _dias;
  late DateTime _inicio;

  bool get _edicion => widget.pila != null;

  @override
  void initState() {
    super.initState();
    final p = widget.pila;
    _nombre = TextEditingController(text: p?.nombre ?? '');
    _ubicacion = TextEditingController(text: p?.ubicacion ?? '');
    _dias = TextEditingController(text: '${p?.diasCiclo ?? 90}');
    _inicio = p?.fechaInicio.toLocal() ?? DateTime.now();
  }

  @override
  void dispose() {
    _nombre.dispose();
    _ubicacion.dispose();
    _dias.dispose();
    super.dispose();
  }

  Future<void> _elegirFecha() async {
    final f = await showDatePicker(
      context: context,
      initialDate: _inicio,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (f != null) setState(() => _inicio = f);
  }

  void _guardar() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(PilaForm(
      nombre: _nombre.text.trim(),
      ubicacion: _ubicacion.text.trim(),
      diasCiclo: int.parse(_dias.text.trim()),
      fechaInicio: _inicio,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(_edicion ? 'Editar pila' : 'Nueva pila'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nombre,
                  decoration: const InputDecoration(labelText: 'Nombre (ej. Pila A-102)'),
                  validator: (v) => (v == null || v.trim().length < 2)
                      ? 'Mínimo 2 caracteres'
                      : null,
                ),
                const SizedBox(height: 14),
                Autocomplete<String>(
                  initialValue: TextEditingValue(text: _ubicacion.text),
                  optionsBuilder: (v) => widget.ubicaciones.where(
                    (u) => u.toLowerCase().contains(v.text.toLowerCase()),
                  ),
                  onSelected: (v) => _ubicacion.text = v,
                  fieldViewBuilder: (context, ctrl, foco, _) {
                    ctrl.addListener(() => _ubicacion.text = ctrl.text);
                    return TextFormField(
                      controller: ctrl,
                      focusNode: foco,
                      decoration: const InputDecoration(
                          labelText: 'Ubicación / Planta (ej. Planta Norte)'),
                    );
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _dias,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Duración del ciclo (días, 30–365)'),
                  validator: (v) {
                    final n = int.tryParse(v ?? '');
                    return (n == null || n < 30 || n > 365)
                        ? 'Ingresa un número entre 30 y 365'
                        : null;
                  },
                ),
                const SizedBox(height: 14),
                InkWell(
                  onTap: _elegirFecha,
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Fecha de inicio'),
                    child: Text(
                      '${_inicio.day.toString().padLeft(2, '0')}/'
                      '${_inicio.month.toString().padLeft(2, '0')}/${_inicio.year}',
                    ),
                  ),
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
        SizedBox(
          width: 140,
          child: ElevatedButton(
              onPressed: _guardar,
              child: Text(_edicion ? 'Guardar' : 'Crear pila')),
        ),
      ],
    );
  }
}

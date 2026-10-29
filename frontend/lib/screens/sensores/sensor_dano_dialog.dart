import 'package:flutter/material.dart';
import '../../models/sensor.dart';
import '../../theme/app_theme.dart';
import '../../widgets/estado_chip.dart';


Future<String?> mostrarDialogoDano(BuildContext context, Sensor sensor) {
  return showDialog<String>(
    context: context,
    builder: (_) => _DialogoDano(sensor: sensor),
  );
}

class _DialogoDano extends StatefulWidget {
  final Sensor sensor;
  const _DialogoDano({required this.sensor});

  @override
  State<_DialogoDano> createState() => _DialogoDanoState();
}

class _DialogoDanoState extends State<_DialogoDano> {
  static const _sugerencias = [
    'Sin señal o sin lecturas',
    'Lecturas erróneas',
    'Daño físico',
    'Batería agotada',
  ];

  final _formKey = GlobalKey<FormState>();
  final _detalle = TextEditingController();

  @override
  void dispose() {
    _detalle.dispose();
    super.dispose();
  }

  void _enviar() {
    if (_formKey.currentState!.validate()) {
      Navigator.pop(context, _detalle.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.sensor;
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text('Reportar daño del sensor'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sensor ${s.codigo} · pila ${s.pilaNombre ?? '--'}. '
                'Se enviará una notificación a todos los usuarios indicando '
                'que se requiere su arreglo para continuar el proceso.',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final t in _sugerencias)
                  ActionChip(
                    label: Text(t, style: const TextStyle(fontSize: 12)),
                    onPressed: () => setState(() => _detalle.text = t),
                  ),
              ]),
              const SizedBox(height: 12),
              TextFormField(
                controller: _detalle,
                autofocus: true,
                maxLines: 3,
                maxLength: 255,
                decoration: const InputDecoration(
                  labelText: 'Descripción del daño',
                  hintText: 'Ej.: sin lectura desde hace 3 horas',
                ),
                validator: (v) => (v ?? '').trim().length < 5
                    ? 'Describe el daño (mínimo 5 caracteres)'
                    : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar')),
        TextButton(
            onPressed: _enviar,
            child: const Text('Notificar daño',
                style: TextStyle(color: EstadoColores.rojo))),
      ],
    );
  }
}

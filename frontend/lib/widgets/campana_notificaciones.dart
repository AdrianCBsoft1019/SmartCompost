import 'package:flutter/material.dart';
import '../models/notificacion.dart';
import '../providers/notificaciones_provider.dart';
import '../services/session.dart';
import '../theme/app_theme.dart';
import 'estado_chip.dart';


class IconoCampana extends StatelessWidget {
  const IconoCampana({super.key});

  @override
  Widget build(BuildContext context) {
    final avisos = NotificacionesProvider.instance;
    return ListenableBuilder(
      listenable: avisos,
      builder: (context, _) => Badge(
        isLabelVisible: avisos.total > 0,
        label: Text('${avisos.total}'),
        backgroundColor: EstadoColores.rojo,
        child: Icon(avisos.total > 0
            ? Icons.notifications_active
            : Icons.notifications_none_outlined),
      ),
    );
  }
}

/// Botón de campana para la barra superior: abre el panel de notificaciones.
class CampanaNotificaciones extends StatelessWidget {
  const CampanaNotificaciones({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Notificaciones',
      onPressed: () => mostrarNotificaciones(context),
      icon: const IconoCampana(),
    );
  }
}

Future<void> mostrarNotificaciones(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const _PanelNotificaciones(),
  );
}

class _PanelNotificaciones extends StatefulWidget {
  const _PanelNotificaciones();

  @override
  State<_PanelNotificaciones> createState() => _PanelNotificacionesState();
}

class _PanelNotificacionesState extends State<_PanelNotificaciones> {
  final _avisos = NotificacionesProvider.instance;
  String? _ocupado; // id del sensor que se está marcando como reparado

  Future<void> _reparado(Notificacion n) async {
    setState(() => _ocupado = n.sensorId);
    try {
      await _avisos.marcarReparado(n.sensorId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sensor ${n.sensorCodigo} marcado como reparado')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red.shade700),
      );
    } finally {
      if (mounted) setState(() => _ocupado = null);
    }
  }

  String _fecha(DateTime? f) {
    if (f == null) return '';
    final l = f.toLocal();
    String dos(int v) => v.toString().padLeft(2, '0');
    return '${dos(l.day)}/${dos(l.month)}/${l.year} ${dos(l.hour)}:${dos(l.minute)}';
  }

  Widget _item(Notificacion n) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: EstadoColores.rojo,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text('SENSOR DAÑADO',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4)),
        ),
        const Spacer(),
        Text(_fecha(n.fecha),
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
      ]),
      const SizedBox(height: 8),
      Text('${n.sensorCodigo} · ${n.pilaNombre}',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
      const SizedBox(height: 4),
      Text(n.mensaje,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
      if (Session.instance.esAdmin)
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _ocupado == n.sensorId ? null : () => _reparado(n),
            icon: const Icon(Icons.build_circle_outlined, size: 18),
            label: const Text('Marcar como reparado'),
          ),
        ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Row(children: [
        Icon(Icons.warning_amber_rounded, color: EstadoColores.rojo),
        SizedBox(width: 8),
        Text('Notificaciones'),
      ]),
      content: SizedBox(
        width: 460,
        child: ListenableBuilder(
          listenable: _avisos,
          builder: (context, _) {
            if (_avisos.notificaciones.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text(
                    'No hay notificaciones. Todos los sensores funcionan con normalidad.',
                    style: TextStyle(color: AppColors.textSecondary)),
              );
            }
            return ListView.separated(
              shrinkWrap: true,
              itemCount: _avisos.notificaciones.length,
              separatorBuilder: (_, __) => const Divider(height: 28),
              itemBuilder: (_, i) => _item(_avisos.notificaciones[i]),
            );
          },
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
      ],
    );
  }
}

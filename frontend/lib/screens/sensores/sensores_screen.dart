import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/sensor.dart';
import '../../providers/sensor_provider.dart';
import '../../services/session.dart';
import '../../theme/app_theme.dart';
import '../../widgets/estado_chip.dart';
import '../../widgets/panel_card.dart';
import 'sensor_form_dialog.dart';

/// Vista de Sensores: tarjetas con filtros por tipo, estado y pila.
/// El instructor (admin) crea, edita, activa/desactiva y elimina; el
/// aprendiz solo consulta.
class SensoresScreen extends StatefulWidget {
  const SensoresScreen({super.key});

  @override
  State<SensoresScreen> createState() => _SensoresScreenState();
}

class _SensoresScreenState extends State<SensoresScreen> {
  final _provider = SensorProvider();
  Timer? _debounce;

  bool get _admin => Session.instance.esAdmin;

  @override
  void initState() {
    super.initState();
    _provider.cargarPilas();
    _provider.cargar();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _provider.dispose();
    super.dispose();
  }

  void _mensaje(String texto, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(texto),
      backgroundColor: error ? Colors.red.shade700 : null,
    ));
  }

  Future<void> _crear() async {
    final form = await mostrarFormularioSensor(context, pilas: _provider.pilas);
    if (form == null) return;
    try {
      await _provider.crear(form);
      _mensaje('Sensor creado');
    } catch (e) {
      _mensaje(e.toString(), error: true);
    }
  }

  Future<void> _editar(Sensor sensor) async {
    final form = await mostrarFormularioSensor(context,
        sensor: sensor, pilas: _provider.pilas);
    if (form == null) return;
    try {
      await _provider.actualizar(sensor.id, form);
      _mensaje('Sensor actualizado');
    } catch (e) {
      _mensaje(e.toString(), error: true);
    }
  }

  Future<void> _cambiarEstado(Sensor sensor) async {
    try {
      await _provider.cambiarActivo(sensor);
      _mensaje(sensor.activo ? 'Sensor desactivado' : 'Sensor activado');
    } catch (e) {
      _mensaje(e.toString(), error: true);
    }
  }

  Future<void> _eliminar(Sensor sensor) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Eliminar sensor'),
        content: Text('¿Eliminar el sensor "${sensor.codigo}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Eliminar',
                  style: TextStyle(color: EstadoColores.rojo))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _provider.eliminar(sensor.id);
      _mensaje('Sensor eliminado');
    } catch (e) {
      _mensaje(e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _provider,
      builder: (context, _) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _barraSuperior(),
            const SizedBox(height: 16),
            _filtros(),
            const SizedBox(height: 16),
            Expanded(child: _contenido()),
          ],
        ),
      ),
    );
  }

  Widget _barraSuperior() {
    return Wrap(
      spacing: 12,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Text('Sensores',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        SizedBox(
          width: 260,
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Buscar por código...',
              prefixIcon: Icon(Icons.search, size: 20),
            ),
            onChanged: (t) {
              _debounce?.cancel();
              _debounce = Timer(
                  const Duration(milliseconds: 350), () => _provider.buscar(t));
            },
          ),
        ),
        if (_admin)
          SizedBox(
            width: 170,
            child: ElevatedButton.icon(
              onPressed: _crear,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Nuevo Sensor'),
            ),
          ),
      ],
    );
  }

  Widget _chip(String texto, bool activo, VoidCallback onTap, {IconData? icono}) {
    return Padding(
      padding: const EdgeInsets.only(right: 8, bottom: 8),
      child: ChoiceChip(
        avatar: icono == null ? null : Icon(icono, size: 16),
        label: Text(texto),
        selected: activo,
        onSelected: (_) => onTap(),
        selectedColor: AppColors.accentDark,
        labelStyle: TextStyle(
            color: activo ? Colors.white : AppColors.textSecondary, fontSize: 13),
        backgroundColor: AppColors.surfaceInput,
        side: const BorderSide(color: AppColors.border),
        showCheckmark: false,
      ),
    );
  }

  Widget _etiquetaFiltro(String texto) => Padding(
        padding: const EdgeInsets.only(right: 12, bottom: 8),
        child: Text(texto,
            style: const TextStyle(
                color: AppColors.textMuted, fontSize: 11, letterSpacing: 0.6)),
      );

  Widget _filtros() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
        _etiquetaFiltro('TIPO'),
        _chip('Todos', _provider.tipo == null, () => _provider.filtrarTipo(null)),
        for (final e in Sensor.tipos.entries)
          _chip(e.value, _provider.tipo == e.key,
              () => _provider.filtrarTipo(_provider.tipo == e.key ? null : e.key),
              icono: _icono(e.key)),
      ]),
      Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
        _etiquetaFiltro('ESTADO'),
        _chip('Todos', _provider.activo == null, () => _provider.filtrarActivo(null)),
        _chip('Activos', _provider.activo == true,
            () => _provider.filtrarActivo(_provider.activo == true ? null : true)),
        _chip('Inactivos', _provider.activo == false,
            () => _provider.filtrarActivo(_provider.activo == false ? null : false)),
      ]),
      if (_provider.pilas.isNotEmpty)
        Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
          _etiquetaFiltro('PILA'),
          for (final p in _provider.pilas)
            _chip(p.nombre, _provider.pilaId == p.id,
                () => _provider.filtrarPila(p.id),
                icono: Icons.eco_outlined),
        ]),
    ]);
  }

  Widget _contenido() {
    if (_provider.cargando && _provider.sensores.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_provider.error != null) {
      return EstadoVacio(_provider.error!, onReintentar: _provider.cargar);
    }
    if (_provider.sensores.isEmpty && !_admin) {
      return const EstadoVacio('No hay sensores que coincidan con los filtros.');
    }
    // Altura fija por tarjeta (mainAxisExtent) para que el menu de 3 puntos
    // del admin no desborde la tarjeta.
    return GridView(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 320,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        mainAxisExtent: 235,
      ),
      children: [
        for (final s in _provider.sensores) _tarjeta(s),
        if (_admin) _tarjetaNueva(),
      ],
    );
  }

  IconData _icono(String tipo) {
    switch (tipo) {
      case 'temperatura':
        return Icons.thermostat;
      case 'humedad':
        return Icons.water_drop_outlined;
      case 'gas_ch4':
        return Icons.cloud_outlined;
      case 'ph':
        return Icons.science_outlined;
      case 'nivel_agua':
        return Icons.waves;
      default:
        return Icons.sensors;
    }
  }

  Widget _chipEstado(bool activo) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: activo ? EstadoColores.verde : AppColors.textMuted,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        activo ? 'ACTIVO' : 'INACTIVO',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _dato(String etiqueta, String valor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(etiqueta,
              style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(valor,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }

  String _fecha(DateTime f) {
    final l = f.toLocal();
    return '${l.day.toString().padLeft(2, '0')}/'
        '${l.month.toString().padLeft(2, '0')}/${l.year}';
  }

  Widget _tarjeta(Sensor s) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _chipEstado(s.activo),
          const Spacer(),
          if (_admin)
            PopupMenuButton<String>(
              tooltip: 'Acciones',
              icon: const Icon(Icons.more_vert, size: 20),
              onSelected: (v) {
                if (v == 'editar') _editar(s);
                if (v == 'estado') _cambiarEstado(s);
                if (v == 'eliminar') _eliminar(s);
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'editar', child: Text('Editar')),
                PopupMenuItem(
                    value: 'estado',
                    child: Text(s.activo ? 'Desactivar' : 'Activar')),
                const PopupMenuItem(value: 'eliminar', child: Text('Eliminar')),
              ],
            ),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_icono(s.tipo), color: AppColors.accent, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.codigo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              Text(s.tipoLabel,
                  style: const TextStyle(color: AppColors.accent, fontSize: 12.5)),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          _dato('PILA', s.pilaNombre ?? '--'),
          const SizedBox(width: 8),
          _dato('PLANTA', s.ubicacion ?? '--'),
        ]),
        const SizedBox(height: 8),
        Text('Registrado el ${_fecha(s.creadoEn)}',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
      ]),
    );
  }

  Widget _tarjetaNueva() {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: _crear,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border, width: 1.5),
        ),
        child: const Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.add_circle_outline, size: 44, color: AppColors.textSecondary),
            SizedBox(height: 10),
            Text('Agregar nuevo sensor',
                style: TextStyle(
                    color: AppColors.textSecondary, fontWeight: FontWeight.w700)),
            SizedBox(height: 4),
            Text('Definir tipo, código y pila',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ]),
        ),
      ),
    );
  }
}

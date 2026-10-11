import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/pila.dart';
import '../../providers/pila_provider.dart';
import '../../services/session.dart';
import '../../theme/app_theme.dart';
import '../../widgets/estado_chip.dart';
import '../../widgets/panel_card.dart';
import 'pila_detalle_screen.dart';
import 'pila_form_dialog.dart';

/// Vista de Pilas: tarjetas con filtros por fase/ubicacion y busqueda.
/// El instructor (admin) crea, edita y elimina; el aprendiz solo consulta.
class PilasScreen extends StatefulWidget {
  const PilasScreen({super.key});

  @override
  State<PilasScreen> createState() => _PilasScreenState();
}

class _PilasScreenState extends State<PilasScreen> {
  final _provider = PilaProvider();
  Timer? _debounce;

  bool get _admin => Session.instance.esAdmin;

  @override
  void initState() {
    super.initState();
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
    final form = await mostrarFormularioPila(context,
        ubicaciones: _provider.ubicaciones);
    if (form == null) return;
    try {
      await _provider.crear(form);
      _mensaje('Pila creada');
    } catch (e) {
      _mensaje(e.toString(), error: true);
    }
  }

  Future<void> _editar(Pila pila) async {
    final form = await mostrarFormularioPila(context,
        pila: pila, ubicaciones: _provider.ubicaciones);
    if (form == null) return;
    try {
      await _provider.actualizar(pila.id, form);
      _mensaje('Pila actualizada');
    } catch (e) {
      _mensaje(e.toString(), error: true);
    }
  }

  Future<void> _eliminar(Pila pila) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Eliminar pila'),
        content: Text(
            '¿Eliminar "${pila.nombre}"? Se borrarán también sus sensores y lecturas.'),
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
      await _provider.eliminar(pila.id);
      _mensaje('Pila eliminada');
    } catch (e) {
      _mensaje(e.toString(), error: true);
    }
  }

  void _abrirDetalle(Pila pila) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PilaDetalleScreen(pilaId: pila.id, titulo: pila.nombre),
    ));
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
        const Text('Pilas de Compostaje',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        SizedBox(
          width: 260,
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Buscar pila...',
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
            width: 150,
            child: ElevatedButton.icon(
              onPressed: _crear,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Nueva Pila'),
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

  Widget _filtros() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
        const Padding(
          padding: EdgeInsets.only(right: 12, bottom: 8),
          child: Text('FASE DE MADURACIÓN',
              style: TextStyle(
                  color: AppColors.textMuted, fontSize: 11, letterSpacing: 0.6)),
        ),
        _chip('Todas', _provider.fase == null, () => _provider.filtrarFase(null)),
        for (final e in Pila.fases.entries)
          _chip(e.value, _provider.fase == e.key,
              () => _provider.filtrarFase(_provider.fase == e.key ? null : e.key)),
      ]),
      if (_provider.ubicaciones.isNotEmpty)
        Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
          const Padding(
            padding: EdgeInsets.only(right: 12, bottom: 8),
            child: Text('UBICACIÓN',
                style: TextStyle(
                    color: AppColors.textMuted, fontSize: 11, letterSpacing: 0.6)),
          ),
          for (final u in _provider.ubicaciones)
            _chip(u, _provider.ubicacion == u, () => _provider.filtrarUbicacion(u),
                icono: Icons.place_outlined),
        ]),
    ]);
  }

  Widget _contenido() {
    if (_provider.cargando && _provider.pilas.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_provider.error != null) {
      return EstadoVacio(_provider.error!, onReintentar: _provider.cargar);
    }
    if (_provider.pilas.isEmpty && !_admin) {
      return const EstadoVacio('No hay pilas que coincidan con los filtros.');
    }
    return GridView.extent(
      maxCrossAxisExtent: 320,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.05,
      children: [
        for (final p in _provider.pilas) _tarjeta(p),
        if (_admin) _tarjetaNueva(),
      ],
    );
  }

  Widget _dato(String etiqueta, String valor, Color color) {
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
              style: TextStyle(
                  color: color, fontSize: 18, fontWeight: FontWeight.w800)),
        ]),
      ),
    );
  }

  Widget _tarjeta(Pila p) {
    final tempFuera = p.temperatura != null && p.temperatura! > 70;
    final humFuera = p.humedad != null && (p.humedad! < 40 || p.humedad! > 65);
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _abrirDetalle(p),
      child: PanelCard(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            EstadoChip(p.estado),
            const Spacer(),
            if (_admin)
              PopupMenuButton<String>(
                tooltip: 'Acciones',
                icon: const Icon(Icons.more_vert, size: 20),
                onSelected: (v) => v == 'editar' ? _editar(p) : _eliminar(p),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'editar', child: Text('Editar')),
                  PopupMenuItem(value: 'eliminar', child: Text('Eliminar')),
                ],
              ),
          ]),
          const SizedBox(height: 8),
          Text(p.nombre,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text('${p.faseLabel} · ${p.ubicacion ?? 'Sin ubicación'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.accent, fontSize: 12.5)),
          const Spacer(),
          Row(children: [
            _dato(
                'TEMPERATURA',
                p.temperatura == null ? '--' : '${p.temperatura!.toStringAsFixed(1)}°C',
                tempFuera ? EstadoColores.rojo : AppColors.textPrimary),
            const SizedBox(width: 8),
            _dato(
                'HUMEDAD',
                p.humedad == null ? '--' : '${p.humedad!.toStringAsFixed(0)}%',
                humFuera ? EstadoColores.amarillo : AppColors.textPrimary),
          ]),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('PROGRESO DE MADURACIÓN',
                style: TextStyle(color: AppColors.textMuted, fontSize: 9.5)),
            Text('${p.madurezPct.toStringAsFixed(0)}%',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
          ]),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: p.madurezPct / 100,
              minHeight: 6,
              backgroundColor: AppColors.border,
              color: AppColors.accent,
            ),
          ),
        ]),
      ),
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
            Text('Agregar nueva pila',
                style: TextStyle(
                    color: AppColors.textSecondary, fontWeight: FontWeight.w700)),
            SizedBox(height: 4),
            Text('Definir ciclo y ubicación',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ]),
        ),
      ),
    );
  }
}

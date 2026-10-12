import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../models/alerta.dart';
import '../../models/sensor.dart';
import '../../providers/alertas_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/descarga.dart';
import '../../widgets/estado_chip.dart';
import '../../widgets/panel_card.dart';

/// Vista de Alertas. Es la misma para Administrador y Estudiante: todo es
/// de solo lectura (periodo, filtros y descarga del PDF).
class AlertasScreen extends StatefulWidget {
  const AlertasScreen({super.key});

  @override
  State<AlertasScreen> createState() => _AlertasScreenState();
}

class _AlertasScreenState extends State<AlertasScreen> {
  final _provider = AlertasProvider();
  bool _descargando = false;

  // Variables que el backend puede marcar fuera de limite (en este orden).
  static const _variables = [
    'temperatura',
    'humedad',
    'co2_ppm',
    'ch4_ppm',
    'nh3_ppm',
  ];
  static const _etiquetas = {
    'temperatura': 'Temperatura',
    'humedad': 'Humedad',
    'co2_ppm': 'CO₂',
    'ch4_ppm': 'CH₄',
    'nh3_ppm': 'NH₃',
  };
  static const _cortas = {
    'temperatura': 'Temp',
    'humedad': 'Hum',
    'co2_ppm': 'CO₂',
    'ch4_ppm': 'CH₄',
    'nh3_ppm': 'NH₃',
  };
  static const _colores = {
    'temperatura': EstadoColores.rojo,
    'humedad': EstadoColores.azul,
    'co2_ppm': AppColors.accent,
    'ch4_ppm': EstadoColores.amarillo,
    'nh3_ppm': Color(0xFFA855F7),
  };

  Color _color(String variable) => _colores[variable] ?? AppColors.accent;

  @override
  void initState() {
    super.initState();
    _provider.cargarPilas();
    _provider.cargar();
  }

  @override
  void dispose() {
    _provider.dispose();
    super.dispose();
  }

  Future<void> _descargarPdf() async {
    setState(() => _descargando = true);
    try {
      final bytes = await _provider.descargarPdf();
      guardarArchivo(bytes, 'alertas_${_provider.periodo}.pdf');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.toString()), backgroundColor: Colors.red.shade700));
      }
    } finally {
      if (mounted) setState(() => _descargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _provider,
      builder: (context, _) {
        final r = _provider.resumen;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: _encabezado(),
          ),
          Expanded(
            child: _provider.error != null
                ? EstadoVacio(_provider.error!, onReintentar: _provider.cargar)
                : (r == null
                    ? const Center(child: CircularProgressIndicator())
                    : Stack(children: [
                        SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: _contenido(r),
                        ),
                        if (_provider.cargando)
                          const Positioned(
                              top: 0,
                              left: 0,
                              right: 0,
                              child: LinearProgressIndicator(minHeight: 2)),
                      ])),
          ),
        ]);
      },
    );
  }

  Widget _encabezado() {
    return Wrap(
      spacing: 14,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Text('Alertas',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        SegmentedButton<String>(
          showSelectedIcon: false,
          segments: [
            for (final e in AlertasProvider.periodos.entries)
              ButtonSegment(value: e.key, label: Text(e.value)),
          ],
          selected: {_provider.periodo},
          onSelectionChanged: (s) => _provider.cambiarPeriodo(s.first),
        ),
        SizedBox(
          width: 170,
          child: ElevatedButton.icon(
            onPressed: _descargando ? null : _descargarPdf,
            icon: _descargando
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                : const Icon(Icons.download, size: 18),
            label: const Text('Descargar PDF'),
          ),
        ),
      ],
    );
  }

  Widget _contenido(AlertasResumen r) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 14, runSpacing: 14, children: [
        _kpi('Alertas del periodo', '${r.totalAlertas}',
            Icons.notifications_outlined),
        _kpi('Alertas activas', '${r.alertasActivas}',
            Icons.notifications_active_outlined,
            color: r.alertasActivas == 0 ? null : EstadoColores.rojo),
        _kpi('Lecturas fuera de límite', '${r.lecturasFueraDeLimite}',
            Icons.warning_amber_rounded),
        _kpi('% fuera de límite',
            '${r.porcentajeFueraDeLimite.toStringAsFixed(1)} %',
            Icons.percent),
      ]),
      const SizedBox(height: 16),
      _doble(_porDia(r), _porVariable(r), flexIzq: 3, flexDer: 2),
      const SizedBox(height: 16),
      _doble(_porPila(r), _porSensor(r), flexIzq: 1, flexDer: 1),
      const SizedBox(height: 16),
      _historial(),
    ]);
  }

  /// Dos paneles lado a lado en pantallas anchas; apilados en las angostas.
  Widget _doble(Widget a, Widget b, {required int flexIzq, required int flexDer}) {
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth < 900) {
        return Column(children: [a, const SizedBox(height: 16), b]);
      }
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(flex: flexIzq, child: a),
        const SizedBox(width: 16),
        Expanded(flex: flexDer, child: b),
      ]);
    });
  }

  Widget _kpi(String titulo, String valor, IconData icono, {Color? color}) {
    return SizedBox(
      width: 200,
      child: PanelCard(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child: Text(titulo,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12.5))),
            Icon(icono, size: 18, color: color ?? AppColors.accent),
          ]),
          const SizedBox(height: 8),
          Text(valor,
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: color ?? AppColors.textPrimary)),
        ]),
      ),
    );
  }

  // ------------------------------------------------------------ GRAFICAS

  /// Tope del eje Y: deja un margen sobre el valor maximo (minimo 4).
  double _techo(int maximo) =>
      (maximo < 4 ? 4 : (maximo * 1.15).ceil()).toDouble();

  Widget _textoEje(String t) =>
      Text(t, style: const TextStyle(color: AppColors.textMuted, fontSize: 10));

  Widget _porDia(AlertasResumen r) {
    final d = r.porDia;
    final maxY = _techo(d.fold<int>(0, (m, e) => e.total > m ? e.total : m));
    final paso = math.max(1, (d.length / 6).ceil());
    return PanelCard(
      titulo: 'Alertas por día',
      subtitulo: 'Cantidad de variables fuera de límite en cada día',
      child: SizedBox(
        height: 240,
        child: d.length < 2
            ? const EstadoVacio('Aún no hay suficientes días para graficar.')
            : LineChart(LineChartData(
                minY: 0,
                maxY: maxY,
                gridData: FlGridData(
                  drawVerticalLine: false,
                  horizontalInterval: (maxY / 4).ceilToDouble(),
                  getDrawingHorizontalLine: (_) =>
                      const FlLine(color: AppColors.border, strokeWidth: 0.6),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: (maxY / 4).ceilToDouble(),
                      getTitlesWidget: (v, _) => _textoEje('${v.toInt()}'),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: paso.toDouble(),
                      getTitlesWidget: (v, _) {
                        final i = v.toInt();
                        if (i < 0 || i >= d.length) return const SizedBox();
                        final f = d[i].fecha; // AAAA-MM-DD
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: _textoEje(f.length >= 10 ? f.substring(5) : f),
                        );
                      },
                    ),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: [
                      for (var i = 0; i < d.length; i++)
                        FlSpot(i.toDouble(), d[i].total.toDouble()),
                    ],
                    color: EstadoColores.rojo,
                    barWidth: 2.5,
                    dotData: FlDotData(show: d.length <= 14),
                    belowBarData: BarAreaData(
                        show: true, color: EstadoColores.rojo.withOpacity(0.12)),
                  ),
                ],
              )),
      ),
    );
  }

  Widget _porVariable(AlertasResumen r) {
    final v = r.porVariable;
    final maxY = _techo(v.fold<int>(0, (m, e) => e.total > m ? e.total : m));
    return PanelCard(
      titulo: 'Alertas por variable',
      subtitulo: 'Qué medición se sale más de los límites',
      child: SizedBox(
        height: 240,
        child: v.isEmpty
            ? const _SinAlertas()
            : BarChart(BarChartData(
                maxY: maxY,
                alignment: BarChartAlignment.spaceAround,
                gridData: FlGridData(
                  drawVerticalLine: false,
                  horizontalInterval: (maxY / 4).ceilToDouble(),
                  getDrawingHorizontalLine: (_) =>
                      const FlLine(color: AppColors.border, strokeWidth: 0.6),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: (maxY / 4).ceilToDouble(),
                      getTitlesWidget: (x, _) => _textoEje('${x.toInt()}'),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (x, _) {
                        final i = x.toInt();
                        if (i < 0 || i >= v.length) return const SizedBox();
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(_cortas[v[i].variable] ?? v[i].nombre,
                              style: const TextStyle(
                                  color: AppColors.textSecondary, fontSize: 11)),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < v.length; i++)
                    BarChartGroupData(x: i, barRods: [
                      BarChartRodData(
                          toY: v[i].total.toDouble(),
                          color: _color(v[i].variable),
                          width: 26,
                          borderRadius: BorderRadius.circular(4)),
                    ]),
                ],
              )),
      ),
    );
  }

  Widget _porPila(AlertasResumen r) {
    final maximo = r.porPila.isEmpty ? 0 : r.porPila.first.total;
    return PanelCard(
      titulo: 'Alertas por pila',
      subtitulo: 'Pilas con más variables fuera de límite',
      child: r.porPila.isEmpty
          ? const _SinAlertas()
          : Column(children: [
              for (final p in r.porPila)
                _FilaBarra(
                    titulo: p.pila,
                    detalle: p.ubicacion,
                    total: p.total,
                    maximo: maximo,
                    color: EstadoColores.amarillo),
            ]),
    );
  }

  Widget _porSensor(AlertasResumen r) {
    final sensores = r.porSensor.take(8).toList();
    final maximo = sensores.isEmpty ? 0 : sensores.first.total;
    return PanelCard(
      titulo: 'Alertas por sensor',
      subtitulo: 'Sensores asociados a más alertas (CO₂ y NH₃ no tienen sensor propio)',
      child: sensores.isEmpty
          ? const _SinAlertas()
          : Column(children: [
              for (final s in sensores)
                _FilaBarra(
                    titulo: s.codigo,
                    detalle: '${Sensor.tipos[s.tipo] ?? s.tipo} · ${s.pila}',
                    total: s.total,
                    maximo: maximo,
                    color: EstadoColores.azul),
            ]),
    );
  }

  // ----------------------------------------------------------- HISTORIAL

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
        _etiquetaFiltro('VARIABLE'),
        _chip('Todas', _provider.variable == null,
            () => _provider.filtrarVariable(null)),
        for (final v in _variables)
          _chip(_etiquetas[v] ?? v, _provider.variable == v,
              () => _provider.filtrarVariable(v)),
      ]),
      if (_provider.pilas.isNotEmpty)
        Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
          _etiquetaFiltro('PILA'),
          for (final p in _provider.pilas)
            _chip(p.nombre, _provider.pilaId == p.id,
                () => _provider.filtrarPila(p.id),
                icono: Icons.eco_outlined),
        ]),
      Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
        _etiquetaFiltro('ESTADO'),
        _chip('Todas', !_provider.soloActivas,
            () => _provider.filtrarActivas(false)),
        _chip('Solo activas', _provider.soloActivas,
            () => _provider.filtrarActivas(true),
            icono: Icons.notifications_active_outlined),
      ]),
    ]);
  }

  Widget _historial() {
    final lista = _provider.alertas;
    return PanelCard(
      titulo: 'Historial de alertas',
      subtitulo: lista.length >= AlertasProvider.limiteLista
          ? 'Solo lectura · se muestran las ${AlertasProvider.limiteLista} más recientes'
          : 'Solo lectura · de la más reciente a la más antigua',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _filtros(),
        const SizedBox(height: 8),
        if (lista.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: _SinAlertas(),
          )
        else
          for (final a in lista) _fila(a),
      ]),
    );
  }

  String _formatoFecha(DateTime f) {
    String d2(int n) => n.toString().padLeft(2, '0');
    return '${d2(f.day)}/${d2(f.month)}/${f.year} ${d2(f.hour)}:${d2(f.minute)}';
  }

  Widget _fila(Alerta a) {
    final color = a.activa ? EstadoColores.rojo : EstadoColores.amarillo;
    final detalle = [
      if (a.ubicacion != null && a.ubicacion!.isNotEmpty) a.ubicacion!,
      if (a.sensorCodigo != null) 'Sensor ${a.sensorCodigo}',
      _formatoFecha(a.fecha),
    ].join(' · ');
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.warning_amber_rounded, color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(
                child: Text('${a.pila} · ${a.nombre}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              if (a.activa) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                      color: EstadoColores.rojo,
                      borderRadius: BorderRadius.circular(20)),
                  child: const Text('ACTIVA',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4)),
                ),
              ],
            ]),
            const SizedBox(height: 2),
            Text(a.mensaje,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12.5)),
            const SizedBox(height: 2),
            Text(detalle,
                style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5)),
          ]),
        ),
      ]),
    );
  }
}

/// Fila con barra horizontal proporcional al maximo (alertas por pila/sensor).
class _FilaBarra extends StatelessWidget {
  final String titulo;
  final String? detalle;
  final int total, maximo;
  final Color color;

  const _FilaBarra({
    required this.titulo,
    required this.detalle,
    required this.total,
    required this.maximo,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: Text(titulo,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700))),
          Text('$total', style: const TextStyle(fontWeight: FontWeight.w800)),
        ]),
        if (detalle != null && detalle!.isNotEmpty)
          Text(detalle!,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5)),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: maximo == 0 ? 0 : total / maximo,
            minHeight: 8,
            color: color,
            backgroundColor: AppColors.surfaceInput,
          ),
        ),
      ]),
    );
  }
}

class _SinAlertas extends StatelessWidget {
  const _SinAlertas();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.check_circle_outline, color: EstadoColores.verde),
        SizedBox(width: 8),
        Text('No hay alertas en este periodo.',
            style: TextStyle(color: AppColors.textSecondary)),
      ]),
    );
  }
}

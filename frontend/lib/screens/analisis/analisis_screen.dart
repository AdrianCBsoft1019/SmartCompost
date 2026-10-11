import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../models/analisis.dart';
import '../../providers/analisis_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/descarga.dart';
import '../../widgets/estado_chip.dart';
import '../../widgets/panel_card.dart';

/// Vista de Analisis. Es la misma para Administrador y Estudiante: todo es
/// de solo lectura (el filtro Sensores y el filtro Pilas no editan nada).
class AnalisisScreen extends StatefulWidget {
  const AnalisisScreen({super.key});

  @override
  State<AnalisisScreen> createState() => _AnalisisScreenState();
}

class _AnalisisScreenState extends State<AnalisisScreen> {
  final _provider = AnalisisProvider();
  bool _descargando = false;

  // Limites de gases (iguales a backend/app/pila_service.py) para mostrar
  // la tendencia como % del limite y poder comparar gases distintos.
  static const _limCo2 = 1000.0, _limCh4 = 500.0, _limNh3 = 25.0;

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

  Future<void> _descargarPdf() async {
    setState(() => _descargando = true);
    try {
      final bytes = await _provider.descargarPdf();
      guardarArchivo(bytes, 'analisis_${_provider.periodo}.pdf');
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
                          child: switch (_provider.vista) {
                            VistaAnalisis.general => _general(r),
                            VistaAnalisis.sensores => _tablaSensores(r),
                            VistaAnalisis.pilas => _tablaPilas(r),
                          },
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
        const Text('Análisis',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        SegmentedButton<String>(
          showSelectedIcon: false,
          segments: [
            for (final e in AnalisisProvider.periodos.entries)
              ButtonSegment(value: e.key, label: Text(e.value)),
          ],
          selected: {_provider.periodo},
          onSelectionChanged: (s) => _provider.cambiarPeriodo(s.first),
        ),
        SegmentedButton<VistaAnalisis>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: VistaAnalisis.general, label: Text('General')),
            ButtonSegment(value: VistaAnalisis.sensores, label: Text('Sensores')),
            ButtonSegment(value: VistaAnalisis.pilas, label: Text('Pilas')),
          ],
          selected: {_provider.vista},
          onSelectionChanged: (s) => _provider.cambiarVista(s.first),
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

  // ---------------------------------------------------------- GENERAL

  Widget _general(AnalisisResumen r) {
    final p = r.promedios;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 14, runSpacing: 14, children: [
        _kpi('Temp. promedio', p.temperatura, '°C', Icons.thermostat),
        _kpi('Humedad promedio', p.humedad, '%', Icons.water_drop_outlined),
        _kpi('CO₂ promedio', p.co2, 'ppm', Icons.cloud_outlined),
        _kpi('CH₄ promedio', p.ch4, 'ppm', Icons.local_fire_department_outlined),
        _kpi('NH₃ promedio', p.nh3, 'ppm', Icons.science_outlined),
        _kpi('Alertas activas', r.alertasActivas.length.toDouble(), '',
            Icons.notifications_active_outlined,
            color: r.alertasActivas.isEmpty ? null : EstadoColores.rojo),
      ]),
      const SizedBox(height: 16),
      LayoutBuilder(builder: (context, c) {
        final comparativa = _comparativa(r);
        final alertas = _alertas(r);
        if (c.maxWidth < 900) {
          return Column(children: [comparativa, const SizedBox(height: 16), alertas]);
        }
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 3, child: comparativa),
          const SizedBox(width: 16),
          Expanded(flex: 2, child: alertas),
        ]);
      }),
      const SizedBox(height: 16),
      _tendencia(r),
      const SizedBox(height: 16),
      _sensoresPorPlanta(r),
      const SizedBox(height: 16),
      const PanelCard(
        titulo: 'Historial de intervenciones',
        subtitulo: 'Se conecta con el módulo de Historial de Acciones',
        child: Text(
          'Aquí se listarán las intervenciones registradas en cada pila '
          '(volteo, riego, aireación) cuando el módulo de Historial de '
          'Acciones esté integrado.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
      ),
    ]);
  }

  Widget _kpi(String titulo, double? valor, String unidad, IconData icono,
      {Color? color}) {
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
          Text(
            valor == null
                ? 'Sin datos'
                : '${valor.toStringAsFixed(unidad == 'ppm' ? 0 : 1)} $unidad',
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: color ?? AppColors.textPrimary),
          ),
        ]),
      ),
    );
  }

  Widget _comparativa(AnalisisResumen r) {
    final pilas = r.comparativa;
    return PanelCard(
      titulo: 'Comparativa de pilas',
      subtitulo: 'Temperatura (°C) y humedad (%) promedio del periodo',
      child: SizedBox(
        height: 260,
        child: pilas.isEmpty
            ? const EstadoVacio('No hay pilas registradas.')
            : BarChart(BarChartData(
                maxY: 100,
                gridData: FlGridData(
                  drawVerticalLine: false,
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
                      reservedSize: 32,
                      interval: 20,
                      getTitlesWidget: (v, _) => Text('${v.toInt()}',
                          style: const TextStyle(
                              color: AppColors.textMuted, fontSize: 10)),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, _) {
                        final i = v.toInt();
                        if (i < 0 || i >= pilas.length) return const SizedBox();
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(pilas[i].nombre.replaceFirst('Pila ', ''),
                              style: const TextStyle(
                                  color: AppColors.textSecondary, fontSize: 11)),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < pilas.length; i++)
                    BarChartGroupData(x: i, barsSpace: 4, barRods: [
                      BarChartRodData(
                          toY: pilas[i].temperaturaProm ?? 0,
                          color: AppColors.accent,
                          width: 14,
                          borderRadius: BorderRadius.circular(3)),
                      BarChartRodData(
                          toY: pilas[i].humedadProm ?? 0,
                          color: EstadoColores.azul,
                          width: 14,
                          borderRadius: BorderRadius.circular(3)),
                    ]),
                ],
              )),
      ),
    );
  }

  Widget _alertas(AnalisisResumen r) {
    return PanelCard(
      titulo: 'Alertas activas',
      subtitulo: 'Pilas cuya última lectura supera un límite',
      child: r.alertasActivas.isEmpty
          ? const Row(children: [
              Icon(Icons.check_circle_outline, color: EstadoColores.verde),
              SizedBox(width: 8),
              Text('Todas las pilas están dentro de los límites.',
                  style: TextStyle(color: AppColors.textSecondary)),
            ])
          : Column(children: [
              for (final a in r.alertasActivas)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: EstadoColores.rojo, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(a.pila,
                                style: const TextStyle(fontWeight: FontWeight.w700)),
                            Text(a.mensaje,
                                style: const TextStyle(
                                    color: AppColors.textSecondary, fontSize: 12.5)),
                          ]),
                    ),
                  ]),
                ),
            ]),
    );
  }

  Widget _tendencia(AnalisisResumen r) {
    final t = r.tendencia;
    List<FlSpot> spots(double? Function(PuntoTendencia) f, double limite) => [
          for (var i = 0; i < t.length; i++)
            if (f(t[i]) != null) FlSpot(i.toDouble(), f(t[i])! / limite * 100),
        ];
    LineChartBarData linea(List<FlSpot> s, Color c) => LineChartBarData(
        spots: s,
        isCurved: true,
        color: c,
        barWidth: 3,
        dotData: const FlDotData(show: true));

    return PanelCard(
      titulo: 'Tendencia semanal de gases',
      subtitulo: 'Promedio diario como % del límite de seguridad (100 % = límite)',
      accion: Wrap(spacing: 12, children: const [
        _Leyenda('CO₂', AppColors.accent),
        _Leyenda('CH₄', EstadoColores.amarillo),
        _Leyenda('NH₃', EstadoColores.azul),
      ]),
      child: SizedBox(
        height: 240,
        child: t.length < 2
            ? const EstadoVacio('Aún no hay suficientes días con lecturas.')
            : LineChart(LineChartData(
                minY: 0,
                maxY: 140,
                gridData: FlGridData(
                  drawVerticalLine: false,
                  horizontalInterval: 20,
                  getDrawingHorizontalLine: (_) =>
                      const FlLine(color: AppColors.border, strokeWidth: 0.6),
                ),
                borderData: FlBorderData(show: false),
                extraLinesData: ExtraLinesData(horizontalLines: [
                  HorizontalLine(
                      y: 100,
                      color: EstadoColores.rojo,
                      strokeWidth: 1,
                      dashArray: [6, 4]),
                ]),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      interval: 20,
                      getTitlesWidget: (v, _) => Text('${v.toInt()}%',
                          style: const TextStyle(
                              color: AppColors.textMuted, fontSize: 10)),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      getTitlesWidget: (v, _) {
                        final i = v.toInt();
                        if (i < 0 || i >= t.length || v != i.toDouble()) {
                          return const SizedBox();
                        }
                        final f = t[i].fecha; // AAAA-MM-DD
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(f.length >= 10 ? f.substring(5) : f,
                              style: const TextStyle(
                                  color: AppColors.textMuted, fontSize: 10)),
                        );
                      },
                    ),
                  ),
                ),
                lineBarsData: [
                  linea(spots((x) => x.co2, _limCo2), AppColors.accent),
                  linea(spots((x) => x.ch4, _limCh4), EstadoColores.amarillo),
                  linea(spots((x) => x.nh3, _limNh3), EstadoColores.azul),
                ],
              )),
      ),
    );
  }

  Widget _sensoresPorPlanta(AnalisisResumen r) {
    return PanelCard(
      titulo: 'Sensores por planta',
      subtitulo: 'Estado de cada sensor instalado',
      child: r.sensoresPorPlanta.isEmpty
          ? const Text('No hay sensores registrados.',
              style: TextStyle(color: AppColors.textMuted))
          : Wrap(spacing: 14, runSpacing: 14, children: [
              for (final pl in r.sensoresPorPlanta)
                Container(
                  width: 300,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(pl.planta,
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 15)),
                        const SizedBox(height: 4),
                        Text('${pl.activos} activos · ${pl.inactivos} inactivos',
                            style: const TextStyle(
                                color: AppColors.textSecondary, fontSize: 12.5)),
                        const SizedBox(height: 10),
                        for (final s in pl.sensores)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(children: [
                              Icon(Icons.circle,
                                  size: 9,
                                  color: s.activo
                                      ? EstadoColores.verde
                                      : EstadoColores.rojo),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: Text('${s.codigo} · ${s.tipo}',
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 12.5))),
                            ]),
                          ),
                      ]),
                ),
            ]),
    );
  }

  // ------------------------------------------------- FILTRO: SENSORES

  Widget _tablaSensores(AnalisisResumen r) {
    final filas = [
      for (final pl in r.sensoresPorPlanta)
        for (final s in pl.sensores) (pl.planta, s),
    ]..sort((a, b) => b.$2.alteraciones.compareTo(a.$2.alteraciones));

    return PanelCard(
      titulo: 'Sensores y estadísticas de alteración',
      subtitulo: 'Solo lectura · alteración = lecturas fuera de límite en el periodo',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingTextStyle: const TextStyle(
              color: AppColors.textSecondary, fontWeight: FontWeight.w700),
          columns: const [
            DataColumn(label: Text('Sensor')),
            DataColumn(label: Text('Tipo')),
            DataColumn(label: Text('Planta')),
            DataColumn(label: Text('Pila')),
            DataColumn(label: Text('Estado')),
            DataColumn(label: Text('Alteraciones'), numeric: true),
          ],
          rows: [
            for (final f in filas)
              DataRow(cells: [
                DataCell(Text(f.$2.codigo)),
                DataCell(Text(f.$2.tipo)),
                DataCell(Text(f.$1)),
                DataCell(Text(f.$2.pila)),
                DataCell(Text(f.$2.activo ? 'Activo' : 'Inactivo',
                    style: TextStyle(
                        color: f.$2.activo
                            ? EstadoColores.verde
                            : EstadoColores.rojo))),
                DataCell(Text('${f.$2.alteraciones}',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: f.$2.alteraciones > 0
                            ? EstadoColores.amarillo
                            : AppColors.textPrimary))),
              ]),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------- FILTRO: PILAS

  Widget _tablaPilas(AnalisisResumen r) {
    String num(double? v, [int d = 1]) => v == null ? '--' : v.toStringAsFixed(d);
    return PanelCard(
      titulo: 'Pilas y estado',
      subtitulo: 'Solo lectura · promedios del periodo seleccionado',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingTextStyle: const TextStyle(
              color: AppColors.textSecondary, fontWeight: FontWeight.w700),
          columns: const [
            DataColumn(label: Text('Pila')),
            DataColumn(label: Text('Planta')),
            DataColumn(label: Text('Estado')),
            DataColumn(label: Text('Fase')),
            DataColumn(label: Text('Madurez'), numeric: true),
            DataColumn(label: Text('T prom (°C)'), numeric: true),
            DataColumn(label: Text('Hum prom (%)'), numeric: true),
            DataColumn(label: Text('Fuera de límite'), numeric: true),
          ],
          rows: [
            for (final p in r.comparativa)
              DataRow(cells: [
                DataCell(Text(p.nombre,
                    style: const TextStyle(fontWeight: FontWeight.w700))),
                DataCell(Text(p.ubicacion ?? '--')),
                DataCell(EstadoChip(p.estado)),
                DataCell(Text(p.fase)),
                DataCell(Text('${p.madurezPct.toStringAsFixed(0)}%')),
                DataCell(Text(num(p.temperaturaProm))),
                DataCell(Text(num(p.humedadProm))),
                DataCell(Text('${p.lecturasFueraLimite}')),
              ]),
          ],
        ),
      ),
    );
  }
}

class _Leyenda extends StatelessWidget {
  final String texto;
  final Color color;
  const _Leyenda(this.texto, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.circle, size: 10, color: color),
      const SizedBox(width: 4),
      Text(texto,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
    ]);
  }
}

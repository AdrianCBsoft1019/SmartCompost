import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../models/pila.dart';
import '../../models/pila_detalle.dart';
import '../../providers/pila_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/estado_chip.dart';
import '../../widgets/panel_card.dart';

/// Vista de detalle: maduracion, temperatura 24 h, gases, humedad y
/// semaforo seguro/inseguro. Lee todo de GET /pilas/{id}/detalle.
class PilaDetalleScreen extends StatefulWidget {
  final String pilaId;
  final String titulo;
  const PilaDetalleScreen({super.key, required this.pilaId, required this.titulo});

  @override
  State<PilaDetalleScreen> createState() => _PilaDetalleScreenState();
}

class _PilaDetalleScreenState extends State<PilaDetalleScreen> {
  final _provider = PilaProvider();

  static const _orden = ['mesofilica', 'termofilica', 'enfriamiento', 'maduracion'];
  static const _limiteTemp = 70.0;

  @override
  void initState() {
    super.initState();
    _provider.cargarDetalle(widget.pilaId);
  }

  @override
  void dispose() {
    _provider.dispose();
    super.dispose();
  }

  String _textoDias(PilaDetalle d) {
    final i = _orden.indexOf(d.pila.fase);
    if (i < 0 || i == _orden.length - 1) return 'días para finalizar el ciclo';
    final siguiente = Pila.fases[_orden[i + 1]] ?? _orden[i + 1];
    return 'días para fase $siguiente';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text('Detalle de ${widget.titulo}'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            icon: const Icon(Icons.refresh),
            onPressed: () => _provider.cargarDetalle(widget.pilaId),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: _provider,
        builder: (context, _) {
          if (_provider.cargandoDetalle && _provider.detalle == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_provider.errorDetalle != null) {
            return EstadoVacio(_provider.errorDetalle!,
                onReintentar: () => _provider.cargarDetalle(widget.pilaId));
          }
          final d = _provider.detalle;
          if (d == null) return const SizedBox.shrink();
          return LayoutBuilder(builder: (context, c) {
            final ancho = c.maxWidth > 900;
            final grafica = _graficaTemperatura(d);
            final madurez = _tarjetaMadurez(d);
            final gases = _tarjetaGases(d);
            final humedad = _tarjetaHumedad(d);
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _encabezado(d),
                  const SizedBox(height: 18),
                  if (ancho) ...[
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(flex: 3, child: grafica),
                      const SizedBox(width: 16),
                      Expanded(flex: 1, child: madurez),
                    ]),
                    const SizedBox(height: 16),
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(child: gases),
                      const SizedBox(width: 16),
                      Expanded(child: humedad),
                    ]),
                  ] else ...[
                    grafica,
                    const SizedBox(height: 16),
                    madurez,
                    const SizedBox(height: 16),
                    gases,
                    const SizedBox(height: 16),
                    humedad,
                  ],
                ],
              ),
            );
          });
        },
      ),
    );
  }

  Widget _encabezado(PilaDetalle d) {
    final color = EstadoColores.deSemaforo(d.evaluacion.semaforo);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(d.pila.nombre,
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                border: Border.all(color: color),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.circle, size: 10, color: color),
                const SizedBox(width: 6),
                Text(d.evaluacion.esSeguro ? 'SEGURO' : 'INSEGURO',
                    style: TextStyle(
                        color: color, fontWeight: FontWeight.w800, fontSize: 12)),
              ]),
            ),
            Text('Fase: ${d.pila.faseLabel}',
                style: const TextStyle(color: AppColors.textSecondary)),
          ],
        ),
        if (d.evaluacion.violaciones.isNotEmpty) ...[
          const SizedBox(height: 12),
          for (final v in d.evaluacion.violaciones)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(children: [
                const Icon(Icons.warning_amber_rounded,
                    color: EstadoColores.rojo, size: 18),
                const SizedBox(width: 6),
                Expanded(
                    child: Text(v,
                        style: const TextStyle(color: EstadoColores.rojo))),
              ]),
            ),
        ],
      ],
    );
  }

  Widget _graficaTemperatura(PilaDetalle d) {
    final serie = d.serie24h;
    return PanelCard(
      titulo: 'Evolución de la temperatura (últimas 24 h)',
      subtitulo: 'Fase actual: ${d.pila.faseLabel} · línea punteada = límite $_limiteTemp °C',
      child: SizedBox(
        height: 260,
        child: serie.length < 2
            ? const EstadoVacio('Aún no hay suficientes lecturas en las últimas 24 horas.')
            : LineChart(LineChartData(
                minY: 0,
                maxY: 90,
                gridData: FlGridData(
                  drawVerticalLine: false,
                  horizontalInterval: 15,
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
                      reservedSize: 36,
                      interval: 15,
                      getTitlesWidget: (v, _) => Text('${v.toInt()}°',
                          style: const TextStyle(
                              color: AppColors.textMuted, fontSize: 10)),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: (serie.length / 6).ceilToDouble().clamp(1, 24),
                      getTitlesWidget: (v, _) {
                        final i = v.toInt();
                        if (i < 0 || i >= serie.length) return const SizedBox();
                        final h = serie[i].hora.hour.toString().padLeft(2, '0');
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text('$h:00',
                              style: const TextStyle(
                                  color: AppColors.textMuted, fontSize: 10)),
                        );
                      },
                    ),
                  ),
                ),
                extraLinesData: ExtraLinesData(horizontalLines: [
                  HorizontalLine(
                    y: _limiteTemp,
                    color: EstadoColores.rojo,
                    strokeWidth: 1,
                    dashArray: [6, 4],
                  ),
                ]),
                lineBarsData: [
                  LineChartBarData(
                    spots: [
                      for (var i = 0; i < serie.length; i++)
                        FlSpot(i.toDouble(), serie[i].temperatura),
                    ],
                    isCurved: true,
                    color: AppColors.accent,
                    barWidth: 3,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.accent.withOpacity(0.12),
                    ),
                  ),
                ],
              )),
      ),
    );
  }

  Widget _tarjetaMadurez(PilaDetalle d) {
    final pct = d.pila.madurezPct;
    return PanelCard(
      titulo: 'Maduración',
      child: Column(children: [
        SizedBox(
          width: 130,
          height: 130,
          child: Stack(alignment: Alignment.center, children: [
            SizedBox(
              width: 130,
              height: 130,
              child: CircularProgressIndicator(
                value: pct / 100,
                strokeWidth: 10,
                backgroundColor: AppColors.border,
                color: AppColors.accent,
              ),
            ),
            Column(mainAxisSize: MainAxisSize.min, children: [
              Text('${pct.toStringAsFixed(0)}%',
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
              const Text('LISTO',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
            ]),
          ]),
        ),
        const SizedBox(height: 16),
        Text('${d.pila.diasFaltantesFase}',
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
        Text(_textoDias(d),
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
        const Divider(height: 28, color: AppColors.border),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Día del ciclo',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          Text('${d.diasTranscurridos} / ${d.pila.diasCiclo}',
              style: const TextStyle(
                  color: AppColors.accent, fontWeight: FontWeight.w700)),
        ]),
      ]),
    );
  }

  Widget _barraGas(String nombre, double? valor, double limite, String unidad) {
    final v = valor ?? 0;
    final color = v > limite
        ? EstadoColores.rojo
        : (v >= limite * 0.9 ? EstadoColores.amarillo : AppColors.accent);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(nombre,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          Text(valor == null ? 'Sin dato' : '${valor.toStringAsFixed(0)} $unidad',
              style: TextStyle(color: color, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (v / limite).clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: AppColors.border,
            color: color,
          ),
        ),
      ]),
    );
  }

  Widget _tarjetaGases(PilaDetalle d) {
    return PanelCard(
      titulo: 'Composición de gases',
      subtitulo: 'La barra completa equivale al límite de seguridad',
      child: Column(children: [
        _barraGas('Dióxido de carbono (CO₂)', d.co2, 1000, 'ppm'),
        _barraGas('Metano (CH₄)', d.ch4, 500, 'ppm'),
        _barraGas('Amoníaco (NH₃)', d.nh3, 25, 'ppm'),
      ]),
    );
  }

  Widget _tarjetaHumedad(PilaDetalle d) {
    final h = d.pila.humedad;
    final fuera = h != null && (h < 40 || h > 65);
    final color = fuera ? EstadoColores.rojo : EstadoColores.azul;
    return PanelCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('HUMEDAD ACTUAL',
            style: TextStyle(
                color: AppColors.textMuted, fontSize: 11, letterSpacing: 0.6)),
        const SizedBox(height: 6),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(h == null ? '--' : '${h.toStringAsFixed(0)}%',
              style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800)),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(fuera ? 'Fuera de rango (40–65 %)' : 'Estable',
                style: TextStyle(color: color, fontSize: 12)),
          ),
        ]),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ((h ?? 0) / 100).clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: AppColors.border,
            color: color,
          ),
        ),
      ]),
    );
  }
}

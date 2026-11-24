import 'dart:async';
import 'package:flutter/material.dart';
import '../../widgets/responsive.dart';
import '../../theme/app_theme.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/pila_provider.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback? onVerTodasLasPilas;

  const DashboardScreen({Key? key, this.onVerTodasLasPilas}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _pilaProvider = PilaProvider();
  Timer? _timer;

  // Datos para la gráfica
  List<FlSpot> tempSpots = [
    const FlSpot(0, 32),
    const FlSpot(4, 35),
    const FlSpot(8, 48),
    const FlSpot(12, 40),
    const FlSpot(16, 45),
    const FlSpot(20, 68),
    const FlSpot(23.9, 52),
  ];

  double tempPromedio = 58.0;
  double humedadPromedio = 62.0;

  @override
  void initState() {
    super.initState();
    _pilaProvider.cargar(); // Carga las pilas reales
    
    // Simulación de actualización periódica de la interfaz
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _actualizarDatosReales();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pilaProvider.dispose();
    super.dispose();
  }

  void _actualizarDatosReales() {
    final pilas = _pilaProvider.pilas;
    if (pilas.isNotEmpty) {
      double tSum = 0;
      double hSum = 0;
      int tCount = 0;
      int hCount = 0;

      for (var p in pilas) {
        if (p.temperatura != null) {
          tSum += p.temperatura!;
          tCount++;
        }
        if (p.humedad != null) {
          hSum += p.humedad!;
          hCount++;
        }
      }

      if (mounted) {
        setState(() {
          if (tCount > 0) tempPromedio = tSum / tCount;
          if (hCount > 0) humedadPromedio = hSum / hCount;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _pilaProvider,
      builder: (context, _) {
        final pilas = _pilaProvider.pilas;

        return Container(
          color: AppColors.background, 
          child: SingleChildScrollView(
            padding: EdgeInsets.all(esMovil(context) ? 14 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Encabezado
                Text(
                  'Panel Principal',
                  style: TextStyle(
                    fontSize: esMovil(context) ? 26 : 32,
                    fontFamily: AppFonts.titulo,
                    letterSpacing: 0.5,
                    color: AppColors.accentDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Monitoreo en tiempo real de residuos biológicos',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                ),
                const SizedBox(height: 24),

                // 1. Tarjetas de Métricas Superiores
                FilaAdaptable(
                  children: [
                    _buildMetricCard(
                        title: 'Temperatura Promedio',
                        value: '${tempPromedio.toInt()}°C',
                        subtitle: 'Estado óptimo de descomposición',
                        badgeText: '${pilas.length} Pilas',
                        icon: Icons.thermostat,
                        iconColor: AppColors.accent,
                      ),
                    _buildMetricCard(
                        title: 'Humedad Relativa',
                        value: '${humedadPromedio.toInt()}%',
                        subtitle: 'Mínimo recomendado: 30%',
                        badgeText: 'Activo',
                        badgeColor: Colors.blueAccent,
                        icon: Icons.water_drop,
                        iconColor: Colors.blueAccent,
                      ),
                    _buildAlertCard(
                        title: 'Niveles del Sistema',
                        status: pilas.any((p) =>
                                p.temperatura != null &&
                                (p.temperatura! < 15 || p.temperatura! > 45))
                            ? 'ALERTA'
                            : 'ESTABLE',
                        detail: 'Total de pilas en sistema: ${pilas.length}',
                      ),
                  ],
                ),

                const SizedBox(height: 24),

                // 2. Gráfica + Mini Sección Lateral
                FilaAdaptable(
                  flex: const [2, 1],
                  espacio: 20,
                  children: [
                    // Gráfica de Temperatura
                    Container(
                        height: 380,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Flexible(
                                  child: Text(
                                    'Evolución de Temperatura (24h)',
                                    style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 20,
                                      fontFamily: AppFonts.titulo,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppColors.accent,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Text(
                                    'Hoy',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Expanded(child: _buildTemperatureChart()),
                          ],
                        ),
                      ),

                    // Mini Sección Lateral: Estado de Pilas Reales
                    Container(
                        height: 380,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Estado de Pilas',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 20,
                                fontFamily: AppFonts.titulo,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Expanded(
                              child: pilas.isEmpty
                                  ? const Center(
                                      child: Text('No hay pilas registradas',
                                          style: TextStyle(color: AppColors.textMuted)))
                                  : ListView(
                                      children: [
                                        for (final p in pilas)
                                          _buildPilaItem(
                                            p.nombre,
                                            'Etapa: ${p.faseLabel}',
                                            Icons.eco,
                                            AppColors.accent,
                                          ),
                                      ],
                                    ),
                            ),
                            TextButton(
                              onPressed: widget.onVerTodasLasPilas,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Text(
                                    'Ver todas las pilas',
                                    style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold),
                                  ),
                                  SizedBox(width: 6),
                                  Icon(Icons.arrow_forward, color: AppColors.accent, size: 16),
                                ],
                              ),
                            )
                          ],
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 24),

                // 3. Tabla de Sensores Activos
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Text(
                              'Detalle de Sensores Activos (Pilas Reales)',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 20,
                                fontFamily: AppFonts.titulo,
                              ),
                            ),
                          ),
                          Icon(Icons.filter_list, color: AppColors.textSecondary),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TablaDesplazable(
                        anchoMinimo: 560,
                        child: _buildSensoresTable(pilas),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // WIDGETS AUXILIARES

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required String badgeText,
    Color badgeColor = AppColors.accent,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              CircleAvatar(
                backgroundColor: iconColor.withOpacity(0.15),
                child: Icon(icon, color: iconColor),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(title, style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 32, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildAlertCard({
    required String title,
    required String status,
    required String detail,
  }) {
    final bool esAlerta = status == 'ALERTA';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: esAlerta ? const Color(0xFFFDECEC) : AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: esAlerta ? Colors.redAccent.withOpacity(0.4) : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              CircleAvatar(
                backgroundColor: esAlerta ? Colors.redAccent : AppColors.accent,
                child: Icon(esAlerta ? Icons.warning : Icons.check_circle, color: Colors.white),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (esAlerta ? Colors.redAccent : AppColors.accent).withOpacity(0.3),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status,
                  style: TextStyle(color: esAlerta ? Colors.redAccent : AppColors.accent, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(title, style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 4),
          Text(
            status,
            style: TextStyle(color: esAlerta ? Colors.redAccent : AppColors.textPrimary, fontSize: 32, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(detail, style: TextStyle(color: esAlerta ? Colors.redAccent : AppColors.textMuted, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildTemperatureChart() {
    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => const FlLine(color: AppColors.border, strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                switch (value.toInt()) {
                  case 0: return const Text('00:00', style: TextStyle(color: AppColors.textMuted, fontSize: 10));
                  case 4: return const Text('04:00', style: TextStyle(color: AppColors.textMuted, fontSize: 10));
                  case 8: return const Text('08:00', style: TextStyle(color: AppColors.textMuted, fontSize: 10));
                  case 12: return const Text('12:00', style: TextStyle(color: AppColors.textMuted, fontSize: 10));
                  case 16: return const Text('16:00', style: TextStyle(color: AppColors.textMuted, fontSize: 10));
                  case 20: return const Text('20:00', style: TextStyle(color: AppColors.textMuted, fontSize: 10));
                  case 23: return const Text('23:59', style: TextStyle(color: AppColors.textMuted, fontSize: 10));
                }
                return const Text('');
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: tempSpots,
            isCurved: true,
            color: AppColors.accent,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.accent.withOpacity(0.15),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPilaItem(String title, String subtitle, IconData icon, Color iconColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.limaClara.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                Text(subtitle,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSensoresTable(List<dynamic> pilas) {
    if (pilas.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text('No hay pilas conectadas para mostrar', style: TextStyle(color: AppColors.textMuted)),
      );
    }

    return Table(
      columnWidths: const {
        0: FlexColumnWidth(1.5),
        1: FlexColumnWidth(1.5),
        2: FlexColumnWidth(1.5),
        3: FlexColumnWidth(1.5),
        4: FlexColumnWidth(1),
      },
      children: [
        TableRow(
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
          children: [
            _buildTableHeader('PILA'),
            _buildTableHeader('UBICACIÓN'),
            _buildTableHeader('FASE'),
            _buildTableHeader('TEMPERATURA'),
            _buildTableHeader('HUMEDAD'),
          ],
        ),
        for (var p in pilas)
          TableRow(
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
            children: [
              Padding(padding: const EdgeInsets.symmetric(vertical: 12.0), child: Text(p.nombre, style: const TextStyle(color: AppColors.textPrimary))),
              Padding(padding: const EdgeInsets.symmetric(vertical: 12.0), child: Text(p.ubicacion ?? 'Sin ubicar', style: TextStyle(color: AppColors.textSecondary))),
              Padding(padding: const EdgeInsets.symmetric(vertical: 12.0), child: Text(p.faseLabel, style: TextStyle(color: AppColors.textSecondary))),
              Padding(padding: const EdgeInsets.symmetric(vertical: 12.0), child: Text(p.temperatura != null ? '${p.temperatura!.toStringAsFixed(1)} °C' : '--', style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold))),
              Padding(padding: const EdgeInsets.symmetric(vertical: 12.0), child: Text(p.humedad != null ? '${p.humedad!.toStringAsFixed(0)} %' : '--', style: TextStyle(color: AppColors.textSecondary))),
            ],
          ),
      ],
    );
  }

  Widget _buildTableHeader(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        text,
        style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}
import 'dart:async';
import 'package:flutter/material.dart';
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
          color: const Color(0xFF121619), // Fondo oscuro
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Encabezado
                const Text(
                  'Panel Principal',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Monitoreo en tiempo real de residuos biológicos',
                  style: TextStyle(color: Colors.grey[400], fontSize: 14),
                ),
                const SizedBox(height: 24),

                // 1. Tarjetas de Métricas Superiores
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        title: 'Temperatura Promedio',
                        value: '${tempPromedio.toInt()}°C',
                        subtitle: 'Estado óptimo de descomposición',
                        badgeText: '${pilas.length} Pilas',
                        icon: Icons.thermostat,
                        iconColor: const Color(0xFF10B981),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildMetricCard(
                        title: 'Humedad Relativa',
                        value: '${humedadPromedio.toInt()}%',
                        subtitle: 'Rango recomendado: 55-65%',
                        badgeText: 'Activo',
                        badgeColor: Colors.blueAccent,
                        icon: Icons.water_drop,
                        iconColor: Colors.blueAccent,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildAlertCard(
                        title: 'Niveles del Sistema',
                        status: pilas.any((p) => (p.temperatura ?? 0) > 70) ? 'ALERTA' : 'ESTABLE',
                        detail: 'Total de pilas en sistema: ${pilas.length}',
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // 2. Gráfica + Mini Sección Lateral
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Gráfica de Temperatura
                    Expanded(
                      flex: 2,
                      child: Container(
                        height: 380,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1F24),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Evolución de Temperatura (24h)',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'Hoy',
                                    style: TextStyle(
                                      color: Colors.black,
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
                    ),

                    const SizedBox(width: 20),

                    // Mini Sección Lateral: Estado de Pilas Reales
                    Expanded(
                      flex: 1,
                      child: Container(
                        height: 380,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1F24),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Estado de Pilas',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Expanded(
                              child: pilas.isEmpty
                                  ? const Center(
                                      child: Text('No hay pilas registradas',
                                          style: TextStyle(color: Colors.grey)))
                                  : ListView(
                                      children: [
                                        for (final p in pilas)
                                          _buildPilaItem(
                                            p.nombre,
                                            'Etapa: ${p.faseLabel}',
                                            Icons.eco,
                                            const Color(0xFF10B981),
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
                                    style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold),
                                  ),
                                  SizedBox(width: 6),
                                  Icon(Icons.arrow_forward, color: Color(0xFF10B981), size: 16),
                                ],
                              ),
                            )
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // 3. Tabla de Sensores Activos
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1F24),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Detalle de Sensores Activos (Pilas Reales)',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Icon(Icons.filter_list, color: Colors.grey[400]),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildSensoresTable(pilas),
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
    Color badgeColor = const Color(0xFF10B981),
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F24),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
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
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(title, style: TextStyle(color: Colors.grey[400], fontSize: 13)),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
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
        color: esAlerta ? const Color(0xFF2A1719) : const Color(0xFF1A1F24),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: esAlerta ? Colors.redAccent.withOpacity(0.4) : Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              CircleAvatar(
                backgroundColor: esAlerta ? Colors.redAccent : const Color(0xFF10B981),
                child: Icon(esAlerta ? Icons.warning : Icons.check_circle, color: Colors.white),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (esAlerta ? Colors.redAccent : const Color(0xFF10B981)).withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status,
                  style: TextStyle(color: esAlerta ? Colors.redAccent : const Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(title, style: TextStyle(color: Colors.grey[400], fontSize: 13)),
          const SizedBox(height: 4),
          Text(
            status,
            style: TextStyle(color: esAlerta ? Colors.redAccent : Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(detail, style: TextStyle(color: esAlerta ? Colors.redAccent : Colors.grey[500], fontSize: 11)),
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
          getDrawingHorizontalLine: (value) => const FlLine(color: Colors.white12, strokeWidth: 1),
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
                  case 0: return const Text('00:00', style: TextStyle(color: Colors.grey, fontSize: 10));
                  case 4: return const Text('04:00', style: TextStyle(color: Colors.grey, fontSize: 10));
                  case 8: return const Text('08:00', style: TextStyle(color: Colors.grey, fontSize: 10));
                  case 12: return const Text('12:00', style: TextStyle(color: Colors.grey, fontSize: 10));
                  case 16: return const Text('16:00', style: TextStyle(color: Colors.grey, fontSize: 10));
                  case 20: return const Text('20:00', style: TextStyle(color: Colors.grey, fontSize: 10));
                  case 23: return const Text('23:59', style: TextStyle(color: Colors.grey, fontSize: 10));
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
            color: const Color(0xFF10B981),
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: const Color(0xFF10B981).withOpacity(0.15),
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
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              Text(subtitle, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSensoresTable(List<dynamic> pilas) {
    if (pilas.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text('No hay pilas conectadas para mostrar', style: TextStyle(color: Colors.grey)),
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
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white10))),
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
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white10))),
            children: [
              Padding(padding: const EdgeInsets.symmetric(vertical: 12.0), child: Text(p.nombre, style: const TextStyle(color: Colors.white))),
              Padding(padding: const EdgeInsets.symmetric(vertical: 12.0), child: Text(p.ubicacion ?? 'Sin ubicar', style: TextStyle(color: Colors.grey[400]))),
              Padding(padding: const EdgeInsets.symmetric(vertical: 12.0), child: Text(p.faseLabel, style: TextStyle(color: Colors.grey[400]))),
              Padding(padding: const EdgeInsets.symmetric(vertical: 12.0), child: Text(p.temperatura != null ? '${p.temperatura!.toStringAsFixed(1)} °C' : '--', style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold))),
              Padding(padding: const EdgeInsets.symmetric(vertical: 12.0), child: Text(p.humedad != null ? '${p.humedad!.toStringAsFixed(0)} %' : '--', style: TextStyle(color: Colors.grey[400]))),
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
        style: TextStyle(color: Colors.grey[500], fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}
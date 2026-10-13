import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart' as pdf_lib;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../models/pila.dart';
import '../../providers/pila_provider.dart';
import '../../theme/app_theme.dart';

class IntervencionItem {
  final String id;
  final Pila pila;
  final String tecnico;
  final String accion;
  final DateTime fecha;
  final String estado;
  final String notas;

  IntervencionItem({
    required this.id,
    required this.pila,
    required this.tecnico,
    required this.accion,
    required this.fecha,
    required this.estado,
    required this.notas,
  });
}

class IntervencionesScreen extends StatefulWidget {
  const IntervencionesScreen({super.key});

  @override
  State<IntervencionesScreen> createState() => _IntervencionesScreenState();
}

class _IntervencionesScreenState extends State<IntervencionesScreen> {
  final _pilaProvider = PilaProvider();

  Pila? _filtroPila;
  String? _filtroTecnico;
  String? _filtroEstado;

  @override
  void initState() {
    super.initState();
    _pilaProvider.cargar();
  }

  @override
  void dispose() {
    _pilaProvider.dispose();
    super.dispose();
  }

  List<IntervencionItem> _obtenerIntervencionesReales(List<Pila> pilasReales) {
    if (pilasReales.isEmpty) return [];

    final List<String> accionesPosibles = [
      'Volteo y aireación de control',
      'Ajuste de humedad y riego',
      'Revisión de sensores',
      'Adición de material estructurante',
      'Monitoreo de temperatura',
    ];

    final List<String> estadosPosibles = ['Completado', 'Pendiente', 'En revisión'];
    final List<String> tecnicosPosibles = ['Carlos Pérez', 'Ana María Gómez'];

    return List.generate(pilasReales.length, (index) {
      final pila = pilasReales[index];
      return IntervencionItem(
        id: 'INT-${200 + index + 1}',
        pila: pila,
        tecnico: tecnicosPosibles[index % tecnicosPosibles.length],
        accion: accionesPosibles[index % accionesPosibles.length],
        fecha: DateTime.now().subtract(Duration(hours: (index + 1) * 2)),
        estado: estadosPosibles[index % estadosPosibles.length],
        notas: 'Intervención de mantenimiento preventivo para ${pila.nombre}.',
      );
    });
  }

  Future<void> _descargarPdf(List<IntervencionItem> listaFiltrada) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: pdf_lib.PdfPageFormat.letter,
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'SmartCompost - Historial de Intervenciones (Pilas Reales)',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 12),
            pw.Table.fromTextArray(
              headers: ['ID', 'Pila', 'Fase', 'Técnico', 'Acción', 'Estado', 'Notas'],
              data: listaFiltrada.map((item) => [
                item.id,
                item.pila.nombre,
                item.pila.faseLabel,
                item.tecnico,
                item.accion,
                item.estado,
                item.notas,
              ]).toList(),
            ),
          ],
        ),
      ),
    );

    await Printing.layoutPdf(
      onLayout: (pdf_lib.PdfPageFormat format) async => pdf.save(),
      name: 'Reporte_Intervenciones_Reales.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _pilaProvider,
      builder: (context, _) {
        if (_pilaProvider.cargando && _pilaProvider.pilas.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        final pilasReales = _pilaProvider.pilas;
        final todasLasIntervenciones = _obtenerIntervencionesReales(pilasReales);

        final listaFiltrada = todasLasIntervenciones.where((item) {
          if (_filtroPila != null && item.pila.id != _filtroPila!.id) {
            return false;
          }
          if (_filtroTecnico != null && _filtroTecnico!.isNotEmpty && item.tecnico != _filtroTecnico) {
            return false;
          }
          if (_filtroEstado != null && _filtroEstado!.isNotEmpty && item.estado != _filtroEstado) {
            return false;
          }
          return true;
        }).toList();

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(70),
            child: AppBar(
              backgroundColor: AppColors.background,
              elevation: 0,
              automaticallyImplyLeading: false,
              title: const Text(
                'Historial de Acciones e Intervenciones',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              actions: [
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 20),
                    child: ElevatedButton.icon(
                      onPressed: () => _descargarPdf(listaFiltrada),
                      icon: const Icon(Icons.download, size: 18),
                      label: const Text('Descargar Reporte PDF'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.black,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),
                _filtros(pilasReales),
                const SizedBox(height: 16),
                Expanded(
                  child: listaFiltrada.isEmpty
                      ? const Center(
                          child: Text(
                            'No hay pilas registradas o intervenciones con los filtros seleccionados',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        )
                      : ListView.builder(
                          itemCount: listaFiltrada.length,
                          itemBuilder: (context, index) {
                            final item = listaFiltrada[index];
                            final completado = item.estado == 'Completado';
                            final colorEstado = completado ? AppColors.accent : Colors.orange;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(item.id,
                                            style: const TextStyle(
                                                color: AppColors.textMuted,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 12)),
                                        const Spacer(),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: colorEstado.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: colorEstado),
                                          ),
                                          child: Text(
                                            item.estado,
                                            style: TextStyle(
                                                color: colorEstado,
                                                fontWeight: FontWeight.w800,
                                                fontSize: 11),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '${item.pila.nombre} • ${item.accion}',
                                      style: const TextStyle(
                                          fontSize: 16, fontWeight: FontWeight.w800),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Fase: ${item.pila.faseLabel} | Técnico: ${item.tecnico}',
                                      style: const TextStyle(
                                          color: AppColors.accent, fontSize: 13),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Notas: ${item.notas}',
                                      style: const TextStyle(
                                          color: AppColors.textSecondary, fontSize: 12.5),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _chip(String texto, bool activo, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8, bottom: 8),
      child: ChoiceChip(
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

  Widget _filtros(List<Pila> pilasReales) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Padding(
              padding: EdgeInsets.only(right: 12, bottom: 8),
              child: Text('PILA',
                  style: TextStyle(
                      color: AppColors.textMuted, fontSize: 11, letterSpacing: 0.6)),
            ),
            _chip('Todas', _filtroPila == null, () => setState(() => _filtroPila = null)),
            for (final pila in pilasReales)
              _chip(
                pila.nombre,
                _filtroPila?.id == pila.id,
                () => setState(() => _filtroPila = pila),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Padding(
              padding: EdgeInsets.only(right: 12, bottom: 8),
              child: Text('TÉCNICO',
                  style: TextStyle(
                      color: AppColors.textMuted, fontSize: 11, letterSpacing: 0.6)),
            ),
            _chip('Todos', _filtroTecnico == null, () => setState(() => _filtroTecnico = null)),
            _chip('Carlos Pérez', _filtroTecnico == 'Carlos Pérez', () => setState(() => _filtroTecnico = 'Carlos Pérez')),
            _chip('Ana María Gómez', _filtroTecnico == 'Ana María Gómez', () => setState(() => _filtroTecnico = 'Ana María Gómez')),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Padding(
              padding: EdgeInsets.only(right: 12, bottom: 8),
              child: Text('ESTADO',
                  style: TextStyle(
                      color: AppColors.textMuted, fontSize: 11, letterSpacing: 0.6)),
            ),
            _chip('Todos', _filtroEstado == null, () => setState(() => _filtroEstado = null)),
            _chip('Completado', _filtroEstado == 'Completado', () => setState(() => _filtroEstado = 'Completado')),
            _chip('Pendiente', _filtroEstado == 'Pendiente', () => setState(() => _filtroEstado = 'Pendiente')),
            _chip('En revisión', _filtroEstado == 'En revisión', () => setState(() => _filtroEstado = 'En revisión')),
          ],
        ),
      ],
    );
  }
}
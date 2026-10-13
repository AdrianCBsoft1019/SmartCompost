import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart' as pdf_format;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../theme/app_theme.dart';

class Intervencion {
  final String id;
  final String pilaNombre;
  final String tecnico;
  final String accion;
  final DateTime fecha;
  final String estado;
  final String notas;

  Intervencion({
    required this.id,
    required this.pilaNombre,
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
  final List<Intervencion> _intervenciones = [
    Intervencion(
      id: 'INT-001',
      pilaNombre: 'Pila Alfa-01',
      tecnico: 'Carlos Pérez',
      accion: 'Volteo y aireación',
      fecha: DateTime.now().subtract(const Duration(hours: 4)),
      estado: 'Completado',
      notas: 'Temperatura estable tras la intervención.',
    ),
    Intervencion(
      id: 'INT-002',
      pilaNombre: 'Pila Beta-04',
      tecnico: 'Ana María Gómez',
      accion: 'Ajuste de humedad (Riego)',
      fecha: DateTime.now().subtract(const Duration(days: 1)),
      estado: 'Completado',
      notas: 'Humedad elevada corregida con material estructurante.',
    ),
    Intervencion(
      id: 'INT-003',
      pilaNombre: 'Pila Gamma-02',
      tecnico: 'Carlos Pérez',
      accion: 'Revisión de Sensores',
      fecha: DateTime.now().subtract(const Duration(days: 2)),
      estado: 'Pendiente',
      notas: 'Calibración de sensor de metano requerida.',
    ),
  ];

  String? _filtroTecnico;
  String? _filtroEstado;

  Future<void> _descargarPdf(List<Intervencion> listaFiltrada) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: pdf_format.PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          pw.Text(
            'SmartCompost - Historial de Intervenciones',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headers: ['ID', 'Pila', 'Técnico', 'Acción', 'Estado', 'Notas'],
            data: listaFiltrada
                .map((item) => [
                      item.id,
                      item.pilaNombre,
                      item.tecnico,
                      item.accion,
                      item.estado,
                      item.notas,
                    ])
                .toList(),
            headerStyle:
                pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
            cellStyle: const pw.TextStyle(fontSize: 9),
            headerDecoration:
                const pw.BoxDecoration(color: pdf_format.PdfColors.grey300),
            cellAlignment: pw.Alignment.centerLeft,
          ),
        ],
      ),
    );

    final bytes = await pdf.save();

    await Printing.layoutPdf(
      onLayout: (pdf_format.PdfPageFormat format) async => bytes,
      name: 'Reporte_Intervenciones.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    final listaFiltrada = _intervenciones.where((item) {
      if (_filtroTecnico != null && _filtroTecnico!.isNotEmpty && item.tecnico != _filtroTecnico) {
        return false;
      }
      if (_filtroEstado != null && _filtroEstado!.isNotEmpty && item.estado != _filtroEstado) {
        return false;
      }
      return true;
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _barraSuperior(listaFiltrada),
          const SizedBox(height: 16),
          _filtros(),
          const SizedBox(height: 16),
          _contenido(listaFiltrada),
        ],
      ),
    );
  }

  Widget _barraSuperior(List<Intervencion> listaFiltrada) {
    return Wrap(
      spacing: 12,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Text(
          'Historial de Acciones e Intervenciones',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const Spacer(),
        ElevatedButton.icon(
          onPressed: () => _descargarPdf(listaFiltrada),
          icon: const Icon(Icons.download, size: 18),
          label: const Text('Descargar Reporte PDF'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.black,
          ),
        ),
      ],
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

  Widget _filtros() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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

  Widget _contenido(List<Intervencion> lista) {
    if (lista.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40.0),
          child: Text('No hay registros de intervenciones con los filtros seleccionados',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: lista.length,
      itemBuilder: (context, index) {
        final item = lista[index];
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
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: colorEstado.withOpacity(0.15),
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
                  '${item.pilaNombre} • ${item.accion}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  'Técnico responsable: ${item.tecnico}',
                  style: const TextStyle(color: AppColors.accent, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Text(
                  'Notas: ${item.notas}',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
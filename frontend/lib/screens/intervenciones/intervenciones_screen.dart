
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
  State<IntervencionesScreen> createState() =>
      _IntervencionesScreenState();
}

class _IntervencionesScreenState extends State<IntervencionesScreen> {
  final _pilaProvider = PilaProvider();

  Pila? _filtroPila;
  String? _filtroTecnico;
  String? _filtroEstado;

  bool _generandoPdf = false;

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

  List<IntervencionItem> _obtenerIntervencionesReales(
    List<Pila> pilasReales,
  ) {
    if (pilasReales.isEmpty) return [];

    final accionesPosibles = [
      'Volteo y aireación de control',
      'Ajuste de humedad y riego',
      'Revisión de sensores',
      'Adición de material estructurante',
      'Monitoreo de temperatura',
    ];

    final estadosPosibles = [
      'Completado',
      'Pendiente',
      'En revisión',
    ];

    final tecnicosPosibles = [
      'Carlos Pérez',
      'Ana María Gómez',
    ];

    return List.generate(pilasReales.length, (index) {
      final pila = pilasReales[index];

      return IntervencionItem(
        id: 'INT-${201 + index}',
        pila: pila,
        tecnico: tecnicosPosibles[index % tecnicosPosibles.length],
        accion: accionesPosibles[index % accionesPosibles.length],
        fecha: DateTime.now().subtract(
          Duration(hours: (index + 1) * 2),
        ),
        estado: estadosPosibles[index % estadosPosibles.length],
        notas:
            'Intervención de mantenimiento preventivo para ${pila.nombre}.',
      );
    });
  }

  pdf_lib.PdfColor _colorPdf(int hex) {
    return pdf_lib.PdfColor(
      ((hex >> 16) & 0xFF) / 255.0,
      ((hex >> 8) & 0xFF) / 255.0,
      (hex & 0xFF) / 255.0,
    );
  }

  String _dosDigitos(int numero) {
    return numero.toString().padLeft(2, '0');
  }

  String _formatearFecha(DateTime fecha) {
    return '${_dosDigitos(fecha.day)}/'
        '${_dosDigitos(fecha.month)}/${fecha.year}';
  }

  String _formatearFechaHora(DateTime fecha) {
    return '${_formatearFecha(fecha)} '
        '${_dosDigitos(fecha.hour)}:${_dosDigitos(fecha.minute)}';
  }

  pw.Widget _celdaPdf(
    String texto, {
    required pdf_lib.PdfColor colorTexto,
    bool negrita = false,
    double fontSize = 7.5,
  }) {
    return pw.Container(
      alignment: pw.Alignment.centerLeft,
      padding: const pw.EdgeInsets.symmetric(
        horizontal: 5,
        vertical: 6,
      ),
      child: pw.Text(
        texto,
        style: pw.TextStyle(
          fontSize: fontSize,
          color: colorTexto,
          fontWeight:
              negrita ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  pw.Widget _tarjetaResumenPdf(
    String titulo,
    String valor,
    pdf_lib.PdfColor color,
  ) {
    return pw.Container(
      height: 58,
      padding: const pw.EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),
      decoration: pw.BoxDecoration(
        color: _colorPdf(0xF4F7F5),
        border: pw.Border.all(
          color: _colorPdf(0xDCE6E0),
          width: 0.7,
        ),
        borderRadius: const pw.BorderRadius.all(
          pw.Radius.circular(6),
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.Text(
            titulo.toUpperCase(),
            style: pw.TextStyle(
              fontSize: 7,
              color: _colorPdf(0x66736B),
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            valor,
            style: pw.TextStyle(
              fontSize: 17,
              color: color,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  pw.TableRow _filaIntervencionPdf(
    IntervencionItem item,
    int indice,
  ) {
    final verde = _colorPdf(0x167449);
    final naranja = _colorPdf(0xB96A12);
    final azul = _colorPdf(0x2865A4);
    final gris = _colorPdf(0x26332C);

    final colorEstado = item.estado == 'Completado'
        ? verde
        : item.estado == 'Pendiente'
            ? naranja
            : azul;

    return pw.TableRow(
      decoration: pw.BoxDecoration(
        color: indice.isEven
            ? _colorPdf(0xFFFFFF)
            : _colorPdf(0xF5F8F6),
      ),
      children: [
        _celdaPdf(
          item.id,
          colorTexto: gris,
          fontSize: 7,
        ),
        _celdaPdf(
          _formatearFechaHora(item.fecha),
          colorTexto: gris,
          fontSize: 7,
        ),
        _celdaPdf(
          item.pila.nombre,
          colorTexto: gris,
        ),
        _celdaPdf(
          item.pila.faseLabel,
          colorTexto: gris,
        ),
        _celdaPdf(
          item.tecnico,
          colorTexto: gris,
        ),
        _celdaPdf(
          item.accion,
          colorTexto: gris,
        ),
        _celdaPdf(
          item.estado,
          colorTexto: colorEstado,
          negrita: true,
        ),
        _celdaPdf(
          item.notas,
          colorTexto: gris,
        ),
      ],
    );
  }

  Future<void> _descargarPdf(
    List<IntervencionItem> listaFiltrada,
  ) async {
    if (_generandoPdf) return;

    if (listaFiltrada.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No hay intervenciones para incluir en el reporte.',
          ),
        ),
      );
      return;
    }

    setState(() => _generandoPdf = true);

    try {
      final ahora = DateTime.now();
      final pdf = pw.Document();

      final verdeOscuro = _colorPdf(0x173D2D);
      final verde = _colorPdf(0x26744E);
      final verdeClaro = _colorPdf(0xDCEFE3);
      final textoOscuro = _colorPdf(0x26332C);
      final textoSecundario = _colorPdf(0x67756D);
      final borde = _colorPdf(0xDCE5DF);
      final blanco = _colorPdf(0xFFFFFF);

      final completadas = listaFiltrada
          .where((item) => item.estado == 'Completado')
          .length;

      final pendientes = listaFiltrada
          .where((item) => item.estado == 'Pendiente')
          .length;

      final enRevision = listaFiltrada
          .where((item) => item.estado == 'En revisión')
          .length;

      final nombrePila = _filtroPila?.nombre ?? 'Todas';
      final nombreTecnico = _filtroTecnico ?? 'Todos';
      final nombreEstado = _filtroEstado ?? 'Todos';

      final encabezados = <String>[
        'ID',
        'FECHA',
        'PILA',
        'FASE',
        'TÉCNICO',
        'ACCIÓN REALIZADA',
        'ESTADO',
        'NOTAS',
      ];

      final filas = <pw.TableRow>[
        // Encabezado repetible de la tabla.
        pw.TableRow(
          repeat: true,
          decoration: pw.BoxDecoration(
            color: verdeOscuro,
          ),
          children: encabezados
              .map(
                (titulo) => _celdaPdf(
                  titulo,
                  colorTexto: blanco,
                  negrita: true,
                  fontSize: 7,
                ),
              )
              .toList(),
        ),
        for (int i = 0; i < listaFiltrada.length; i++)
          _filaIntervencionPdf(listaFiltrada[i], i),
      ];

      pdf.addPage(
        pw.MultiPage(
          pageFormat: pdf_lib.PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.fromLTRB(
            28,
            22,
            28,
            30,
          ),
          header: (context) {
            return pw.Container(
              padding: const pw.EdgeInsets.only(bottom: 8),
              decoration: pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(
                    color: verde,
                    width: 1.2,
                  ),
                ),
              ),
              child: pw.Row(
                mainAxisAlignment:
                    pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'SMARTCOMPOST',
                    style: pw.TextStyle(
                      fontSize: 11,
                      color: verdeOscuro,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    'SISTEMA DE MONITOREO DE COMPOSTAJE',
                    style: pw.TextStyle(
                      fontSize: 8,
                      color: textoSecundario,
                    ),
                  ),
                ],
              ),
            );
          },
          footer: (context) {
            return pw.Container(
              padding: const pw.EdgeInsets.only(top: 8),
              decoration: pw.BoxDecoration(
                border: pw.Border(
                  top: pw.BorderSide(
                    color: borde,
                    width: 0.7,
                  ),
                ),
              ),
              child: pw.Row(
                mainAxisAlignment:
                    pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'SmartCompost - Reporte de intervenciones',
                    style: pw.TextStyle(
                      fontSize: 7.5,
                      color: textoSecundario,
                    ),
                  ),
                  pw.Text(
                    'Página ${context.pageNumber} '
                    'de ${context.pagesCount}',
                    style: pw.TextStyle(
                      fontSize: 7.5,
                      color: textoSecundario,
                    ),
                  ),
                ],
              ),
            );
          },
          build: (context) => [
            // Título principal.
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: verdeOscuro,
                borderRadius: const pw.BorderRadius.all(
                  pw.Radius.circular(8),
                ),
              ),
              child: pw.Row(
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment:
                          pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'REPORTE DE INTERVENCIONES',
                          style: pw.TextStyle(
                            fontSize: 19,
                            color: blanco,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 6),
                        pw.Text(
                          'Historial de acciones y mantenimiento de las pilas',
                          style: pw.TextStyle(
                            fontSize: 9,
                            color: _colorPdf(0xDDE9E1),
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: pw.BoxDecoration(
                      color: verde,
                      borderRadius: const pw.BorderRadius.all(
                        pw.Radius.circular(5),
                      ),
                    ),
                    child: pw.Text(
                      'SMARTCOMPOST',
                      style: pw.TextStyle(
                        fontSize: 9,
                        color: blanco,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 12),

            pw.Text(
              'Fecha de generación: ${_formatearFechaHora(ahora)}',
              style: pw.TextStyle(
                fontSize: 8,
                color: textoSecundario,
              ),
            ),

            pw.SizedBox(height: 12),

            // Resumen de intervenciones.
            pw.Row(
              children: [
                pw.Expanded(
                  child: _tarjetaResumenPdf(
                    'Total de registros',
                    '${listaFiltrada.length}',
                    verdeOscuro,
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  child: _tarjetaResumenPdf(
                    'Completados',
                    '$completadas',
                    verde,
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  child: _tarjetaResumenPdf(
                    'Pendientes',
                    '$pendientes',
                    _colorPdf(0xB96A12),
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  child: _tarjetaResumenPdf(
                    'En revisión',
                    '$enRevision',
                    _colorPdf(0x2865A4),
                  ),
                ),
              ],
            ),

            pw.SizedBox(height: 14),

            // Filtros activos al generar el archivo.
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: _colorPdf(0xF4F7F5),
                border: pw.Border.all(
                  color: borde,
                  width: 0.7,
                ),
                borderRadius: const pw.BorderRadius.all(
                  pw.Radius.circular(6),
                ),
              ),
              child: pw.Column(
                crossAxisAlignment:
                    pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'FILTROS APLICADOS',
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      color: verdeOscuro,
                    ),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Text(
                    'Pila: $nombrePila    |    '
                    'Técnico: $nombreTecnico    |    '
                    'Estado: $nombreEstado',
                    style: pw.TextStyle(
                      fontSize: 8,
                      color: textoOscuro,
                    ),
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 16),

            pw.Text(
              'DETALLE DE INTERVENCIONES',
              style: pw.TextStyle(
                fontSize: 10,
                color: verdeOscuro,
                fontWeight: pw.FontWeight.bold,
              ),
            ),

            pw.SizedBox(height: 7),

            // Tabla del reporte. No se usa headerCount.
            // La primera fila tiene repeat: true.
            pw.Table(
              border: pw.TableBorder.all(
                color: borde,
                width: 0.5,
              ),
              defaultVerticalAlignment:
                  pw.TableCellVerticalAlignment.middle,
              columnWidths: const <int, pw.TableColumnWidth>{
                0: pw.FlexColumnWidth(0.75),
                1: pw.FlexColumnWidth(1.25),
                2: pw.FlexColumnWidth(1.15),
                3: pw.FlexColumnWidth(1.05),
                4: pw.FlexColumnWidth(1.45),
                5: pw.FlexColumnWidth(1.9),
                6: pw.FlexColumnWidth(1.05),
                7: pw.FlexColumnWidth(2.0),
              },
              children: filas,
            ),

            pw.SizedBox(height: 12),

            pw.Container(
              padding: const pw.EdgeInsets.all(9),
              decoration: pw.BoxDecoration(
                color: verdeClaro,
                borderRadius: const pw.BorderRadius.all(
                  pw.Radius.circular(5),
                ),
              ),
              child: pw.Text(
                'Este documento resume las intervenciones incluidas '
                'según los filtros seleccionados en SmartCompost.',
                style: pw.TextStyle(
                  fontSize: 8,
                  color: verdeOscuro,
                ),
              ),
            ),
          ],
        ),
      );

      final bytes = await pdf.save();

      final nombreArchivo =
          'Reporte_Intervenciones_${ahora.year}'
          '${_dosDigitos(ahora.month)}'
          '${_dosDigitos(ahora.day)}_'
          '${_dosDigitos(ahora.hour)}'
          '${_dosDigitos(ahora.minute)}.pdf';

      // Abre el diálogo de impresión o guardado de PDF.
      await Printing.layoutPdf(
        onLayout: (format) async => bytes,
        name: nombreArchivo,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El reporte PDF se generó correctamente.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo generar el PDF: $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _generandoPdf = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _pilaProvider,
      builder: (context, _) {
        if (_pilaProvider.cargando &&
            _pilaProvider.pilas.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final pilasReales = _pilaProvider.pilas;

        final todasLasIntervenciones =
            _obtenerIntervencionesReales(pilasReales);

        final listaFiltrada =
            todasLasIntervenciones.where((item) {
          if (_filtroPila != null &&
              item.pila.id != _filtroPila!.id) {
            return false;
          }

          if (_filtroTecnico != null &&
              _filtroTecnico!.isNotEmpty &&
              item.tecnico != _filtroTecnico) {
            return false;
          }

          if (_filtroEstado != null &&
              _filtroEstado!.isNotEmpty &&
              item.estado != _filtroEstado) {
            return false;
          }

          return true;
        }).toList();

        return Scaffold(
          backgroundColor: AppColors.background,

          // El encabezado conserva el título original.
          // El botón PDF está en el cuerpo, encima de los filtros.
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(70),
            child: AppBar(
              backgroundColor: AppColors.background,
              elevation: 0,
              automaticallyImplyLeading: false,
              title: const Text(
                'Historial de Acciones e Intervenciones',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),

          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),

                SizedBox(
                  width: double.infinity,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      onPressed: _generandoPdf
                          ? null
                          : () => _descargarPdf(listaFiltrada),
                      icon: _generandoPdf
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            )
                          : const Icon(
                              Icons.download,
                              size: 18,
                            ),
                      label: Text(
                        _generandoPdf
                            ? 'Generando PDF...'
                            : 'Descargar Reporte PDF',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Filtros originales.
                _filtros(pilasReales),

                const SizedBox(height: 16),

                // Lista original de intervenciones.
                Expanded(
                  child: listaFiltrada.isEmpty
                      ? const Center(
                          child: Text(
                            'No hay pilas registradas o intervenciones '
                            'con los filtros seleccionados',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: listaFiltrada.length,
                          itemBuilder: (context, index) {
                            final item = listaFiltrada[index];

                            final completado =
                                item.estado == 'Completado';

                            final colorEstado = completado
                                ? AppColors.accent
                                : Colors.orange;

                            return Padding(
                              padding: const EdgeInsets.only(
                                bottom: 12,
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: AppColors.border,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          item.id,
                                          style: const TextStyle(
                                            color: AppColors.textMuted,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12,
                                          ),
                                        ),
                                        const Spacer(),
                                        Container(
                                          padding:
                                              const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: colorEstado.withValues(
                                              alpha: 0.15,
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border: Border.all(
                                              color: colorEstado,
                                            ),
                                          ),
                                          child: Text(
                                            item.estado,
                                            style: TextStyle(
                                              color: colorEstado,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 6),

                                    Text(
                                      '${item.pila.nombre} • ${item.accion}',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),

                                    const SizedBox(height: 4),

                                    Text(
                                      'Fase: ${item.pila.faseLabel} | '
                                      'Técnico: ${item.tecnico}',
                                      style: const TextStyle(
                                        color: AppColors.accent,
                                        fontSize: 13,
                                      ),
                                    ),

                                    const SizedBox(height: 8),

                                    Text(
                                      'Notas: ${item.notas}',
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 12.5,
                                      ),
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


  Widget _chip(
    String texto,
    bool activo,
    VoidCallback onTap,
  ) {
    return Padding(
      padding: const EdgeInsets.only(
        right: 8,
        bottom: 8,
      ),
      child: ChoiceChip(
        label: Text(texto),
        selected: activo,
        onSelected: (_) => onTap(),
        selectedColor: AppColors.accentDark,
        labelStyle: TextStyle(
          color: activo
              ? Colors.white
              : AppColors.textSecondary,
          fontSize: 13,
        ),
        backgroundColor: AppColors.surfaceInput,
        side: const BorderSide(
          color: AppColors.border,
        ),
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
              padding: EdgeInsets.only(
                right: 12,
                bottom: 8,
              ),
              child: Text(
                'PILA',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  letterSpacing: 0.6,
                ),
              ),
            ),
            _chip(
              'Todas',
              _filtroPila == null,
              () => setState(() => _filtroPila = null),
            ),
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
              padding: EdgeInsets.only(
                right: 12,
                bottom: 8,
              ),
              child: Text(
                'TÉCNICO',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  letterSpacing: 0.6,
                ),
              ),
            ),
            _chip(
              'Todos',
              _filtroTecnico == null,
              () => setState(() => _filtroTecnico = null),
            ),
            _chip(
              'Carlos Pérez',
              _filtroTecnico == 'Carlos Pérez',
              () => setState(
                () => _filtroTecnico = 'Carlos Pérez',
              ),
            ),
            _chip(
              'Ana María Gómez',
              _filtroTecnico == 'Ana María Gómez',
              () => setState(
                () => _filtroTecnico = 'Ana María Gómez',
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Padding(
              padding: EdgeInsets.only(
                right: 12,
                bottom: 8,
              ),
              child: Text(
                'ESTADO',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  letterSpacing: 0.6,
                ),
              ),
            ),
            _chip(
              'Todos',
              _filtroEstado == null,
              () => setState(() => _filtroEstado = null),
            ),
            _chip(
              'Completado',
              _filtroEstado == 'Completado',
              () => setState(
                () => _filtroEstado = 'Completado',
              ),
            ),
            _chip(
              'Pendiente',
              _filtroEstado == 'Pendiente',
              () => setState(
                () => _filtroEstado = 'Pendiente',
              ),
            ),
            _chip(
              'En revisión',
              _filtroEstado == 'En revisión',
              () => setState(
                () => _filtroEstado = 'En revisión',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

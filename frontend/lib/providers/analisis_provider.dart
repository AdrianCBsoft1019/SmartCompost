import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../models/analisis.dart';
import '../services/api_service.dart';

enum VistaAnalisis { general, sensores, pilas }

/// Estado de la Vista de Analisis (la usan Administrador y Estudiante;
/// el rol solo cambia lo que se puede editar en otras pantallas).
class AnalisisProvider extends ChangeNotifier {
  final ApiService _api;
  AnalisisProvider([ApiService? api]) : _api = api ?? ApiService();

  String periodo = 'semana'; // semana | mes | anio
  VistaAnalisis vista = VistaAnalisis.general;

  AnalisisResumen? resumen;
  bool cargando = false;
  String? error;

  static const periodos = {'semana': 'Semana', 'mes': 'Mes', 'anio': 'Año'};

  Future<void> cargar() async {
    cargando = true;
    error = null;
    notifyListeners();
    try {
      // Una sola peticion trae general, sensores y pilas: los filtros
      // "Sensores" y "Pilas" reutilizan esos datos sin volver a pedirlos.
      final data = await _api.get('/analisis/resumen', query: {'periodo': periodo});
      resumen = AnalisisResumen.fromJson(data as Map<String, dynamic>);
    } catch (e) {
      error = e.toString();
    } finally {
      cargando = false;
      notifyListeners();
    }
  }

  void cambiarPeriodo(String nuevo) {
    if (nuevo == periodo) return;
    periodo = nuevo;
    cargar();
  }

  void cambiarVista(VistaAnalisis nueva) {
    vista = nueva;
    notifyListeners();
  }

  Future<Uint8List> descargarPdf() =>
      _api.descargar('/analisis/reporte.pdf', query: {'periodo': periodo});
}

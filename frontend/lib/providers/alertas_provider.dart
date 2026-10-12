import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../models/alerta.dart';
import '../models/pila.dart';
import '../services/api_service.dart';

/// Estado de la vista de Alertas (la usan Administrador y Estudiante; es de
/// solo lectura para ambos). El periodo cambia graficas y lista; los filtros
/// de variable, pila y "solo activas" afectan solo a la lista.
class AlertasProvider extends ChangeNotifier {
  final ApiService _api;
  AlertasProvider([ApiService? api]) : _api = api ?? ApiService();

  static const periodos = {'semana': 'Semana', 'mes': 'Mes', 'anio': 'Año'};
  static const limiteLista = 100;

  String periodo = 'semana'; // semana | mes | anio
  String? variable; // temperatura | humedad | co2_ppm | ch4_ppm | nh3_ppm
  String? pilaId;
  bool soloActivas = false;

  AlertasResumen? resumen;
  List<Alerta> alertas = [];
  List<Pila> pilas = [];
  bool cargando = false;
  String? error;

  Map<String, String?> get _queryLista => {
        'periodo': periodo,
        'variable': variable,
        'pila_id': pilaId,
        'solo_activas': soloActivas ? 'true' : null,
        'limite': '$limiteLista',
      };

  List<Alerta> _aLista(dynamic data) => (data as List)
      .map((e) => Alerta.fromJson(e as Map<String, dynamic>))
      .toList();

  /// Carga graficas y lista (primera carga y cambio de periodo).
  Future<void> cargar() async {
    cargando = true;
    error = null;
    notifyListeners();
    try {
      final r = await Future.wait([
        _api.get('/alertas/resumen', query: {'periodo': periodo}),
        _api.get('/alertas/', query: _queryLista),
      ]);
      resumen = AlertasResumen.fromJson(r[0] as Map<String, dynamic>);
      alertas = _aLista(r[1]);
    } catch (e) {
      error = e.toString();
    } finally {
      cargando = false;
      notifyListeners();
    }
  }

  /// Recarga solo la lista (cambio de filtros), sin tocar las graficas.
  Future<void> _cargarLista() async {
    cargando = true;
    error = null;
    notifyListeners();
    try {
      alertas = _aLista(await _api.get('/alertas/', query: _queryLista));
    } catch (e) {
      error = e.toString();
    } finally {
      cargando = false;
      notifyListeners();
    }
  }

  Future<void> cargarPilas() async {
    try {
      final data = await _api.get('/pilas/');
      pilas = (data as List)
          .map((e) => Pila.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => a.nombre.compareTo(b.nombre));
      notifyListeners();
    } catch (_) {
      // Sin pilas solo se pierde el filtro por pila.
    }
  }

  void cambiarPeriodo(String nuevo) {
    if (nuevo == periodo) return;
    periodo = nuevo;
    cargar();
  }

  void filtrarVariable(String? valor) {
    variable = variable == valor ? null : valor;
    _cargarLista();
  }

  void filtrarPila(String? valor) {
    pilaId = pilaId == valor ? null : valor;
    _cargarLista();
  }

  void filtrarActivas(bool valor) {
    soloActivas = valor;
    _cargarLista();
  }

  Future<Uint8List> descargarPdf() =>
      _api.descargar('/alertas/reporte.pdf', query: {'periodo': periodo});
}

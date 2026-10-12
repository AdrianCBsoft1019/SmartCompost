import 'package:flutter/foundation.dart';
import '../models/pila.dart';
import '../models/sensor.dart';
import '../services/api_service.dart';

/// Estado de los sensores: lista con filtros y CRUD.
/// Las pantallas escuchan este ChangeNotifier con ListenableBuilder.
class SensorProvider extends ChangeNotifier {
  final ApiService _api;
  SensorProvider([ApiService? api]) : _api = api ?? ApiService();

  List<Sensor> sensores = [];
  bool cargando = false;
  String? error;

  /// Pilas disponibles (para el filtro y para asignar el sensor a una pila).
  List<Pila> pilas = [];

  // Filtros de la vista de Sensores (los mismos que acepta GET /sensores)
  String busqueda = '';
  String? tipo;
  bool? activo;
  String? pilaId;

  Future<void> cargar() async {
    cargando = true;
    error = null;
    notifyListeners();
    try {
      final data = await _api.get('/sensores/', query: {
        'q': busqueda,
        'tipo': tipo,
        'activo': activo?.toString(),
        'pila_id': pilaId,
      });
      sensores = (data as List)
          .map((e) => Sensor.fromJson(e as Map<String, dynamic>))
          .toList();
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
      // Sin pilas no se puede crear un sensor, pero la lista sigue funcionando.
    }
  }

  void buscar(String texto) {
    busqueda = texto.trim();
    cargar();
  }

  void filtrarTipo(String? valor) {
    tipo = valor;
    cargar();
  }

  void filtrarActivo(bool? valor) {
    activo = valor;
    cargar();
  }

  void filtrarPila(String? valor) {
    pilaId = pilaId == valor ? null : valor;
    cargar();
  }

  Future<void> crear(SensorForm form) async {
    await _api.post('/sensores/', form.toJson());
    await cargar();
  }

  Future<void> actualizar(String id, SensorForm form) async {
    await _api.put('/sensores/$id', form.toJson());
    await cargar();
  }

  Future<void> cambiarActivo(Sensor sensor) async {
    await _api.put('/sensores/${sensor.id}', {'activo': !sensor.activo});
    await cargar();
  }

  Future<void> eliminar(String id) async {
    await _api.delete('/sensores/$id');
    await cargar();
  }
}

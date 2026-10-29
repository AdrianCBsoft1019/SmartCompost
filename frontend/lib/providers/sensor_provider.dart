import 'package:flutter/foundation.dart';
import '../models/pila.dart';
import '../models/sensor.dart';
import '../services/api_service.dart';
import 'notificaciones_provider.dart';


class SensorProvider extends ChangeNotifier {
  final ApiService _api;
  SensorProvider([ApiService? api]) : _api = api ?? ApiService();

  List<Sensor> sensores = [];
  bool cargando = false;
  String? error;


  List<Pila> pilas = [];
 
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

  Future<Set<String>> codigosExistentes() async {
    try {
      final data = await _api.get('/sensores/');
      return (data as List)
          .map((e) =>
              (e as Map<String, dynamic>)['codigo_dispositivo'] as String)
          .map((c) => c.toUpperCase())
          .toSet();
    } catch (_) {
      // Sin conexión con la API: usa los que ya están cargados en la vista.
      return sensores.map((s) => s.codigo.toUpperCase()).toSet();
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


  Future<void> reportarDano(String id, String detalle) async {
    await _api.post('/sensores/$id/dano', {'detalle': detalle});
    await Future.wait([cargar(), NotificacionesProvider.instance.cargar()]);
  }

 
  Future<void> marcarReparado(String id) async {
    await _api.post('/sensores/$id/reparado', {});
    await Future.wait([cargar(), NotificacionesProvider.instance.cargar()]);
  }

  Future<void> eliminar(String id) async {
    await _api.delete('/sensores/$id');
    await cargar();
  }
}

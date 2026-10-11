import 'package:flutter/foundation.dart';
import '../models/pila.dart';
import '../models/pila_detalle.dart';
import '../services/api_service.dart';

/// Estado de las pilas: lista con filtros, CRUD y detalle.
/// Las pantallas escuchan este ChangeNotifier con ListenableBuilder.
class PilaProvider extends ChangeNotifier {
  final ApiService _api;
  PilaProvider([ApiService? api]) : _api = api ?? ApiService();

  List<Pila> pilas = [];
  bool cargando = false;
  String? error;

  // Filtros de la vista de Pilas
  String busqueda = '';
  String? fase;
  String? ubicacion;

  // Detalle
  PilaDetalle? detalle;
  bool cargandoDetalle = false;
  String? errorDetalle;

  /// Ubicaciones conocidas (para los chips de filtro), sin repetir.
  List<String> ubicaciones = [];

  Future<void> cargar() async {
    cargando = true;
    error = null;
    notifyListeners();
    try {
      final data = await _api.get('/pilas/', query: {
        'q': busqueda,
        'fase': fase,
        'ubicacion': ubicacion,
      });
      pilas = (data as List)
          .map((e) => Pila.fromJson(e as Map<String, dynamic>))
          .toList();
      if (fase == null && ubicacion == null && busqueda.isEmpty) {
        ubicaciones = {
          for (final p in pilas)
            if (p.ubicacion != null && p.ubicacion!.isNotEmpty) p.ubicacion!
        }.toList()
          ..sort();
      }
    } catch (e) {
      error = e.toString();
    } finally {
      cargando = false;
      notifyListeners();
    }
  }

  void filtrarFase(String? valor) {
    fase = valor;
    cargar();
  }

  void filtrarUbicacion(String? valor) {
    ubicacion = ubicacion == valor ? null : valor;
    cargar();
  }

  void buscar(String texto) {
    busqueda = texto.trim();
    cargar();
  }

  Future<void> crear(PilaForm form) async {
    await _api.post('/pilas/', form.toJson());
    await cargar();
  }

  Future<void> actualizar(String id, PilaForm form) async {
    await _api.put('/pilas/$id', form.toJson());
    await cargar();
  }

  Future<void> eliminar(String id) async {
    await _api.delete('/pilas/$id');
    await cargar();
  }

  Future<void> cargarDetalle(String id) async {
    cargandoDetalle = true;
    errorDetalle = null;
    notifyListeners();
    try {
      final data = await _api.get('/pilas/$id/detalle');
      detalle = PilaDetalle.fromJson(data as Map<String, dynamic>);
    } catch (e) {
      errorDetalle = e.toString();
    } finally {
      cargandoDetalle = false;
      notifyListeners();
    }
  }
}

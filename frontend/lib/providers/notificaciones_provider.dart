import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/notificacion.dart';
import '../services/api_service.dart';

class NotificacionesProvider extends ChangeNotifier {
  NotificacionesProvider._();
  static final NotificacionesProvider instance = NotificacionesProvider._();

  final ApiService _api = ApiService();

  List<Notificacion> notificaciones = [];
  String? error;

  Timer? _timer;

  /// Ids vistos en la última consulta; null hasta que termina la primera.
  Set<String>? _vistas;

  /// Se llama por cada notificación que aparece después de la primera carga.
  void Function(Notificacion)? onNueva;

  /// Se llama una vez, en la primera carga, si ya hay avisos pendientes.
  void Function(int total)? onPendientes;

  int get total => notificaciones.length;

  void iniciar({Duration cada = const Duration(seconds: 30)}) {
    _timer?.cancel();
    _vistas = null;
    notificaciones = [];
    cargar();
    _timer = Timer.periodic(cada, (_) => cargar());
  }

  /// Detiene la consulta periódica (al salir de la app o cerrar sesión).
  void detener() {
    _timer?.cancel();
    _timer = null;
    _vistas = null;
    notificaciones = [];
  }

  Future<void> cargar() async {
    try {
      final data = await _api.get('/notificaciones/');
      final lista = (data as List)
          .map((e) => Notificacion.fromJson(e as Map<String, dynamic>))
          .toList();
      final previas = _vistas;
      final ids = lista.map((n) => n.id).toSet();
      final huboCambio =
          previas == null || !setEquals(previas, ids) || error != null;

      notificaciones = lista;
      error = null;
      _vistas = ids;

      if (previas == null) {
        if (lista.isNotEmpty) onPendientes?.call(lista.length);
      } else {
        for (final n in lista) {
          if (!previas.contains(n.id)) onNueva?.call(n);
        }
      }
      if (huboCambio) notifyListeners();
    } catch (e) {
      final cambio = error == null;
      error = e.toString();
      if (cambio) notifyListeners();
    }
  }

  /// El administrador indica que el sensor ya fue arreglado.
  Future<void> marcarReparado(String sensorId) async {
    await _api.post('/sensores/$sensorId/reparado', {});
    await cargar();
  }
}

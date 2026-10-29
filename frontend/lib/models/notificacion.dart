/// Aviso que devuelve GET /notificaciones: hoy se genera uno por cada sensor
/// dañado que sigue sin repararse.
class Notificacion {
  final String id;
  final String sensorId;
  final String sensorCodigo;
  final String sensorTipo;
  final String pilaNombre;
  final String? ubicacion;
  final String detalle;
  final String mensaje;
  final DateTime? fecha;

  const Notificacion({
    required this.id,
    required this.sensorId,
    required this.sensorCodigo,
    required this.sensorTipo,
    required this.pilaNombre,
    required this.ubicacion,
    required this.detalle,
    required this.mensaje,
    required this.fecha,
  });

  factory Notificacion.fromJson(Map<String, dynamic> j) => Notificacion(
        id: j['id'] as String,
        sensorId: j['sensor_id'] as String,
        sensorCodigo: j['sensor_codigo'] as String,
        sensorTipo: j['sensor_tipo'] as String,
        pilaNombre: (j['pila_nombre'] as String?) ?? 'Sin pila',
        ubicacion: j['ubicacion'] as String?,
        detalle: (j['detalle'] as String?) ?? '',
        mensaje: j['mensaje'] as String,
        fecha: j['fecha'] == null ? null : DateTime.parse('${j['fecha']}Z'),
      );
}

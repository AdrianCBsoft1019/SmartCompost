/// Modelos de la vista de Alertas (GET /alertas y GET /alertas/resumen).

DateTime _fecha(dynamic v) {
  final s = v as String;
  // El backend manda fechas UTC sin zona horaria: se les agrega la Z.
  final conZona = s.endsWith('Z') || s.contains('+');
  return DateTime.parse(conZona ? s : '${s}Z').toLocal();
}

class Alerta {
  final String id, pilaId, pila, variable, nombre, lado, mensaje;
  final String? ubicacion, sensorCodigo;
  final double valor, limite;
  final DateTime fecha;
  final bool activa;

  const Alerta({
    required this.id,
    required this.pilaId,
    required this.pila,
    required this.ubicacion,
    required this.variable,
    required this.nombre,
    required this.valor,
    required this.limite,
    required this.lado,
    required this.mensaje,
    required this.sensorCodigo,
    required this.fecha,
    required this.activa,
  });

  factory Alerta.fromJson(Map<String, dynamic> j) => Alerta(
        id: j['id'] as String,
        pilaId: j['pila_id'] as String,
        pila: j['pila'] as String,
        ubicacion: j['ubicacion'] as String?,
        variable: j['variable'] as String,
        nombre: j['nombre'] as String,
        valor: (j['valor'] as num).toDouble(),
        limite: (j['limite'] as num).toDouble(),
        lado: j['lado'] as String,
        mensaje: j['mensaje'] as String,
        sensorCodigo: j['sensor_codigo'] as String?,
        fecha: _fecha(j['fecha']),
        activa: j['activa'] as bool,
      );
}

class ConteoVariable {
  final String variable, nombre;
  final int total;
  const ConteoVariable(this.variable, this.nombre, this.total);

  factory ConteoVariable.fromJson(Map<String, dynamic> j) => ConteoVariable(
        j['variable'] as String,
        j['nombre'] as String,
        (j['total'] as num).toInt(),
      );
}

class ConteoPila {
  final String pilaId, pila;
  final String? ubicacion;
  final int total;
  const ConteoPila(this.pilaId, this.pila, this.ubicacion, this.total);

  factory ConteoPila.fromJson(Map<String, dynamic> j) => ConteoPila(
        j['pila_id'] as String,
        j['pila'] as String,
        j['ubicacion'] as String?,
        (j['total'] as num).toInt(),
      );
}

class ConteoSensor {
  final String sensorId, codigo, tipo, pila;
  final int total;
  const ConteoSensor(this.sensorId, this.codigo, this.tipo, this.pila, this.total);

  factory ConteoSensor.fromJson(Map<String, dynamic> j) => ConteoSensor(
        j['sensor_id'] as String,
        j['codigo'] as String,
        j['tipo'] as String,
        j['pila'] as String,
        (j['total'] as num).toInt(),
      );
}

class ConteoDia {
  final String fecha; // AAAA-MM-DD
  final int total;
  const ConteoDia(this.fecha, this.total);

  factory ConteoDia.fromJson(Map<String, dynamic> j) =>
      ConteoDia(j['fecha'] as String, (j['total'] as num).toInt());
}

class AlertasResumen {
  final String periodo;
  final int totalAlertas, alertasActivas, totalLecturas, lecturasFueraDeLimite;
  final double porcentajeFueraDeLimite;
  final List<ConteoVariable> porVariable;
  final List<ConteoPila> porPila;
  final List<ConteoSensor> porSensor;
  final List<ConteoDia> porDia;

  const AlertasResumen({
    required this.periodo,
    required this.totalAlertas,
    required this.alertasActivas,
    required this.totalLecturas,
    required this.lecturasFueraDeLimite,
    required this.porcentajeFueraDeLimite,
    required this.porVariable,
    required this.porPila,
    required this.porSensor,
    required this.porDia,
  });

  factory AlertasResumen.fromJson(Map<String, dynamic> j) {
    List<T> lista<T>(String k, T Function(Map<String, dynamic>) f) =>
        (j[k] as List).map((e) => f(e as Map<String, dynamic>)).toList();
    return AlertasResumen(
      periodo: j['periodo'] as String,
      totalAlertas: (j['total_alertas'] as num).toInt(),
      alertasActivas: (j['alertas_activas'] as num).toInt(),
      totalLecturas: (j['total_lecturas'] as num).toInt(),
      lecturasFueraDeLimite: (j['lecturas_fuera_de_limite'] as num).toInt(),
      porcentajeFueraDeLimite: (j['porcentaje_fuera_de_limite'] as num).toDouble(),
      porVariable: lista('por_variable', ConteoVariable.fromJson),
      porPila: lista('por_pila', ConteoPila.fromJson),
      porSensor: lista('por_sensor', ConteoSensor.fromJson),
      porDia: lista('por_dia', ConteoDia.fromJson),
    );
  }
}

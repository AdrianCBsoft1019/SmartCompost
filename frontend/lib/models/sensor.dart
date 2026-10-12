/// Sensor tal como lo devuelve GET /sensores (incluye el nombre y la planta
/// de su pila para poder listarlo sin pedir cada pila por separado).
class Sensor {
  final String id;
  final String tipo; // humedad | temperatura | ph | gas_ch4 | nivel_agua
  final String codigo;
  final String pilaId;
  final bool activo;
  final DateTime creadoEn;
  final String? pilaNombre;
  final String? ubicacion;

  const Sensor({
    required this.id,
    required this.tipo,
    required this.codigo,
    required this.pilaId,
    required this.activo,
    required this.creadoEn,
    required this.pilaNombre,
    required this.ubicacion,
  });

  factory Sensor.fromJson(Map<String, dynamic> j) => Sensor(
        id: j['id'] as String,
        tipo: j['tipo'] as String,
        codigo: j['codigo_dispositivo'] as String,
        pilaId: j['pila_id'] as String,
        activo: j['activo'] as bool,
        creadoEn: DateTime.parse('${j['creado_en']}Z'),
        pilaNombre: j['pila_nombre'] as String?,
        ubicacion: j['ubicacion'] as String?,
      );

  /// Valor del backend -> texto para mostrar.
  static const tipos = {
    'temperatura': 'Temperatura',
    'humedad': 'Humedad',
    'gas_ch4': 'Gas CH₄',
    'ph': 'pH',
    'nivel_agua': 'Nivel de agua',
  };

  String get tipoLabel => tipos[tipo] ?? tipo;
}

/// Datos que envia el formulario de crear/editar sensor.
class SensorForm {
  final String tipo;
  final String codigo;
  final String pilaId;
  final bool activo;

  const SensorForm({
    required this.tipo,
    required this.codigo,
    required this.pilaId,
    this.activo = true,
  });

  Map<String, dynamic> toJson() => {
        'tipo': tipo,
        'codigo_dispositivo': codigo,
        'pila_id': pilaId,
        'activo': activo,
      };
}

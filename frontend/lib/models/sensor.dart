
class Sensor {
  final String id;
  final String tipo; // humedad | temperatura | ph | gas_ch4 | nivel_agua
  final String codigo;
  final String pilaId;
  final bool activo;
  final DateTime creadoEn;
  final String? pilaNombre;
  final String? ubicacion;
  final bool danado;
  final String? detalleDano;

  const Sensor({
    required this.id,
    required this.tipo,
    required this.codigo,
    required this.pilaId,
    required this.activo,
    required this.creadoEn,
    required this.pilaNombre,
    required this.ubicacion,
    this.danado = false,
    this.detalleDano,
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
        danado: (j['danado'] as bool?) ?? false,
        detalleDano: j['detalle_dano'] as String?,
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


  static const prefijos = {
    'temperatura': 'TMP',
    'humedad': 'HUM',
    'gas_ch4': 'CH4',
    'ph': 'PH',
    'nivel_agua': 'NIV',
  };

  /// Primer código `PREFIJO-NNN` que no usa ningún sensor existente.
  /// [existentes] debe venir en mayúsculas.
  static String codigoSugerido(String tipo, Set<String> existentes) {
    final prefijo = prefijos[tipo] ?? 'SEN';
    var n = 1;
    String codigo;
    do {
      codigo = '$prefijo-${n.toString().padLeft(3, '0')}';
      n++;
    } while (existentes.contains(codigo.toUpperCase()));
    return codigo;
  }
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

/// Pila de compostaje tal como la devuelve GET /pilas (incluye campos
/// calculados por el backend: fase, madurez y ultima lectura).
class Pila {
  final String id;
  final String nombre;
  final String? ubicacion;
  final String estado; // normal | atencion | critico | listo
  final String? responsableId;
  final DateTime fechaInicio;
  final int diasCiclo;
  final String fase; // mesofilica | termofilica | enfriamiento | maduracion
  final double madurezPct;
  final int diasFaltantesFase;
  final double? temperatura;
  final double? humedad;

  const Pila({
    required this.id,
    required this.nombre,
    required this.ubicacion,
    required this.estado,
    required this.responsableId,
    required this.fechaInicio,
    required this.diasCiclo,
    required this.fase,
    required this.madurezPct,
    required this.diasFaltantesFase,
    required this.temperatura,
    required this.humedad,
  });

  factory Pila.fromJson(Map<String, dynamic> j) => Pila(
        id: j['id'] as String,
        nombre: j['nombre'] as String,
        ubicacion: j['ubicacion'] as String?,
        estado: j['estado'] as String,
        responsableId: j['responsable_id'] as String?,
        fechaInicio: DateTime.parse('${j['fecha_inicio']}Z'),
        diasCiclo: (j['dias_ciclo'] as num).toInt(),
        fase: j['fase'] as String,
        madurezPct: (j['madurez_pct'] as num).toDouble(),
        diasFaltantesFase: (j['dias_faltantes_fase'] as num).toInt(),
        temperatura: (j['temperatura'] as num?)?.toDouble(),
        humedad: (j['humedad'] as num?)?.toDouble(),
      );

  static const fases = {
    'mesofilica': 'Mesofílica',
    'termofilica': 'Termofílica',
    'enfriamiento': 'Enfriamiento',
    'maduracion': 'Maduración',
  };

  String get faseLabel => fases[fase] ?? fase;
}

/// Datos que envia el formulario de crear/editar pila.
class PilaForm {
  final String nombre;
  final String? ubicacion;
  final int diasCiclo;
  final DateTime? fechaInicio;

  const PilaForm({
    required this.nombre,
    this.ubicacion,
    this.diasCiclo = 90,
    this.fechaInicio,
  });

  Map<String, dynamic> toJson() => {
        'nombre': nombre,
        if (ubicacion != null && ubicacion!.isNotEmpty) 'ubicacion': ubicacion,
        'dias_ciclo': diasCiclo,
        if (fechaInicio != null)
          'fecha_inicio': fechaInicio!.toUtc().toIso8601String(),
      };
}

double? _d(dynamic v) => (v as num?)?.toDouble();

class Promedios {
  final double? temperatura, humedad, co2, ch4, nh3;
  const Promedios(this.temperatura, this.humedad, this.co2, this.ch4, this.nh3);

  factory Promedios.fromJson(Map<String, dynamic> j) => Promedios(
        _d(j['temperatura']),
        _d(j['humedad']),
        _d(j['co2_ppm']),
        _d(j['ch4_ppm']),
        _d(j['nh3_ppm']),
      );
}

class ComparativaPila {
  final String pilaId, nombre, estado, fase;
  final String? ubicacion;
  final double? temperaturaProm, temperaturaMax, humedadProm;
  final double madurezPct;
  final int lecturasFueraLimite;

  const ComparativaPila({
    required this.pilaId,
    required this.nombre,
    required this.ubicacion,
    required this.estado,
    required this.fase,
    required this.temperaturaProm,
    required this.temperaturaMax,
    required this.humedadProm,
    required this.madurezPct,
    required this.lecturasFueraLimite,
  });

  factory ComparativaPila.fromJson(Map<String, dynamic> j) => ComparativaPila(
        pilaId: j['pila_id'] as String,
        nombre: j['nombre'] as String,
        ubicacion: j['ubicacion'] as String?,
        estado: j['estado'] as String,
        fase: j['fase'] as String,
        temperaturaProm: _d(j['temperatura_prom']),
        temperaturaMax: _d(j['temperatura_max']),
        humedadProm: _d(j['humedad_prom']),
        madurezPct: (j['madurez_pct'] as num).toDouble(),
        lecturasFueraLimite: (j['lecturas_fuera_limite'] as num).toInt(),
      );
}

class AlertaActiva {
  final String pilaId, pila, mensaje;
  const AlertaActiva(this.pilaId, this.pila, this.mensaje);

  factory AlertaActiva.fromJson(Map<String, dynamic> j) => AlertaActiva(
        j['pila_id'] as String,
        j['pila'] as String,
        j['mensaje'] as String,
      );
}

class PuntoTendencia {
  final String fecha;
  final double? co2, ch4, nh3;
  const PuntoTendencia(this.fecha, this.co2, this.ch4, this.nh3);

  factory PuntoTendencia.fromJson(Map<String, dynamic> j) => PuntoTendencia(
        j['fecha'] as String,
        _d(j['co2_ppm']),
        _d(j['ch4_ppm']),
        _d(j['nh3_ppm']),
      );
}

class SensorEstado {
  final String id, codigo, tipo, pila;
  final bool activo;
  final int alteraciones;

  const SensorEstado({
    required this.id,
    required this.codigo,
    required this.tipo,
    required this.pila,
    required this.activo,
    required this.alteraciones,
  });

  factory SensorEstado.fromJson(Map<String, dynamic> j) => SensorEstado(
        id: j['id'] as String,
        codigo: j['codigo'] as String,
        tipo: j['tipo'] as String,
        pila: j['pila'] as String,
        activo: j['activo'] as bool,
        alteraciones: (j['alteraciones'] as num).toInt(),
      );
}

class PlantaSensores {
  final String planta;
  final int total, activos, inactivos;
  final List<SensorEstado> sensores;

  const PlantaSensores(
      this.planta, this.total, this.activos, this.inactivos, this.sensores);

  factory PlantaSensores.fromJson(Map<String, dynamic> j) => PlantaSensores(
        j['planta'] as String,
        (j['total'] as num).toInt(),
        (j['activos'] as num).toInt(),
        (j['inactivos'] as num).toInt(),
        (j['sensores'] as List)
            .map((e) => SensorEstado.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class AnalisisResumen {
  final String periodo;
  final Promedios promedios;
  final int totalLecturas;
  final List<ComparativaPila> comparativa;
  final List<AlertaActiva> alertasActivas;
  final List<PuntoTendencia> tendencia;
  final List<PlantaSensores> sensoresPorPlanta;

  const AnalisisResumen({
    required this.periodo,
    required this.promedios,
    required this.totalLecturas,
    required this.comparativa,
    required this.alertasActivas,
    required this.tendencia,
    required this.sensoresPorPlanta,
  });

  factory AnalisisResumen.fromJson(Map<String, dynamic> j) {
    List<T> lista<T>(String k, T Function(Map<String, dynamic>) f) =>
        (j[k] as List).map((e) => f(e as Map<String, dynamic>)).toList();
    return AnalisisResumen(
      periodo: j['periodo'] as String,
      promedios: Promedios.fromJson(j['promedios'] as Map<String, dynamic>),
      totalLecturas: (j['total_lecturas'] as num).toInt(),
      comparativa: lista('comparativa', ComparativaPila.fromJson),
      alertasActivas: lista('alertas_activas', AlertaActiva.fromJson),
      tendencia: lista('tendencia_semanal', PuntoTendencia.fromJson),
      sensoresPorPlanta: lista('sensores_por_planta', PlantaSensores.fromJson),
    );
  }
}

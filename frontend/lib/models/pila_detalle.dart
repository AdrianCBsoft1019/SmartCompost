import 'pila.dart';

class PuntoHora {
  final DateTime hora;
  final double temperatura;
  final double humedad;

  const PuntoHora(this.hora, this.temperatura, this.humedad);

  factory PuntoHora.fromJson(Map<String, dynamic> j) => PuntoHora(
        DateTime.parse('${j['hora']}Z').toLocal(),
        (j['temperatura'] as num).toDouble(),
        (j['humedad'] as num).toDouble(),
      );
}

class Evaluacion {
  final String semaforo; // verde | amarillo | rojo
  final String indicador; // seguro | inseguro
  final List<String> violaciones;

  const Evaluacion(this.semaforo, this.indicador, this.violaciones);

  factory Evaluacion.fromJson(Map<String, dynamic> j) => Evaluacion(
        j['semaforo'] as String,
        j['indicador'] as String,
        (j['violaciones'] as List).map((e) => e.toString()).toList(),
      );

  bool get esSeguro => indicador == 'seguro';
}

class PilaDetalle {
  final Pila pila;
  final Evaluacion evaluacion;
  final double? co2;
  final double? ch4;
  final double? nh3;
  final List<PuntoHora> serie24h;
  final int diasTranscurridos;

  const PilaDetalle({
    required this.pila,
    required this.evaluacion,
    required this.co2,
    required this.ch4,
    required this.nh3,
    required this.serie24h,
    required this.diasTranscurridos,
  });

  factory PilaDetalle.fromJson(Map<String, dynamic> j) {
    final gases = j['gases'] as Map<String, dynamic>;
    return PilaDetalle(
      pila: Pila.fromJson(j['pila'] as Map<String, dynamic>),
      evaluacion: Evaluacion.fromJson(j['evaluacion'] as Map<String, dynamic>),
      co2: (gases['co2_ppm'] as num?)?.toDouble(),
      ch4: (gases['ch4_ppm'] as num?)?.toDouble(),
      nh3: (gases['nh3_ppm'] as num?)?.toDouble(),
      serie24h: (j['serie_24h'] as List)
          .map((e) => PuntoHora.fromJson(e as Map<String, dynamic>))
          .toList(),
      diasTranscurridos: (j['dias_transcurridos'] as num).toInt(),
    );
  }
}

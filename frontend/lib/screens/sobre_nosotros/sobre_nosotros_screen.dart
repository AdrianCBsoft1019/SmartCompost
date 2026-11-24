import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/marca.dart';
import '../../widgets/responsive.dart';

/// "Sobre nosotros": historia del proyecto, el equipo y fotos del proceso.
///
/// Es una página informativa y de solo lectura: nadie (ni administradores
/// ni estudiantes) puede editarla desde la aplicación. Se abre desde el
/// menú y también desde el inicio de sesión, sin necesidad de cuenta.
class SobreNosotrosScreen extends StatelessWidget {
  /// true cuando se abre como pantalla propia (desde el login).
  final bool pantallaCompleta;
  const SobreNosotrosScreen({super.key, this.pantallaCompleta = false});

  static const _equipo = [
    _Integrante('Nareth Tatiana', 'Ramírez Fuentes', 'NR'),
    _Integrante('Nicolás Santiago', 'Duarte Tabares', 'ND'),
    _Integrante('Roderick Adrián', 'Correa Buitrago', 'RC'),
  ];

  static const _pasos = [
    _Paso(Icons.travel_explore, 'Observamos',
        'Visitamos la planta de compostaje del CBA Mosquera: los residuos estaban amontonados, sin volteo, expuestos al sol y a la lluvia, secos y compactados.'),
    _Paso(Icons.record_voice_over_outlined, 'Escuchamos',
        'Entrevistamos al instructor líder y al encargado de la planta, y encuestamos a los aprendices que hacen las prácticas de compostaje.'),
    _Paso(Icons.edit_note, 'Diseñamos',
        'En marzo de 2026 escribimos los requisitos del sistema: casos de uso, diagramas, base de datos y el diseño de la página web.'),
    _Paso(Icons.memory, 'Construimos',
        'Armamos el prototipo con Arduino UNO + ESP32, sensores de temperatura, humedad y gases, riego y volteo automático, y esta plataforma web.'),
    _Paso(Icons.emoji_events_outlined, 'Presentamos',
        'Llevamos SmartCompost a INNOVATEC VI, la feria de proyectos e innovación del SENA.'),
  ];

  static const _antes = [
    _Foto('assets/images/antes_pila.jpg', 'Pilas amontonadas al aire libre'),
    _Foto('assets/images/antes_compactado.jpg', 'Material seco y compactado'),
    _Foto('assets/images/antes_campo.jpg', 'Compost expuesto al sol y la lluvia'),
    _Foto('assets/images/antes_caseta.jpg', 'Zona de compostaje del CBA'),
  ];

  static const _ahora = [
    _Foto('assets/images/prototipo.jpg', 'Nuestro prototipo con volteo, riego y sensores'),
    _Foto('assets/images/plataforma.jpg', 'La plataforma web con datos en tiempo real', 4 / 3),
    _Foto('assets/images/poster.jpg', 'Póster de INNOVATEC VI'),
  ];

  static const _tecnologias = [
    'C++ / Arduino', 'ESP32', 'Python', 'Flutter', 'MySQL', 'GitHub',
  ];

  @override
  Widget build(BuildContext context) {
    final movil = esMovil(context);
    final contenido = SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _portada(movil),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Padding(
              padding: EdgeInsets.fromLTRB(movil ? 14 : 28, 8, movil ? 14 : 28, 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Aparecer(
                  retrasoMs: 150,
                  child: FilaAdaptable(espacio: 18, children: [
                    const TarjetaPoster(
                      titulo: '¿Qué problema resuelve?',
                      icono: Icons.eco,
                      child: Text(
                        'En el compostaje del CBA, el control manual y poco preciso de la '
                        'temperatura, la humedad y los gases dificulta detectar problemas a '
                        'tiempo, afectando la calidad del abono y la seguridad de quienes lo manejan.',
                        style: _cuerpo,
                      ),
                    ),
                    const TarjetaPoster(
                      titulo: 'Nuestra solución',
                      icono: Icons.lightbulb_outline,
                      child: Text(
                        'Un prototipo físico de compostaje conectado a una plataforma web: '
                        'mezcla, riega y mide las variables del compost para transformar '
                        'los residuos orgánicos en abono de forma más controlada.',
                        style: _cuerpo,
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 22),
                Aparecer(
                  retrasoMs: 300,
                  child: TarjetaPoster(
                    titulo: '¿Cómo surgió todo?',
                    icono: Icons.auto_stories_outlined,
                    child: Column(children: [
                      for (var i = 0; i < _pasos.length; i++)
                        _pasoLinea(_pasos[i], i + 1, i == _pasos.length - 1),
                    ]),
                  ),
                ),
                const SizedBox(height: 22),
                Aparecer(
                  retrasoMs: 450,
                  child: TarjetaPoster(
                    titulo: 'Así empezó',
                    icono: Icons.history,
                    child: _galeria(context, _antes, movil),
                  ),
                ),
                const SizedBox(height: 22),
                Aparecer(
                  retrasoMs: 550,
                  child: TarjetaPoster(
                    titulo: 'Así va ahora',
                    icono: Icons.rocket_launch_outlined,
                    child: _galeria(context, _ahora, movil),
                  ),
                ),
                const SizedBox(height: 22),
                Aparecer(
                  retrasoMs: 650,
                  child: TarjetaPoster(
                    titulo: 'Nuestro equipo',
                    icono: Icons.groups_outlined,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 16,
                        runSpacing: 16,
                        children: [for (final p in _equipo) _tarjetaIntegrante(p)],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Aprendices del SENA · Centro de Biotecnología Agropecuaria, Mosquera. '
                        'Gracias al equipo de la planta de compostaje del CBA por abrirnos sus puertas.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13.5),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 22),
                Aparecer(
                  retrasoMs: 750,
                  child: TarjetaPoster(
                    titulo: 'Tecnologías utilizadas',
                    icono: Icons.code,
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      alignment: WrapAlignment.center,
                      children: [
                        for (final t in _tecnologias)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.limaClara,
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(color: AppColors.lima),
                            ),
                            child: Text(t,
                                style: const TextStyle(
                                    color: AppColors.accentDark,
                                    fontWeight: FontWeight.w700)),
                          ),
                      ],
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 10),
        _pie(movil),
      ]),
    );

    if (!pantallaCompleta) return contenido;
    return Scaffold(
      appBar: AppBar(title: const Text('Sobre nosotros')),
      body: contenido,
    );
  }

  static const _cuerpo = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 15,
    height: 1.45,
  );

  Widget _portada(bool movil) {
    return Column(children: [
      Container(
        width: double.infinity,
        color: AppColors.accent,
        padding: const EdgeInsets.fromLTRB(16, 22, 16, 4),
        child: Column(children: [
          LogoAnimado(size: movil ? 110 : 130),
          const SizedBox(height: 6),
          Text('Sobre nosotros',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppFonts.titulo,
                color: Colors.white,
                fontSize: movil ? 32 : 42,
                shadows: const [Shadow(color: AppColors.accentDark, offset: Offset(2, 3))],
              )),
          const SizedBox(height: 4),
          const Text(
            'Compostaje inteligente: electrónica + software + sostenibilidad',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.limaClara, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (final t in const ['SENA · CBA Mosquera', 'INNOVATEC VI'])
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.amarillo,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(t,
                      style: const TextStyle(
                          color: AppColors.accentDark, fontWeight: FontWeight.w800, fontSize: 12.5)),
                ),
            ],
          ),
        ]),
      ),
      // Borde ondulado inferior, como el encabezado del póster.
      const OndasPoster(altura: 70),
    ]);
  }

  Widget _pasoLinea(_Paso p, int numero, bool ultimo) {
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Column(children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(gradient: kDegradadoVerde, shape: BoxShape.circle),
            child: Icon(p.icono, color: Colors.white, size: 20),
          ),
          if (!ultimo)
            Expanded(
              child: Container(width: 3, color: AppColors.lima, margin: const EdgeInsets.symmetric(vertical: 4)),
            ),
        ]),
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: ultimo ? 0 : 18, top: 6),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$numero. ${p.titulo}',
                  style: const TextStyle(
                      fontFamily: AppFonts.titulo, fontSize: 19, color: AppColors.accentDark)),
              const SizedBox(height: 4),
              Text(p.texto, style: _cuerpo),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _galeria(BuildContext context, List<_Foto> fotos, bool movil) {
    return LayoutBuilder(builder: (context, c) {
      final columnas = movil ? 2 : (fotos.length > 3 ? 4 : 3);
      final ancho = (c.maxWidth - 12 * (columnas - 1)) / columnas;
      return Wrap(spacing: 12, runSpacing: 12, children: [
        for (final f in fotos) _FotoTarjeta(foto: f, ancho: ancho.floorToDouble()),
      ]);
    });
  }

  Widget _tarjetaIntegrante(_Integrante p) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(children: [
        Container(
          width: 76,
          height: 76,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: kDegradadoVerde,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.lima, width: 4),
          ),
          child: Text(p.iniciales,
              style: const TextStyle(
                  fontFamily: AppFonts.titulo, color: Colors.white, fontSize: 26)),
        ),
        const SizedBox(height: 10),
        Text(p.nombre,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        Text(p.apellidos,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        const Text('Equipo de desarrollo',
            style: TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.w700)),
      ]),
    );
  }

  Widget _pie(bool movil) {
    return Stack(children: [
      const OndasPoster(altura: 140, arriba: false),
      Positioned.fill(
        child: Align(
          alignment: const Alignment(0, 0.55),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              '¡Compostaje inteligente que transforma el campo!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppFonts.titulo,
                color: Colors.white,
                fontSize: movil ? 18 : 24,
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}

class _Integrante {
  final String nombre;
  final String apellidos;
  final String iniciales;
  const _Integrante(this.nombre, this.apellidos, this.iniciales);
}

class _Paso {
  final IconData icono;
  final String titulo;
  final String texto;
  const _Paso(this.icono, this.titulo, this.texto);
}

class _Foto {
  final String ruta;
  final String descripcion;
  final double aspecto;
  const _Foto(this.ruta, this.descripcion, [this.aspecto = 3 / 4]);
}

/// Foto con esquinas redondeadas que crece un poco al pasar el mouse y se
/// abre en grande al tocarla.
class _FotoTarjeta extends StatefulWidget {
  final _Foto foto;
  final double ancho;
  const _FotoTarjeta({required this.foto, required this.ancho});

  @override
  State<_FotoTarjeta> createState() => _FotoTarjetaState();
}

class _FotoTarjetaState extends State<_FotoTarjeta> {
  bool _encima = false;

  void _abrir() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        clipBehavior: Clip.antiAlias,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Flexible(
            child: InteractiveViewer(
              child: Image.asset(widget.foto.ruta, fit: BoxFit.contain),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(widget.foto.descripcion,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _encima = true),
      onExit: (_) => setState(() => _encima = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: _abrir,
        child: AnimatedScale(
          scale: _encima ? 1.04 : 1,
          duration: const Duration(milliseconds: 200),
          child: SizedBox(
            width: widget.ancho,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: AspectRatio(
                  aspectRatio: widget.foto.aspecto,
                  child: Image.asset(widget.foto.ruta, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(height: 6),
              Text(widget.foto.descripcion,
                  style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
            ]),
          ),
        ),
      ),
    );
  }
}

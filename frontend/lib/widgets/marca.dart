import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Logo de SmartCompost que "flota" suavemente arriba y abajo.
class LogoAnimado extends StatefulWidget {
  final double size;
  final bool animado;
  const LogoAnimado({super.key, this.size = 96, this.animado = true});

  @override
  State<LogoAnimado> createState() => _LogoAnimadoState();
}

class _LogoAnimadoState extends State<LogoAnimado>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  @override
  void initState() {
    super.initState();
    if (widget.animado) _c.repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final img = Image.asset(
      'assets/images/logo.png',
      width: widget.size,
      height: widget.size,
      fit: BoxFit.contain,
      semanticLabel: 'Logo de SmartCompost',
    );
    if (!widget.animado) return img;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_c.value);
        return Transform.translate(
          offset: Offset(0, -6 * t),
          child: Transform.rotate(angle: (t - 0.5) * 0.06, child: child),
        );
      },
      child: img,
    );
  }
}

/// Nombre "SMARTCOMPOST" con la fuente gruesa del póster.
class NombreMarca extends StatelessWidget {
  final double fontSize;
  final Color color;
  const NombreMarca({super.key, this.fontSize = 28, this.color = AppColors.accentDark});

  @override
  Widget build(BuildContext context) {
    return Text(
      'SMARTCOMPOST',
      style: TextStyle(
        fontFamily: AppFonts.titulo,
        fontSize: fontSize,
        color: color,
        letterSpacing: 1.2,
        shadows: [
          Shadow(
            color: AppColors.lima.withValues(alpha: 0.6),
            offset: const Offset(2, 2),
          ),
        ],
      ),
    );
  }
}

/// Ondas verdes como las del encabezado y pie del póster.
class OndasPoster extends StatelessWidget {
  final double altura;
  final bool arriba;
  const OndasPoster({super.key, this.altura = 220, this.arriba = true});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: altura,
      width: double.infinity,
      child: CustomPaint(painter: _PintorOndas(arriba)),
    );
  }
}

class _PintorOndas extends CustomPainter {
  final bool arriba;
  _PintorOndas(this.arriba);

  @override
  void paint(Canvas canvas, Size size) {
    void onda(Color color, double base, double amp, double fase) {
      final path = Path();
      final w = size.width;
      final h = size.height;
      double y(double x) =>
          base * h + amp * h * math.sin((x / w) * 2 * math.pi + fase);
      if (arriba) {
        path.moveTo(0, 0);
        path.lineTo(0, y(0));
        for (double x = 0; x <= w; x += 8) {
          path.lineTo(x, y(x));
        }
        path.lineTo(w, y(w));
        path.lineTo(w, 0);
      } else {
        path.moveTo(0, h);
        path.lineTo(0, h - y(0));
        for (double x = 0; x <= w; x += 8) {
          path.lineTo(x, h - y(x));
        }
        path.lineTo(w, h - y(w));
        path.lineTo(w, h);
      }
      path.close();
      canvas.drawPath(path, Paint()..color = color);
    }

    onda(AppColors.limaClara, 0.92, 0.08, 0.6);
    onda(AppColors.lima.withValues(alpha: 0.85), 0.78, 0.09, 2.2);
    onda(AppColors.accent, 0.62, 0.08, 4.0);
  }

  @override
  bool shouldRepaint(covariant _PintorOndas old) => old.arriba != arriba;
}

/// Hace aparecer a su hijo deslizándose hacia arriba con un pequeño retraso.
class Aparecer extends StatefulWidget {
  final Widget child;
  final int retrasoMs;
  const Aparecer({super.key, required this.child, this.retrasoMs = 0});

  @override
  State<Aparecer> createState() => _AparecerState();
}

class _AparecerState extends State<Aparecer> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 550),
  );

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: widget.retrasoMs), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curva = CurvedAnimation(parent: _c, curve: Curves.easeOutBack);
    return FadeTransition(
      opacity: _c,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.12), end: Offset.zero).animate(curva),
        child: widget.child,
      ),
    );
  }
}

/// Encabezado verde con esquinas redondeadas, igual a las secciones del
/// póster ("¿QUÉ PROBLEMA RESUELVE?", "OBJETIVO"...).
class EncabezadoPoster extends StatelessWidget {
  final String texto;
  final IconData icono;
  const EncabezadoPoster(this.texto, this.icono, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: const BoxDecoration(
        gradient: kDegradadoVerde,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: const BoxDecoration(color: AppColors.lima, shape: BoxShape.circle),
          child: Icon(icono, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            texto.toUpperCase(),
            style: const TextStyle(
              fontFamily: AppFonts.titulo,
              color: Colors.white,
              fontSize: 20,
              letterSpacing: 1,
            ),
          ),
        ),
      ]),
    );
  }
}

/// Tarjeta del póster: encabezado verde + cuerpo crema con borde verde.
class TarjetaPoster extends StatelessWidget {
  final String titulo;
  final IconData icono;
  final Widget child;
  const TarjetaPoster({super.key, required this.titulo, required this.icono, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.accent, width: 1.6),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentDark.withValues(alpha: 0.12),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        EncabezadoPoster(titulo, icono),
        Padding(padding: const EdgeInsets.all(18), child: child),
      ]),
    );
  }
}

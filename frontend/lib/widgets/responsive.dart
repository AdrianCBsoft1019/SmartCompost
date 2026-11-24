import 'package:flutter/material.dart';

/// Ancho a partir del cual se considera pantalla de celular.
const double kAnchoMovil = 700;

/// true cuando la ventana es angosta (celulares y tablets en vertical).
bool esMovil(BuildContext context) =>
    MediaQuery.sizeOf(context).width < kAnchoMovil;

/// Margen exterior de las pantallas: más pequeño en el celular.
EdgeInsets paddingPantalla(BuildContext context) =>
    EdgeInsets.all(esMovil(context) ? 14 : 20);

/// Fila que se convierte en columna en pantallas angostas.
///
/// En horizontal cada hijo ocupa su parte (`flex`) del ancho; en vertical
/// los hijos se apilan uno debajo de otro ocupando todo el ancho.
class FilaAdaptable extends StatelessWidget {
  final List<Widget> children;
  final List<int>? flex;
  final double espacio;
  final bool? vertical;

  const FilaAdaptable({
    super.key,
    required this.children,
    this.flex,
    this.espacio = 16,
    this.vertical,
  });

  @override
  Widget build(BuildContext context) {
    final apilar = vertical ?? esMovil(context);
    final items = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        items.add(SizedBox(width: espacio, height: espacio));
      }
      items.add(apilar
          ? children[i]
          : Expanded(flex: flex?[i] ?? 1, child: children[i]));
    }
    return apilar
        ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: items)
        : Row(crossAxisAlignment: CrossAxisAlignment.start, children: items);
  }
}

/// Permite desplazar horizontalmente una tabla ancha en el celular en vez
/// de aplastar sus columnas.
class TablaDesplazable extends StatelessWidget {
  final double anchoMinimo;
  final Widget child;

  const TablaDesplazable({super.key, required this.anchoMinimo, required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth >= anchoMinimo) return child;
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(width: anchoMinimo, child: child),
      );
    });
  }
}

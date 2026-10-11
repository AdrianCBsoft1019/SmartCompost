import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Tarjeta oscura con borde, usada por Pilas, Detalle y Analisis.
class PanelCard extends StatelessWidget {
  final String? titulo;
  final String? subtitulo;
  final Widget? accion;
  final Widget child;
  final EdgeInsets padding;

  const PanelCard({
    super.key,
    this.titulo,
    this.subtitulo,
    this.accion,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (titulo != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(titulo!,
                            style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 15)),
                        if (subtitulo != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(subtitulo!,
                                style: const TextStyle(
                                    color: AppColors.textMuted, fontSize: 12)),
                          ),
                      ],
                    ),
                  ),
                  if (accion != null) accion!,
                ],
              ),
            ),
          child,
        ],
      ),
    );
  }
}

class EstadoVacio extends StatelessWidget {
  final String mensaje;
  final VoidCallback? onReintentar;
  const EstadoVacio(this.mensaje, {super.key, this.onReintentar});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(mensaje,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary)),
            if (onReintentar != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(onPressed: onReintentar, child: const Text('Reintentar')),
            ],
          ],
        ),
      ),
    );
  }
}

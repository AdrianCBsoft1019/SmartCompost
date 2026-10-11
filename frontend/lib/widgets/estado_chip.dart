import 'package:flutter/material.dart';

/// Colores del semaforo / estado de una pila (iguales a los de Stitch).
class EstadoColores {
  static const verde = Color(0xFF10B981);
  static const amarillo = Color(0xFFEAB308);
  static const rojo = Color(0xFFEF4444);
  static const azul = Color(0xFF3B82F6);

  static Color deEstado(String estado) {
    switch (estado) {
      case 'critico':
        return rojo;
      case 'atencion':
        return amarillo;
      case 'listo':
        return azul;
      default:
        return verde;
    }
  }

  static Color deSemaforo(String semaforo) {
    switch (semaforo) {
      case 'rojo':
        return rojo;
      case 'amarillo':
        return amarillo;
      default:
        return verde;
    }
  }

  static String etiqueta(String estado) {
    switch (estado) {
      case 'critico':
        return 'CRÍTICO';
      case 'atencion':
        return 'ATENCIÓN';
      case 'listo':
        return 'LISTO';
      default:
        return 'ÓPTIMO';
    }
  }
}

class EstadoChip extends StatelessWidget {
  final String estado;
  const EstadoChip(this.estado, {super.key});

  @override
  Widget build(BuildContext context) {
    final color = EstadoColores.deEstado(estado);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        EstadoColores.etiqueta(estado),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

import 'package:flutter/foundation.dart';
import '../models/usuario.dart';

/// Usuario autenticado. Las pantallas lo leen para decidir que mostrar
/// segun el rol (instructor = Administrador, aprendiz = Estudiante).
class Session extends ChangeNotifier {
  Session._();
  static final Session instance = Session._();

  Usuario? _usuario;
  Usuario? get usuario => _usuario;
  set usuario(Usuario? valor) {
    _usuario = valor;
    notifyListeners();
  }

  bool get esAdmin => _usuario?.esAdmin ?? false;
}

import 'package:flutter/material.dart';
import '../screens/analisis/analisis_screen.dart';
import '../screens/perfil/perfil_screen.dart';
import '../screens/perfil/usuarios_screen.dart';
import '../screens/pilas/pilas_screen.dart';
import '../services/session.dart';
import '../theme/app_theme.dart';

class _Destino {
  final String titulo;
  final IconData icono;
  final Widget Function() pantalla;
  final bool soloAdmin;
  const _Destino(this.titulo, this.icono, this.pantalla, {this.soloAdmin = false});
}

/// Marco de la app autenticada: menu lateral + avatar de usuario.
///
/// Para agregar una pantalla de otro modulo (Dashboard, Alertas, Sensores,
/// Historial) basta con anadir un `_Destino` a la lista de abajo.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _indice = 0;

  static final List<_Destino> _todos = [
    _Destino('Pilas', Icons.eco_outlined, () => const PilasScreen()),
    _Destino('Análisis', Icons.bar_chart_rounded, () => const AnalisisScreen()),
    _Destino('Usuarios', Icons.people_outline, () => const UsuariosScreen(),
        soloAdmin: true),
  ];

  List<_Destino> get _destinos =>
      _todos.where((d) => !d.soloAdmin || Session.instance.esAdmin).toList();

  void _abrirPerfil() => Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => const PerfilScreen()))
      .then((_) => setState(() {})); // refresca el avatar si cambio el nombre

  Widget _avatar() {
    final u = Session.instance.usuario;
    return Tooltip(
      message: 'Mi perfil',
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: _abrirPerfil,
        child: CircleAvatar(
          radius: 18,
          backgroundColor: AppColors.accentDark,
          child: Text(u?.iniciales ?? '?',
              style: const TextStyle(
                  color: Colors.black, fontWeight: FontWeight.w800, fontSize: 13)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final destinos = _destinos;
    if (_indice >= destinos.length) _indice = 0;
    final actual = destinos[_indice];
    final u = Session.instance.usuario;

    return LayoutBuilder(builder: (context, c) {
      final ancho = c.maxWidth >= 900;
      final contenido = KeyedSubtree(key: ValueKey(actual.titulo), child: actual.pantalla());

      if (ancho) {
        return Scaffold(
          body: Row(children: [
            Container(
              width: 230,
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(right: BorderSide(color: AppColors.border)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 28, 20, 24),
                  child: Text('SMARTCOMPOST',
                      style: TextStyle(
                          color: AppColors.accent,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1)),
                ),
                for (var i = 0; i < destinos.length; i++)
                  ListTile(
                    leading: Icon(destinos[i].icono,
                        color: i == _indice ? AppColors.accent : AppColors.textSecondary),
                    title: Text(destinos[i].titulo,
                        style: TextStyle(
                            color: i == _indice
                                ? AppColors.accent
                                : AppColors.textSecondary,
                            fontWeight: FontWeight.w600)),
                    selected: i == _indice,
                    selectedTileColor: AppColors.accent.withOpacity(0.08),
                    onTap: () => setState(() => _indice = i),
                  ),
                const Spacer(),
                ListTile(
                  leading: _avatar(),
                  title: Text(u?.nombreCompleto ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13)),
                  subtitle: Text(u?.esAdmin == true ? 'Administrador' : 'Estudiante',
                      style: const TextStyle(color: AppColors.accent, fontSize: 11)),
                  onTap: _abrirPerfil,
                ),
              ]),
            ),
            Expanded(child: contenido),
          ]),
        );
      }

      return Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.background,
          title: Text(actual.titulo),
          actions: [
            Padding(padding: const EdgeInsets.only(right: 14), child: _avatar()),
          ],
        ),
        body: contenido,
        bottomNavigationBar: NavigationBar(
          backgroundColor: AppColors.surface,
          selectedIndex: _indice,
          onDestinationSelected: (i) => setState(() => _indice = i),
          destinations: [
            for (final d in destinos)
              NavigationDestination(icon: Icon(d.icono), label: d.titulo),
          ],
        ),
      );
    });
  }
}

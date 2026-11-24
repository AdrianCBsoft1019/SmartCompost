import 'package:flutter/material.dart';
import '../screens/alertas/alertas_screen.dart';
import '../screens/analisis/analisis_screen.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/intervenciones/intervenciones_screen.dart'; // <--- Importación añadida
import '../screens/perfil/perfil_screen.dart';
import '../screens/perfil/usuarios_screen.dart';
import '../screens/pilas/pilas_screen.dart';
import '../screens/sensores/sensores_screen.dart';
import '../screens/sobre_nosotros/sobre_nosotros_screen.dart';
import '../models/usuario.dart';
import '../providers/notificaciones_provider.dart';
import '../screens/login_screen.dart';
import '../services/api_service.dart';
import '../services/session.dart';
import '../theme/app_theme.dart';
import 'avatar_usuario.dart';
import 'campana_notificaciones.dart';
import 'estado_chip.dart';
import 'marca.dart';

class _Destino {
  final String titulo;
  final IconData icono;
  final Widget Function() pantalla;
  final bool soloAdmin;
  const _Destino(this.titulo, this.icono, this.pantalla, {this.soloAdmin = false});
}


class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _indice = 0;

  @override
  void initState() {
    super.initState();
    _sincronizarSesion();
    _configurarNotificaciones();
  }

  @override
  void dispose() {
    final avisos = NotificacionesProvider.instance;
    avisos.onNueva = null;
    avisos.onPendientes = null;
    avisos.detener();
    super.dispose();
  }

  /// Avisa (SnackBar rojo) cuando un sensor se daña y requiere arreglo.
  void _configurarNotificaciones() {
    final avisos = NotificacionesProvider.instance;
    avisos.onNueva = (n) => _avisar(n.mensaje);
    avisos.onPendientes = (total) => _avisar(total == 1
        ? 'Hay 1 sensor dañado que requiere arreglo.'
        : 'Hay $total sensores dañados que requieren arreglo.');
    avisos.iniciar();
  }

  void _avisar(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        backgroundColor: EstadoColores.rojo,
        duration: const Duration(seconds: 10),
        content: Text(texto),
        action: SnackBarAction(
          label: 'VER',
          textColor: Colors.white,
          onPressed: () => mostrarNotificaciones(context),
        ),
      ));
  }


  Future<void> _sincronizarSesion() async {
    try {
      final data = await ApiService().get('/auth/me');
      Session.instance.usuario =
          Usuario.fromJson(data as Map<String, dynamic>);
      if (mounted) setState(() {});
    } catch (_) {
      // Token invalido o expirado: ApiService ya limpio la sesion.
      if (mounted && Session.instance.usuario == null) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    }
  }

  static final List<_Destino> _todos = [
    _Destino('Dashboard', Icons.dashboard_outlined, () => const DashboardScreen()),
    _Destino('Pilas', Icons.eco_outlined, () => const PilasScreen()),
    _Destino('Análisis', Icons.bar_chart_rounded, () => const AnalisisScreen()),
    _Destino('Intervenciones', Icons.assignment_outlined, () => const IntervencionesScreen()), // <--- Añadido aquí
    _Destino('Alertas', Icons.notifications_active_outlined,
        () => const AlertasScreen()),
    _Destino('Sensores', Icons.sensors, () => const SensoresScreen()),
    _Destino('Usuarios', Icons.people_outline, () => const UsuariosScreen(),
        soloAdmin: true),
    // Página informativa de solo lectura, visible para todos.
    _Destino('Sobre nosotros', Icons.info_outline,
        () => const SobreNosotrosScreen()),
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
        child: u == null
            ? const CircleAvatar(radius: 18, child: Text('?'))
            : AvatarUsuario(usuario: u, radius: 18),
      ),
    );
  }

  /// Menú verde estilo póster. En escritorio va fijo a la izquierda; en el
  /// celular se abre con el botón de hamburguesa (Drawer).
  Widget _menu(List<_Destino> destinos, Usuario? u, {required bool enDrawer}) {
    void ir(int i) {
      if (enDrawer) Navigator.of(context).pop();
      setState(() => _indice = i);
    }

    Widget item(IconData icono, String titulo, bool activo, VoidCallback onTap,
        {Widget? leading}) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(30),
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              decoration: BoxDecoration(
                color: activo ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(30),
                boxShadow: activo
                    ? [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 8, offset: const Offset(0, 3))]
                    : null,
              ),
              child: Row(children: [
                IconTheme(
                  data: IconThemeData(
                      color: activo ? AppColors.accentDark : Colors.white, size: 22),
                  child: leading ?? Icon(icono),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(titulo,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: activo ? AppColors.accentDark : Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14.5)),
                ),
              ]),
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.accentDark, AppColors.accent],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SizedBox(height: 16),
          const Center(child: LogoAnimado(size: 84)),
          const Center(child: NombreMarca(fontSize: 22, color: Colors.white)),
          const SizedBox(height: 14),
          Expanded(
            child: ListView(padding: EdgeInsets.zero, children: [
              for (var i = 0; i < destinos.length; i++)
                item(destinos[i].icono, destinos[i].titulo, i == _indice, () => ir(i)),
            ]),
          ),
          if (!enDrawer)
            item(Icons.notifications, 'Notificaciones', false,
                () => mostrarNotificaciones(context),
                leading: const IconoCampana()),
          const Divider(height: 1, color: Colors.white24),
          ListTile(
            leading: _avatar(),
            title: Text(u?.nombreCompleto ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 13, color: Colors.white, fontWeight: FontWeight.w700)),
            subtitle: Text(u?.esAdmin == true ? 'Administrador' : 'Estudiante',
                style: const TextStyle(color: AppColors.limaClara, fontSize: 11)),
            onTap: () {
              if (enDrawer) Navigator.of(context).pop();
              _abrirPerfil();
            },
          ),
        ]),
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
      // Cambio de sección con un desvanecido + leve deslizamiento.
      final contenido = AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        switchInCurve: Curves.easeOutCubic,
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, 0.03), end: Offset.zero).animate(anim),
            child: child,
          ),
        ),
        child: KeyedSubtree(key: ValueKey(actual.titulo), child: actual.pantalla()),
      );

      if (ancho) {
        return Scaffold(
          body: Row(children: [
            SizedBox(width: 240, child: _menu(destinos, u, enDrawer: false)),
            Expanded(child: contenido),
          ]),
        );
      }

      return Scaffold(
        appBar: AppBar(
          titleSpacing: 0,
          title: Text(actual.titulo, overflow: TextOverflow.ellipsis),
          actions: [
            const CampanaNotificaciones(),
            Padding(padding: const EdgeInsets.only(right: 14), child: _avatar()),
          ],
        ),
        drawer: Drawer(child: _menu(destinos, u, enDrawer: true)),
        body: contenido,
      );
    });
  }
}

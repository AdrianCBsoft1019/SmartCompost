import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../widgets/app_shell.dart';
import 'register_screen.dart';
import 'sobre_nosotros/sobre_nosotros_screen.dart';
import '../widgets/marca.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _correoCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _api = ApiService();

  bool _obscure = true;
  bool _recordarSesion = false;
  bool _cargando = false;
  String? _error;

  @override
  void dispose() {
    _correoCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _iniciarSesion() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      await _api.login(correo: _correoCtrl.text.trim(), password: _passwordCtrl.text);
      if (!mounted) return;
      // Sesion iniciada: entra a la app (el rol decide que menus se ven).
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AppShell()),
      );
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(children: [
        const Positioned(top: 0, left: 0, right: 0, child: OndasPoster(altura: 200)),
        const Positioned(bottom: 0, left: 0, right: 0, child: OndasPoster(altura: 90, arriba: false)),
        Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              children: [
                _buildBrandHeader(),
                const SizedBox(height: 14),
                // Pública: los visitantes (por ejemplo, desde el QR del
                // póster) pueden conocer el proyecto sin tener cuenta.
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: AppColors.amarillo,
                    foregroundColor: AppColors.accentDark,
                    side: const BorderSide(color: AppColors.accentDark, width: 1.6),
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                  ),
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const SobreNosotrosScreen(pantallaCompleta: true))),
                  icon: const Icon(Icons.eco),
                  label: const Text('¡Conoce el proyecto y al equipo!'),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: EdgeInsets.all(
                      MediaQuery.sizeOf(context).width < 420 ? 20 : 28),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: AppColors.accent, width: 1.6),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accentDark.withValues(alpha: 0.15),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '¡Bienvenido!',
                          style: TextStyle(
                            color: AppColors.accentDark,
                            fontSize: 28,
                            fontFamily: AppFonts.titulo,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Ingresa tus credenciales para continuar',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 13.5),
                        ),
                        const SizedBox(height: 24),

                        const _FieldLabel('Correo electrónico'),
                        TextFormField(
                          controller: _correoCtrl,
                          keyboardType: TextInputType.emailAddress,
                          style: const TextStyle(color: AppColors.textPrimary),
                          decoration: const InputDecoration(
                            hintText: 'nombre@empresa.com',
                            prefixIcon: Icon(Icons.mail_outline, color: AppColors.textMuted, size: 20),
                          ),
                          validator: (v) => (v == null || !v.contains('@'))
                              ? 'Ingresa un correo válido'
                              : null,
                        ),
                        const SizedBox(height: 16),

                        const _FieldLabel('Contraseña'),
                        TextFormField(
                          controller: _passwordCtrl,
                          obscureText: _obscure,
                          style: const TextStyle(color: AppColors.textPrimary),
                          decoration: InputDecoration(
                            hintText: '••••••••',
                            prefixIcon: const Icon(Icons.lock_outline, color: AppColors.textMuted, size: 20),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                color: AppColors.textMuted,
                                size: 20,
                              ),
                              onPressed: () => setState(() => _obscure = !_obscure),
                            ),
                          ),
                          validator: (v) =>
                              (v == null || v.length < 8) ? 'Mínimo 8 caracteres' : null,
                        ),
                        const SizedBox(height: 12),

                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            InkWell(
                              onTap: () => setState(() => _recordarSesion = !_recordarSesion),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Checkbox(
                                    value: _recordarSesion,
                                    activeColor: AppColors.accent,
                                    onChanged: (v) => setState(() => _recordarSesion = v ?? false),
                                  ),
                                  const Text('Recordar mi sesión',
                                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: () {},
                              child: const Text('¿Olvidaste tu contraseña?',
                                  style: TextStyle(color: AppColors.accent, fontSize: 13)),
                            ),
                          ],
                        ),

                        if (_error != null) ...[
                          const SizedBox(height: 4),
                          Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                        ],

                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: _cargando ? null : _iniciarSesion,
                          child: _cargando
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text('Iniciar Sesión'),
                                    SizedBox(width: 6),
                                    Icon(Icons.arrow_forward, size: 18),
                                  ],
                                ),
                        ),

                        const SizedBox(height: 18),
                        Center(
                          child: RichText(
                            text: TextSpan(
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13.5),
                              children: [
                                const TextSpan(text: '¿No tienes cuenta? '),
                                TextSpan(
                                  text: 'Crear cuenta',
                                  style: const TextStyle(
                                    color: AppColors.accent,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  recognizer: TapGestureRecognizer()
                                    ..onTap = () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(builder: (_) => const RegisterScreen()),
                                      );
                                    },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      ]),
    );
  }

  Widget _buildBrandHeader() {
    return const Column(
      children: [
        LogoAnimado(size: 130),
        NombreMarca(fontSize: 30),
        SizedBox(height: 2),
        Text(
          'Compostaje inteligente: electrónica + software + sostenibilidad',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
    );
  }
}


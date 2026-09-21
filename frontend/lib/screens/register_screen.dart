import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../models/rol_usuario.dart';
import 'login_screen.dart';

/// Pantalla de Registro — replica el mockup "SmartCompost - Registro (Oscuro)".
/// HU-10: crea un usuario con rol (instructor/aprendiz); la contraseña
/// nunca se envia ni se guarda en texto plano (se hashea en el backend).
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _correoCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _api = ApiService();

  RolUsuario _rol = RolUsuario.aprendiz;
  bool _obscure = true;
  bool _aceptaTerminos = false;
  bool _cargando = false;
  String? _error;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _correoCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _registrar() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_aceptaTerminos) {
      setState(() => _error = 'Debes aceptar los Términos de Servicio');
      return;
    }
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      await _api.registrar(
        nombreCompleto: _nombreCtrl.text.trim(),
        correo: _correoCtrl.text.trim(),
        password: _passwordCtrl.text,
        rol: _rol.value,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cuenta creada. Ya puedes iniciar sesión.')),
      );
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: isWide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: _buildBrandPanel()),
                        const SizedBox(width: 24),
                        Expanded(child: SingleChildScrollView(child: _buildFormCard())),
                      ],
                    )
                  : SingleChildScrollView(child: _buildFormCard()),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBrandPanel() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF102A24), Color(0xFF0B0D10)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          RichText(
            text: const TextSpan(
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, height: 1.3),
              children: [
                TextSpan(text: 'Gestiona tu compostaje de forma ', style: TextStyle(color: Colors.white)),
                TextSpan(text: 'inteligente', style: TextStyle(color: AppColors.accent)),
                TextSpan(text: ' con SmartCompost', style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Monitorea humedad, temperatura, pH y gases de tus pilas en '
            'tiempo real, y actúa antes de que se conviertan en un problema.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 28),
          const _BulletItem('Alertas automáticas en tiempo real'),
          const _BulletItem('Control de volteo manual o programado'),
          const _BulletItem('Acceso seguro por roles (instructor / aprendiz)'),
          const SizedBox(height: 28),
          const Text(
            'Centro de Biotecnología Agropecuaria — SENA Mosquera',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Crear cuenta',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text('Comienza a monitorear tus pilas de compost',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13.5)),
            const SizedBox(height: 24),

            const _FieldLabel('Nombre completo'),
            TextFormField(
              controller: _nombreCtrl,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                hintText: 'Ej. Juan Pérez',
                prefixIcon: Icon(Icons.person_outline, color: AppColors.textMuted, size: 20),
              ),
              validator: (v) => (v == null || v.trim().length < 3) ? 'Ingresa tu nombre completo' : null,
            ),
            const SizedBox(height: 16),

            const _FieldLabel('Rol'),
            DropdownButtonFormField<RolUsuario>(
              value: _rol,
              dropdownColor: AppColors.surfaceInput,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.badge_outlined, color: AppColors.textMuted, size: 20),
              ),
              items: RolUsuario.values
                  .map((r) => DropdownMenuItem(value: r, child: Text(r.label)))
                  .toList(),
              onChanged: (v) => setState(() => _rol = v ?? RolUsuario.aprendiz),
            ),
            const SizedBox(height: 16),

            const _FieldLabel('Correo electrónico'),
            TextFormField(
              controller: _correoCtrl,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                hintText: 'nombre@correo.com',
                prefixIcon: Icon(Icons.mail_outline, color: AppColors.textMuted, size: 20),
              ),
              validator: (v) => (v == null || !v.contains('@')) ? 'Ingresa un correo válido' : null,
            ),
            const SizedBox(height: 16),

            const _FieldLabel('Contraseña'),
            TextFormField(
              controller: _passwordCtrl,
              obscureText: _obscure,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Mínimo 8 caracteres',
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
              validator: (v) => (v == null || v.length < 8) ? 'Mínimo 8 caracteres' : null,
            ),
            const SizedBox(height: 14),

            InkWell(
              onTap: () => setState(() => _aceptaTerminos = !_aceptaTerminos),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: _aceptaTerminos,
                    activeColor: AppColors.accent,
                    onChanged: (v) => setState(() => _aceptaTerminos = v ?? false),
                  ),
                  const Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Text(
                        'Acepto los Términos de Servicio y la Política de Privacidad',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 4),
              Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
            ],

            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _cargando ? null : _registrar,
              child: _cargando
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    )
                  : const Text('Registrarse'),
            ),

            const SizedBox(height: 18),
            Center(
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13.5),
                  children: [
                    const TextSpan(text: '¿Ya tienes cuenta? '),
                    TextSpan(
                      text: 'Iniciar sesión',
                      style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w600),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () => Navigator.of(context).pushReplacement(
                              MaterialPageRoute(builder: (_) => const LoginScreen()),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
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

class _BulletItem extends StatelessWidget {
  final String text;
  const _BulletItem(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle, color: AppColors.accent, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13.5)),
          ),
        ],
      ),
    );
  }
}

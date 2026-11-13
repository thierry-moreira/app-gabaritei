import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/app_exception.dart';
import '../../core/providers.dart';
import '../../core/ui/responsive.dart';

/// Tela de Recuperação de Senha - Gabaritei Questões
///
/// Implementação fiel ao design do Stitch (project: 5146871290008903931)
/// com identidade visual: azul/índigo/violeta, cards suaves, gradientes.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;

  // Cores da marca (igual ao Tailwind config do Stitch)
  static const Color _brand50 = Color(0xFFEEF6FF);
  static const Color _brand100 = Color(0xFFDBEAFE);
  static const Color _brand200 = Color(0xFFBFDBFE);
  static const Color _brand600 = Color(0xFF2563EB);
  static const Color _brand700 = Color(0xFF1D4ED8);
  static const Color _violet = Color(0xFF7C3AED);
  static const Color _slate50 = Color(0xFFF8FAFC);
  static const Color _slate100 = Color(0xFFF1F5F9);
  static const Color _slate200 = Color(0xFFE2E8F0);
  static const Color _slate400 = Color(0xFF94A3B8);
  static const Color _slate500 = Color(0xFF64748B);
  static const Color _slate700 = Color(0xFF334155);
  static const Color _slate800 = Color(0xFF1E293B);
  static const Color _slate900 = Color(0xFF0F172A);

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Informe seu e-mail';
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim())) {
      return 'Informe um e-mail válido';
    }
    return null;
  }

  Future<void> _handleSendResetLink() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await ref
          .read(authRepositoryProvider)
          .recuperarSenha(_emailController.text);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Link de recuperação enviado! Verifique seu e-mail.',
          ),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      context.go('/login');
    } on AppException catch (error) {
      if (mounted) _mostrarErro(error.message);
    } catch (_) {
      if (mounted) _mostrarErro('Não foi possível enviar o link agora.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _mostrarErro(String mensagem) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(mensagem),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final safeTop = mediaQuery.padding.top;
    final safeBottom = mediaQuery.padding.bottom;

    return Scaffold(
      // Fundo com gradientes radiais (bg-canvas do Stitch)
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_slate50, _slate50],
            stops: [0.0, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // Glow radial superior esquerdo
            Positioned(
              top: -80,
              left: -60,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _brand100.withValues(alpha: 0.5),
                      _slate50.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
            // Glow radial inferior direito
            Positioned(
              bottom: -100,
              right: -80,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFEDE9FE).withValues(alpha: 0.45),
                      _slate50.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
            // Conteúdo principal
            SafeArea(
              child: Column(
                children: [
                  // Header
                  _buildHeader(safeTop),
                  // Main Content
                  Expanded(child: _buildMainContent()),
                  // Footer
                  _buildFooter(safeBottom),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(double safeTop) {
    final responsive = Responsive.of(context);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        responsive.isCompact ? 20 : 24,
        safeTop + 8,
        responsive.isCompact ? 20 : 24,
        4,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: responsive.authMaxWidth),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              // Badge com ícone de formatura
              Container(
                width: responsive.sp(44),
                height: responsive.sp(44),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: _brand100),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.school_rounded,
                  size: responsive.sp(24),
                  color: _brand600,
                ),
              ),
              SizedBox(width: responsive.sp(12)),
              Flexible(
                child: Text(
                  'Gabaritei Questões',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: responsive.sp(20),
                    fontWeight: FontWeight.w800,
                    color: _slate900,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    final responsive = Responsive.of(context);

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: responsive.isCompact ? 20 : 24,
        vertical: responsive.isCompact ? 10 : 18,
      ),
      physics: const ClampingScrollPhysics(),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: responsive.authMaxWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Hero Section
              _buildHeroSection(),
              SizedBox(height: responsive.isCompact ? 28 : 36),
              // Form Card
              _buildFormCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroSection() {
    final responsive = Responsive.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Badge "Estudo de Alto Nível"
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: responsive.sp(14),
            vertical: responsive.sp(6),
          ),
          decoration: BoxDecoration(
            color: _brand100.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(9999),
            border: Border.all(color: _brand200.withValues(alpha: 0.6)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.star_rounded,
                size: responsive.sp(16),
                color: _brand600,
              ),
              SizedBox(width: responsive.sp(6)),
              Flexible(
                child: Text(
                  'Estudo de Alto Nível',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: responsive.sp(12),
                    fontWeight: FontWeight.w600,
                    color: _brand700,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: responsive.sp(14)),
        // Título principal
        RichText(
          textAlign: TextAlign.left,
          text: TextSpan(
            style: TextStyle(
              fontSize: responsive.sp(28),
              fontWeight: FontWeight.w800,
              color: _slate900,
              height: 1.1,
              letterSpacing: -0.5,
            ),
            children: [
              const TextSpan(text: 'Gabarite suas '),
              TextSpan(
                text: 'Provas',
                style: TextStyle(
                  foreground: Paint()
                    ..shader = LinearGradient(colors: [_brand600, _violet])
                        .createShader(const Rect.fromLTWH(0, 0, 200, 70)),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: responsive.sp(8)),
        // Subtitle
        Text(
          'Acesse milhares de questões comentadas, simulados personalizados e acompanhe sua evolução em tempo real com a inteligência artificial da plataforma.',
          style: TextStyle(
            fontSize: responsive.sp(13),
            color: _slate500,
            height: 1.5,
            letterSpacing: 0.1,
            fontWeight: FontWeight.w400,
          ),
        ),
        SizedBox(height: responsive.sp(14)),
        // Badges de features
        Wrap(
          alignment: WrapAlignment.start,
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildFeatureBadge(Icons.check_rounded, 'Questões Atualizadas'),
            _buildFeatureBadge(Icons.psychology_rounded, 'IA Integrada'),
          ],
        ),
      ],
    );
  }

  Widget _buildFeatureBadge(IconData icon, String label) {
    final responsive = Responsive.of(context);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: responsive.sp(12),
        vertical: responsive.sp(6),
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(color: _slate200.withValues(alpha: 0.8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.015),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: responsive.sp(24),
            height: responsive.sp(24),
            decoration: const BoxDecoration(
              color: _brand600,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_rounded,
              size: responsive.sp(14),
              color: Colors.white,
            ),
          ),
          SizedBox(width: responsive.sp(6)),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: responsive.sp(12),
                fontWeight: FontWeight.w600,
                color: _slate700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard() {
    final responsive = Responsive.of(context);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _slate100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
          BoxShadow(
            color: Colors.blue.shade900.withValues(alpha: 0.02),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      padding: EdgeInsets.all(responsive.sp(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header do card
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: responsive.sp(48),
                height: responsive.sp(48),
                decoration: BoxDecoration(
                  color: _brand50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _brand100),
                ),
                child: Icon(
                  Icons.lock_outline_rounded,
                  size: responsive.sp(24),
                  color: _brand600,
                ),
              ),
              SizedBox(width: responsive.sp(14)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recuperar conta',
                      style: TextStyle(
                        fontSize: responsive.sp(20),
                        fontWeight: FontWeight.w700,
                        color: _slate900,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Informe seu e-mail para receber as instruções de acesso.',
                      style: TextStyle(
                        fontSize: responsive.sp(12),
                        color: _slate500,
                        height: 1.3,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: responsive.sp(24)),
          // Formulário
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Email Field
                _buildInputField(
                  controller: _emailController,
                  label: 'E-mail da conta',
                  hint: 'seu@email.com',
                  icon: Icons.mail_outline_rounded,
                  keyboardType: TextInputType.emailAddress,
                  validator: _validateEmail,
                ),
                SizedBox(height: responsive.sp(24)),
                // Botão ENVIAR LINK
                _buildSendButton(),
                SizedBox(height: responsive.sp(16)),
                // Link para Login
                _buildBackToLoginLink(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    final responsive = Responsive.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: responsive.sp(12),
            fontWeight: FontWeight.w600,
            color: _slate700,
          ),
        ),
        SizedBox(height: responsive.sp(8)),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.015),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            style: TextStyle(
              fontSize: responsive.sp(14),
              color: _slate900,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: _slate400,
                fontSize: responsive.sp(14),
                fontWeight: FontWeight.w400,
              ),
              prefixIcon: Padding(
                padding: EdgeInsets.only(
                  left: responsive.sp(14),
                  right: responsive.sp(10),
                ),
                child: Icon(icon, size: responsive.sp(20), color: _slate400),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: EdgeInsets.symmetric(
                horizontal: responsive.sp(16),
                vertical: responsive.sp(16),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: _slate200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: _slate200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: _brand600, width: 1.5),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.red.shade400),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.red.shade600, width: 1.5),
              ),
              errorStyle: TextStyle(
                color: Colors.red.shade600,
                fontSize: responsive.sp(11),
                fontWeight: FontWeight.w500,
              ),
            ),
            validator: validator,
          ),
        ),
      ],
    );
  }

  Widget _buildSendButton() {
    final responsive = Responsive.of(context);

    return SizedBox(
      height: responsive.sp(54),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleSendResetLink,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2563EB), Color(0xFF6D28D9)],
              stops: [0.0, 1.0],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.indigo.shade500.withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Container(
            alignment: Alignment.center,
            child: _isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          'ENVIAR LINK DE RECUPERAÇÃO',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: responsive.sp(13),
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                      SizedBox(width: responsive.sp(8)),
                      Icon(
                        Icons.send_rounded,
                        size: responsive.sp(20),
                        color: Colors.white,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackToLoginLink() {
    final responsive = Responsive.of(context);

    return Center(
      child: TextButton(
        onPressed: () => context.go('/login'),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(
          'Voltar para o login',
          style: TextStyle(
            fontSize: responsive.sp(12),
            fontWeight: FontWeight.w600,
            color: _brand600,
            letterSpacing: 0.1,
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(double safeBottom) {
    final responsive = Responsive.of(context);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        responsive.isCompact ? 20 : 24,
        10,
        responsive.isCompact ? 20 : 24,
        safeBottom + 10,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: responsive.authMaxWidth),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Link GitHub
              TextButton.icon(
                onPressed: () {
                  // TODO: Abrir URL do GitHub
                },
                icon: Icon(
                  Icons.code_rounded,
                  size: responsive.sp(14),
                  color: _slate800,
                ),
                label: Text(
                  'Código-fonte',
                  style: TextStyle(
                    fontSize: responsive.sp(11),
                    fontWeight: FontWeight.w500,
                    color: _slate700,
                  ),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.8),
                  foregroundColor: _slate700,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9999),
                    side: BorderSide(color: _slate200.withValues(alpha: 0.8)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: TextStyle(
                    fontSize: responsive.sp(11),
                    color: _slate500,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.3,
                  ),
                  children: const [
                    TextSpan(
                      text: 'Gabaritei Questões © 2026 • Software livre.',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

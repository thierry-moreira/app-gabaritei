import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/app_exception.dart';
import '../../core/providers.dart';
import '../../core/ui/responsive.dart';

/// Tela de Cadastro - Gabaritei Questões
///
/// Implementação fiel ao design do Stitch (project: 5146871290008903931)
/// com identidade visual: azul/índigo/violeta, cards suaves, gradientes.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  // Cores da marca (igual ao Tailwind config do Stitch)
  static const Color _brand50 = Color(0xFFEEF6FF);
  static const Color _brand100 = Color(0xFFDBEAFE);
  static const Color _brand200 = Color(0xFFBFDBFE);
  static const Color _brand600 = Color(0xFF2563EB);
  static const Color _brand700 = Color(0xFF1D4ED8);
  static const Color _accent = Color(0xFF6366F1);
  static const Color _violet = Color(0xFF7C3AED);
  static const Color _slate50 = Color(0xFFF8FAFC);
  static const Color _slate100 = Color(0xFFF1F5F9);
  static const Color _slate200 = Color(0xFFE2E8F0);
  static const Color _slate300 = Color(0xFFCBD5E1);
  static const Color _slate400 = Color(0xFF94A3B8);
  static const Color _slate500 = Color(0xFF64748B);
  static const Color _slate600 = Color(0xFF475569);
  static const Color _slate700 = Color(0xFF334155);
  static const Color _slate900 = Color(0xFF0F172A);
  static const Color _slate950 = Color(0xFF020617);

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Informe seu nome';
    }
    if (value.trim().length < 2) {
      return 'Nome deve ter pelo menos 2 caracteres';
    }
    if (value.trim().length > 30) {
      return 'Nome deve ter no máximo 30 caracteres';
    }
    return null;
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

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Informe sua senha';
    }
    if (value.length < 8) {
      return 'A senha precisa ter no mínimo 8 caracteres';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Confirme sua senha';
    }
    if (value != _passwordController.text) {
      return 'As senhas não conferem. Digite a mesma senha nos dois campos.';
    }
    return null;
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final resultado = await ref
          .read(authRepositoryProvider)
          .cadastrar(
            username: _nameController.text,
            email: _emailController.text,
            password: _passwordController.text,
            confirmacao: _confirmPasswordController.text,
          );

      if (!mounted) return;

      if (resultado.pendenteConfirmacao) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Enviamos um link de confirmação para '
              '${resultado.email ?? _emailController.text.trim()}.',
            ),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        context.go('/login');
        return;
      }

      ref.invalidate(perfilAtualProvider);
      context.go('/home');
    } on AppException catch (error) {
      if (mounted) _mostrarErro(error.message);
    } catch (_) {
      if (mounted) {
        _mostrarErro('Não foi possível criar a conta. Tente novamente.');
      }
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
      // Fundo com gradientes radiais (glow-bg do Stitch)
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
                      const Color(0xFFDBEAFE).withValues(alpha: 0.6),
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
                      const Color(0xFFEDE9FE).withValues(alpha: 0.5),
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
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Badge com ícone de formatura
              Container(
                width: responsive.sp(36),
                height: responsive.sp(36),
                decoration: BoxDecoration(
                  color: _brand50,
                  borderRadius: BorderRadius.circular(12),
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
                  size: responsive.sp(18),
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
                    fontSize: responsive.sp(16),
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
              SizedBox(height: responsive.isCompact ? 24 : 32),
              // Register Card
              _buildRegisterCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroSection() {
    final responsive = Responsive.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Badge "Estudo de Alto Nível"
        Center(
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: responsive.sp(16),
              vertical: responsive.sp(6),
            ),
            decoration: BoxDecoration(
              color: _brand50.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(9999),
              border: Border.all(color: _brand200.withValues(alpha: 0.6)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.01),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
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
                      fontSize: responsive.sp(13),
                      fontWeight: FontWeight.w700,
                      color: _brand700,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: responsive.sp(16)),
        // Título principal
        Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: TextStyle(
                  fontSize: responsive.sp(28),
                  fontWeight: FontWeight.w800,
                  color: _slate950,
                  height: 1.15,
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
            SizedBox(height: responsive.sp(10)),
            Text(
              'Acesse milhares de questões comentadas, simulados e acompanhe sua evolução em tempo real com IA.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: responsive.sp(15),
                color: _slate600,
                height: 1.5,
                letterSpacing: 0.2,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        SizedBox(height: responsive.sp(18)),
        // Badges de features
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildFeatureBadge(Icons.verified_rounded, 'Questões Atualizadas'),
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
        horizontal: responsive.sp(14),
        vertical: responsive.sp(6),
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(color: _slate200.withValues(alpha: 0.8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.01),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: responsive.sp(14), color: _brand600),
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
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterCard() {
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
            color: Colors.black.withValues(alpha: 0.04),
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
                width: responsive.sp(36),
                height: responsive.sp(36),
                decoration: BoxDecoration(
                  color: _brand50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _brand100),
                ),
                child: Icon(
                  Icons.person_add_rounded,
                  size: responsive.sp(20),
                  color: _brand600,
                ),
              ),
              SizedBox(width: responsive.sp(12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Crie sua conta',
                      style: TextStyle(
                        fontSize: responsive.sp(18),
                        fontWeight: FontWeight.w800,
                        color: _slate900,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Sua conta, seu progresso em qualquer dispositivo.',
                      style: TextStyle(
                        fontSize: responsive.sp(11),
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
          SizedBox(height: responsive.sp(20)),
          // Formulário
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Name Field
                _buildInputField(
                  controller: _nameController,
                  label: 'Como quer ser chamado?',
                  hint: 'Seu nome ou apelido',
                  icon: Icons.person_outline_rounded,
                  keyboardType: TextInputType.name,
                  validator: _validateName,
                ),
                SizedBox(height: responsive.sp(12)),
                // Email Field
                _buildInputField(
                  controller: _emailController,
                  label: 'E-mail',
                  hint: 'seu@email.com',
                  icon: Icons.mail_outline_rounded,
                  keyboardType: TextInputType.emailAddress,
                  validator: _validateEmail,
                ),
                SizedBox(height: responsive.sp(12)),
                // Password Field
                _buildInputField(
                  controller: _passwordController,
                  label: 'Senha (mínimo 8 caracteres)',
                  hint: 'Crie uma senha forte',
                  icon: Icons.lock_outline_rounded,
                  obscureText: _obscurePassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      size: responsive.sp(20),
                      color: _slate400,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  validator: _validatePassword,
                ),
                SizedBox(height: responsive.sp(12)),
                // Confirm Password Field
                _buildInputField(
                  controller: _confirmPasswordController,
                  label: 'Confirmar senha',
                  hint: 'Digite a senha novamente',
                  icon: Icons.lock_outline_rounded,
                  obscureText: _obscureConfirmPassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirmPassword
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      size: responsive.sp(20),
                      color: _slate400,
                    ),
                    onPressed: () => setState(
                      () => _obscureConfirmPassword = !_obscureConfirmPassword,
                    ),
                  ),
                  validator: _validateConfirmPassword,
                ),
                SizedBox(height: responsive.sp(18)),
                // Botão CRIAR CONTA
                _buildRegisterButton(),
                SizedBox(height: responsive.sp(14)),
                // Link para Login
                _buildLoginLink(),
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
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    final responsive = Responsive.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: responsive.sp(11),
            fontWeight: FontWeight.w600,
            color: _slate700,
          ),
        ),
        SizedBox(height: responsive.sp(6)),
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
            obscureText: obscureText,
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
              suffixIcon: suffixIcon,
              filled: true,
              fillColor: Colors.white,
              contentPadding: EdgeInsets.symmetric(
                horizontal: responsive.sp(16),
                vertical: responsive.sp(12),
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

  Widget _buildRegisterButton() {
    final responsive = Responsive.of(context);

    return SizedBox(
      height: responsive.sp(50),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleRegister,
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
              colors: [Color(0xFF2B62EE), Color(0xFF6848E4), Color(0xFF7D3CEE)],
              stops: [0.0, 0.5, 1.0],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: _accent.withValues(alpha: 0.35),
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
                      Text(
                        'CRIAR CONTA',
                        style: TextStyle(
                          fontSize: responsive.sp(13),
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.6,
                        ),
                      ),
                      SizedBox(width: responsive.sp(8)),
                      Icon(
                        Icons.person_add_rounded,
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

  Widget _buildLoginLink() {
    final responsive = Responsive.of(context);

    return Center(
      child: TextButton(
        onPressed: () => context.go('/login'),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: RichText(
          text: TextSpan(
            style: TextStyle(
              fontSize: responsive.sp(12),
              color: _slate500,
              height: 1.4,
            ),
            children: [
              const TextSpan(text: 'Já tenho conta — '),
              TextSpan(
                text: 'entrar',
                style: TextStyle(
                  fontSize: responsive.sp(12),
                  fontWeight: FontWeight.w600,
                  color: _brand600,
                  letterSpacing: 0.1,
                ),
              ),
            ],
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
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: _slate200.withValues(alpha: 0.6)),
        ),
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
                  color: _slate700,
                ),
                label: Text(
                  'Código-fonte',
                  style: TextStyle(
                    fontSize: responsive.sp(11),
                    fontWeight: FontWeight.w500,
                    color: _slate600,
                  ),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: _slate100.withValues(alpha: 0.8),
                  foregroundColor: _slate600,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9999),
                    side: BorderSide(color: _slate200.withValues(alpha: 0.6)),
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
                  ),
                  children: const [
                    TextSpan(text: 'Gabaritei Questões © 2026 '),
                    TextSpan(
                      text: '•',
                      style: TextStyle(
                        color: _slate300,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    TextSpan(text: ' Software livre'),
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

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/ui/responsive.dart';

/// Barra superior compartilhada pelos dashboards (painel e raio-x).
///
/// Reproduz o cabeçalho do Stitch: cápsula da marca, pílula de ofensiva,
/// alternância de tema e avatar do aluno. Em telas estreitas o selo
/// "QUESTÕES" é ocultado para preservar o layout.
class DashboardTopBar extends StatelessWidget {
  const DashboardTopBar({
    super.key,
    required this.isDark,
    required this.streak,
    this.username = 'thierry_n1',
    this.onToggleTheme,
    this.onLogout,
  });

  final bool isDark;
  final int streak;
  final String username;
  final VoidCallback? onToggleTheme;
  final VoidCallback? onLogout;

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);
    final topInset = MediaQuery.paddingOf(context).top;
    final surface = isDark ? const Color(0xFF0B0E14) : Colors.white;
    final borderColor = isDark
        ? const Color(0xFF1F2737)
        : const Color(0xFFE2E8F0);
    final horizontal = responsive.isCompact ? 16.0 : 24.0;
    final vertical = responsive.isCompact ? 12.0 : 14.0;

    return Container(
      padding: EdgeInsets.fromLTRB(
        horizontal,
        topInset + vertical,
        horizontal,
        vertical,
      ),
      decoration: BoxDecoration(
        color: surface.withValues(alpha: 0.95),
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: responsive.dashboardMaxWidth),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final mostrarSelo = constraints.maxWidth >= 350;

              return Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: _LogoPill(
                            isDark: isDark,
                            mostrarSelo: mostrarSelo,
                          ),
                        ),
                        SizedBox(width: responsive.isCompact ? 8 : 10),
                        _StreakPill(isDark: isDark, streak: streak),
                      ],
                    ),
                  ),
                  SizedBox(width: responsive.isCompact ? 8 : 12),
                  _ThemeButton(isDark: isDark, onPressed: onToggleTheme),
                  SizedBox(width: responsive.isCompact ? 8 : 12),
                  _AccountMenu(
                    isDark: isDark,
                    username: username,
                    onLogout: onLogout,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _LogoPill extends StatelessWidget {
  const _LogoPill({required this.isDark, required this.mostrarSelo});

  final bool isDark;
  final bool mostrarSelo;

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);
    final logoSize = (isDark ? 24.0 : 20.0) * responsive.scale;
    final horizontal = 12.0 * responsive.scale;
    final vertical = 6.0 * responsive.scale;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: horizontal, vertical: vertical),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1422) : Colors.white,
        borderRadius: BorderRadius.circular(isDark ? 14 : 12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: logoSize,
            height: logoSize,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0B0F19) : const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(6),
              border: isDark
                  ? Border.all(color: const Color(0xFF334155))
                  : null,
            ),
            child: Icon(
              Icons.check_rounded,
              size: (isDark ? 14 : 13) * responsive.scale,
              color: Colors.white,
            ),
          ),
          SizedBox(width: 6 * responsive.scale),
          Flexible(
            child: Text(
              'Gabaritei',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: (isDark ? 15 : 14) * responsive.scale,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ),
          if (mostrarSelo) ...[
            SizedBox(width: 6 * responsive.scale),
            Flexible(
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 5 * responsive.scale,
                  vertical: 2 * responsive.scale,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E2538)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'QUESTÕES',
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 10 * responsive.scale,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4,
                      color: isDark
                          ? const Color(0xFFCBD5E1)
                          : const Color(0xFF64748B),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StreakPill extends StatelessWidget {
  const _StreakPill({required this.isDark, required this.streak});

  final bool isDark;
  final int streak;

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);
    final cor = isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309);
    final fundo = isDark
        ? const Color(0xFFF59E0B).withValues(alpha: 0.10)
        : const Color(0xFFFFFBEB).withValues(alpha: 0.9);
    final borda = isDark
        ? const Color(0xFFF59E0B).withValues(alpha: 0.20)
        : const Color(0xFFFDE68A).withValues(alpha: 0.8);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 10 * responsive.scale,
        vertical: 6 * responsive.scale,
      ),
      decoration: BoxDecoration(
        color: fundo,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borda),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.local_fire_department_rounded,
            size: 14 * responsive.scale,
            color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706),
          ),
          SizedBox(width: 4 * responsive.scale),
          Text(
            '$streak Dias',
            maxLines: 1,
            style: TextStyle(
              fontSize: 12 * responsive.scale,
              fontWeight: FontWeight.w600,
              color: cor,
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeButton extends StatelessWidget {
  const _ThemeButton({required this.isDark, this.onPressed});

  final bool isDark;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);
    final size = (isDark ? 32.0 : 36.0) * responsive.scale;
    final button = SizedBox(
      width: size,
      height: size,
      child: Material(
        color: isDark ? Colors.transparent : Colors.white,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: isDark
                  ? null
                  : Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              size: 16 * responsive.scale,
              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
            ),
          ),
        ),
      ),
    );

    return Tooltip(
      message: isDark
          ? 'Alternar para tema claro'
          : 'Alternar para tema escuro',
      child: button,
    );
  }
}

enum _AccountMenuAction { settings, logout }

class _AccountMenu extends StatelessWidget {
  const _AccountMenu({
    required this.isDark,
    required this.username,
    required this.onLogout,
  });

  final bool isDark;
  final String username;
  final VoidCallback? onLogout;

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);
    final textColor = isDark
        ? const Color(0xFFE2E8F0)
        : const Color(0xFF0F172A);
    final secondary = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);
    final border = isDark ? const Color(0xFF263248) : const Color(0xFFE2E8F0);

    return PopupMenuButton<_AccountMenuAction>(
      key: const Key('dashboard-account-menu'),
      tooltip: 'Menu da conta',
      position: PopupMenuPosition.under,
      offset: const Offset(0, 8),
      constraints: BoxConstraints(
        minWidth: responsive.sp(220),
        maxWidth: responsive.sp(280),
      ),
      color: isDark ? const Color(0xFF161B22) : Colors.white,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: border),
      ),
      onSelected: (action) {
        switch (action) {
          case _AccountMenuAction.settings:
            context.go('/conta');
          case _AccountMenuAction.logout:
            onLogout?.call();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<_AccountMenuAction>(
          enabled: false,
          height: responsive.sp(70),
          child: Row(
            children: [
              _Avatar(isDark: isDark, username: username, size: 38),
              SizedBox(width: responsive.sp(10)),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      username,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textColor,
                        fontSize: responsive.sp(12),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: responsive.sp(4)),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: responsive.sp(7),
                        vertical: responsive.sp(2),
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'ALUNO',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: responsive.sp(8),
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(height: 1),
        PopupMenuItem<_AccountMenuAction>(
          key: const Key('dashboard-account-settings'),
          value: _AccountMenuAction.settings,
          height: responsive.sp(52),
          child: Row(
            children: [
              Icon(
                Icons.manage_accounts_outlined,
                size: responsive.sp(19),
                color: secondary,
              ),
              SizedBox(width: responsive.sp(11)),
              Expanded(
                child: Text(
                  'Configurações da Conta',
                  style: TextStyle(
                    color: textColor,
                    fontSize: responsive.sp(11.5),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(height: 1),
        PopupMenuItem<_AccountMenuAction>(
          key: const Key('dashboard-account-logout'),
          value: _AccountMenuAction.logout,
          enabled: onLogout != null,
          height: responsive.sp(50),
          child: Row(
            children: [
              Icon(
                Icons.logout_rounded,
                size: responsive.sp(18),
                color: const Color(0xFFEF4444),
              ),
              SizedBox(width: responsive.sp(11)),
              Text(
                'Sair da Conta',
                style: TextStyle(
                  color: const Color(0xFFEF4444),
                  fontSize: responsive.sp(11.5),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Avatar(isDark: isDark, username: username),
          SizedBox(width: responsive.sp(3)),
          Icon(
            Icons.expand_more_rounded,
            color: secondary,
            size: responsive.sp(16),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.isDark, required this.username, this.size = 36});

  final bool isDark;
  final String username;
  final double size;

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);
    final avatarSize = size * responsive.scale;
    final inicial = username.trim().isEmpty
        ? '?'
        : username.trim().characters.first.toUpperCase();

    final avatar = Container(
      width: avatarSize,
      height: avatarSize,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2563EB) : const Color(0xFF0F172A),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        inicial,
        style: TextStyle(
          fontSize: 14 * responsive.scale,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          height: 1,
        ),
      ),
    );

    return avatar;
  }
}

/// Navegação inferior compartilhada pelos dashboards.
///
/// Mantém os oito módulos do app desktop, com rolagem horizontal quando
/// o espaço não é suficiente para todos os itens.
class DashboardBottomNav extends StatelessWidget {
  const DashboardBottomNav({
    super.key,
    required this.isDark,
    required this.selectedIndex,
    required this.onSelected,
  });

  final bool isDark;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const _items = <({IconData icon, String label})>[
    (icon: Icons.grid_view_rounded, label: 'Painel'),
    (icon: Icons.edit_note_rounded, label: 'Questões'),
    (icon: Icons.book_outlined, label: 'Cadernos'),
    (icon: Icons.layers_outlined, label: 'Flashcards'),
    (icon: Icons.description_outlined, label: 'Resumos'),
    (icon: Icons.fact_check_outlined, label: 'Simulados'),
    (icon: Icons.adjust_rounded, label: 'Edital em Questão'),
    (icon: Icons.settings_outlined, label: 'Ajustes'),
  ];

  static String labelFor(int index) => _items[index].label;

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final surface = isDark ? const Color(0xFF0E1219) : Colors.white;
    final borderColor = isDark
        ? const Color(0xFF1A2230)
        : const Color(0xFFE2E8F0);
    final horizontal = responsive.isCompact ? 4.0 : 8.0;
    final vertical = responsive.isCompact ? 6.0 : 8.0;

    return Container(
      padding: EdgeInsets.fromLTRB(
        horizontal,
        vertical,
        horizontal,
        bottomInset + vertical,
      ),
      decoration: BoxDecoration(
        color: surface.withValues(alpha: 0.95),
        border: Border(top: BorderSide(color: borderColor)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: responsive.dashboardMaxWidth),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      for (var index = 0; index < _items.length; index++)
                        _NavItem(
                          isDark: isDark,
                          icon: _items[index].icon,
                          label: _items[index].label,
                          active: index == selectedIndex,
                          onTap: () => onSelected(index),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.isDark,
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final bool isDark;
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);
    final activeColor = isDark
        ? const Color(0xFF60A5FA)
        : const Color(0xFF2F4F75);
    final inactiveColor = const Color(0xFF94A3B8);
    final color = active ? activeColor : inactiveColor;
    final boxSize = (isDark ? 28.0 : 32.0) * responsive.scale;

    return Semantics(
      button: true,
      selected: active,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: 44 * responsive.scale),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 4 * responsive.scale,
              vertical: 4 * responsive.scale,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: boxSize,
                  height: boxSize,
                  decoration: BoxDecoration(
                    color: active
                        ? (isDark
                              ? const Color(0xFF3B82F6).withValues(alpha: 0.15)
                              : const Color(0xFFF1F5F9))
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 16 * responsive.scale, color: color),
                ),
                SizedBox(height: 2 * responsive.scale),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 62 * responsive.scale),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: (isDark ? 8 : 9) * responsive.scale,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                      letterSpacing: -0.1,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

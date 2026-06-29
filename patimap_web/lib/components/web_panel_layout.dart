import 'package:flutter/material.dart';
import '../theme/app_palette.dart';
import '../utils/panel_responsive.dart';
import 'panel_footer_links.dart';
import 'scroll_reveal.dart';

enum WebMenuItem { dashboard, reports, volunteers, map, settings }
const String _webBrandLogoAsset = 'assets/images/patimaplogo2.png';

class WebPanelLayout extends StatelessWidget {
  const WebPanelLayout({
    super.key,
    required this.revealScope,
    required this.currentItem,
    required this.title,
    required this.child,
    required this.onMenuSelected,
    this.headerTrailing,
    this.compactFooter = false,
  });

  /// [ScrollReveal] / [VisibilityDetector] anahtarları için benzersiz önek.
  final String revealScope;
  /// Dashboard gibi sayfalarda footer üst boşluğunu azaltır.
  final bool compactFooter;
  final WebMenuItem currentItem;
  final String title;
  final Widget child;
  final ValueChanged<WebMenuItem> onMenuSelected;
  final Widget? headerTrailing;

  @override
  Widget build(BuildContext context) {
    const bg = AppPalette.pageBackground;
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final wide = PanelResponsive.useSidebar(width);
            final pagePad = PanelResponsive.pagePadding(width);
            return Row(
              children: [
                if (wide)
                  Container(
                    width: 252,
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                    decoration: const BoxDecoration(
                      color: AppPalette.pageBackground,
                      border: Border(
                        right: BorderSide(color: AppPalette.border),
                      ),
                    ),
                    child: _SidebarMenu(
                      currentItem: currentItem,
                      onMenuSelected: onMenuSelected,
                    ),
                  ),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        Padding(
                          padding: pagePad,
                          child: Column(
                            children: [
                              ScrollReveal(
                                detectKey: ValueKey<String>(
                                  '${revealScope}_panel_header',
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    _TopHeader(
                                      title: title,
                                      trailing: headerTrailing,
                                      viewportWidth: width,
                                    ),
                                    if (!wide) ...[
                                      SizedBox(
                                        height: PanelResponsive.isMobile(width)
                                            ? 8
                                            : 12,
                                      ),
                                      _CompactMenuBar(
                                        currentItem: currentItem,
                                        onMenuSelected: onMenuSelected,
                                        viewportWidth: width,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              SizedBox(
                                height: PanelResponsive.isMobile(width) ? 14 : 20,
                              ),
                              ScrollReveal(
                                detectKey: ValueKey<String>(
                                  '${revealScope}_panel_main',
                                ),
                                child: ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(maxWidth: 1200),
                                  child: child,
                                ),
                              ),
                              SizedBox(
                                height: PanelResponsive.isMobile(width) ? 18 : 28,
                              ),
                            ],
                          ),
                        ),
                        ScrollReveal(
                          detectKey: ValueKey<String>(
                            '${revealScope}_panel_footer',
                          ),
                          child: _PanelFooter(
                            compact: compactFooter,
                            onMenuSelected: onMenuSelected,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TopHeader extends StatelessWidget {
  const _TopHeader({
    required this.title,
    required this.viewportWidth,
    this.trailing,
  });

  final String title;
  final double viewportWidth;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    const primary = AppPalette.primaryBlue;
    final narrow = PanelResponsive.isNarrow(viewportWidth);
    final mobile = PanelResponsive.isMobile(viewportWidth);
    final logoSize = narrow ? 22.0 : (mobile ? 26.0 : 30.0);
    final titleSize = narrow ? 15.0 : (mobile ? 17.0 : 21.0);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: narrow ? 10 : (mobile ? 12 : 18),
        vertical: narrow ? 10 : 14,
      ),
      decoration: BoxDecoration(
        color: AppPalette.cardBackground,
        borderRadius: BorderRadius.circular(AppPalette.radiusLg),
        border: Border.all(color: AppPalette.border),
        boxShadow: [
          BoxShadow(
            color: AppPalette.navy.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(narrow ? 5 : 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: primary.withValues(alpha: 0.18)),
              boxShadow: [
                BoxShadow(
                  color: primary.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Image.asset(
              _webBrandLogoAsset,
              width: logoSize,
              height: logoSize,
              fit: BoxFit.cover,
            ),
          ),
          SizedBox(width: narrow ? 6 : 10),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: TextStyle(
                color: AppPalette.navy,
                fontSize: titleSize,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
          ),
          SizedBox(width: narrow ? 4 : 8),
          Flexible(
            fit: FlexFit.loose,
            child: trailing ??
                CircleAvatar(
                  radius: narrow ? 15 : 18,
                  backgroundColor: primary.withValues(alpha: 0.12),
                  child: Icon(
                    Icons.person_outline_rounded,
                    color: primary,
                    size: narrow ? 18 : 20,
                  ),
                ),
          ),
        ],
      ),
    );
  }
}

class _SidebarMenu extends StatelessWidget {
  const _SidebarMenu({required this.currentItem, required this.onMenuSelected});

  final WebMenuItem currentItem;
  final ValueChanged<WebMenuItem> onMenuSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: AppPalette.cardBackground,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppPalette.border),
            boxShadow: [
              BoxShadow(
                color: AppPalette.navy.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: const Text(
            'PatiMap Panel',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppPalette.navy,
            ),
          ),
        ),
        const SizedBox(height: 16),
        _SidebarItem(
          icon: Icons.dashboard_outlined,
          label: 'Dashboard',
          active: currentItem == WebMenuItem.dashboard,
          onTap: () => onMenuSelected(WebMenuItem.dashboard),
        ),
        _SidebarItem(
          icon: Icons.report_gmailerrorred_outlined,
          label: 'Ihbarlar',
          active: currentItem == WebMenuItem.reports,
          onTap: () => onMenuSelected(WebMenuItem.reports),
        ),
        _SidebarItem(
          icon: Icons.groups_outlined,
          label: 'Yakin Veterinerler',
          active: currentItem == WebMenuItem.volunteers,
          onTap: () => onMenuSelected(WebMenuItem.volunteers),
        ),
        _SidebarItem(
          icon: Icons.map_outlined,
          label: 'Harita',
          active: currentItem == WebMenuItem.map,
          onTap: () => onMenuSelected(WebMenuItem.map),
        ),
        _SidebarItem(
          icon: Icons.settings_outlined,
          label: 'Ayarlar',
          active: currentItem == WebMenuItem.settings,
          onTap: () => onMenuSelected(WebMenuItem.settings),
        ),
        const Spacer(),
        Text(
          'v1.0',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const primary = AppPalette.primaryBlue;
    final iconBg = active
        ? primary.withValues(alpha: 0.13)
        : AppPalette.pageBackground;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active ? primary.withValues(alpha: 0.28) : Colors.transparent,
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: primary.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(
                icon,
                size: 17,
                color: active ? primary : Colors.grey.shade700,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                color: active ? AppPalette.navy : Colors.grey.shade800,
                fontWeight: active ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactMenuBar extends StatelessWidget {
  const _CompactMenuBar({
    required this.currentItem,
    required this.onMenuSelected,
    required this.viewportWidth,
  });

  final WebMenuItem currentItem;
  final ValueChanged<WebMenuItem> onMenuSelected;
  final double viewportWidth;

  @override
  Widget build(BuildContext context) {
    final mobile = PanelResponsive.isMobile(viewportWidth);
    final chips = WebMenuItem.values
        .map(
          (item) => ChoiceChip(
            label: Text(
              _label(item),
              style: TextStyle(
                fontSize: mobile ? 12 : 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            visualDensity: mobile ? VisualDensity.compact : VisualDensity.standard,
            padding: mobile
                ? const EdgeInsets.symmetric(horizontal: 4, vertical: 0)
                : null,
            selected: currentItem == item,
            onSelected: (_) => onMenuSelected(item),
          ),
        )
        .toList();

    if (mobile) {
      return GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
        childAspectRatio: 2.85,
        children: chips,
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < chips.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            chips[i],
          ],
        ],
      ),
    );
  }

  String _label(WebMenuItem item) {
    switch (item) {
      case WebMenuItem.dashboard:
        return 'Dashboard';
      case WebMenuItem.reports:
        return 'Ihbarlar';
      case WebMenuItem.volunteers:
        return 'Yakin Veterinerler';
      case WebMenuItem.map:
        return 'Harita';
      case WebMenuItem.settings:
        return 'Ayarlar';
    }
  }
}

class _PanelFooter extends StatelessWidget {
  const _PanelFooter({
    required this.onMenuSelected,
    this.compact = false,
  });

  final ValueChanged<WebMenuItem> onMenuSelected;
  final bool compact;

  static const List<(String, List<String>)> _columns = [
    (
      'PatiMap',
      ['Hakkımızda', 'Nasıl Çalışır?', 'İletişim', 'Sık Sorulan Sorular'],
    ),
    (
      'Yardım',
      ['İhbar Oluştur', 'Yakın Veterinerler', 'Acil Durum Rehberi', 'Destek Merkezi'],
    ),
    (
      'Sistem',
      ['Harita', 'Güncellemeler', 'Bildirimler', 'Güvenlik'],
    ),
    (
      'Yasal',
      ['Gizlilik Politikası', 'Kullanım Şartları', 'KVKK', 'Çerez Politikası'],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final compact = width < 980;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFF6F8FB),
            Color(0xFFF2F4F8),
          ],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          28,
          compact ? 20 : 38,
          28,
          compact ? 12 : 16,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1320),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Column(
                  children: [
                    Container(
                      width: compact ? 44 : 54,
                      height: compact ? 44 : 54,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      padding: EdgeInsets.all(compact ? 6 : 8),
                      child: Image.asset(
                        _webBrandLogoAsset,
                        fit: BoxFit.contain,
                      ),
                    ),
                    SizedBox(height: compact ? 6 : 10),
                    Text(
                      'PatiMap',
                      style: TextStyle(
                        color: AppPalette.navy,
                        fontWeight: FontWeight.w800,
                        fontSize: compact ? 22 : 28,
                        letterSpacing: -0.3,
                      ),
                    ),
                    SizedBox(height: compact ? 4 : 6),
                    Text(
                      'Sokaktaki dostlarımız için hızlı ihbar ve destek platformu.',
                      style: TextStyle(
                        color: compact
                            ? const Color(0xFF5C6E86)
                            : Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                        fontSize: compact ? 13.2 : 14.4,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
                SizedBox(height: compact ? 16 : 24),
                Container(
                  height: 1,
                  color: Colors.grey.shade200,
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: compact ? 20 : 44,
                  runSpacing: compact ? 20 : 28,
                  alignment: WrapAlignment.center,
                  children: _columns
                      .map(
                        (section) => _FooterColumn(
                          title: section.$1,
                          items: section.$2,
                          onMenuSelected: onMenuSelected,
                        ),
                      )
                      .toList(),
                ),
                SizedBox(height: compact ? 12 : 18),
                Container(
                  height: 1,
                  color: Colors.grey.shade200,
                ),
                SizedBox(height: compact ? 8 : 12),
                Text(
                  '© 2026 PatiMap — Sokaktaki dostlarımız için geliştirildi.',
                  style: TextStyle(
                    color: compact
                        ? const Color(0xFF5C6E86)
                        : Colors.grey.shade700,
                    fontSize: compact ? 12.2 : 12.8,
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FooterColumn extends StatelessWidget {
  const _FooterColumn({
    required this.title,
    required this.items,
    required this.onMenuSelected,
  });

  final String title;
  final List<String> items;
  final ValueChanged<WebMenuItem> onMenuSelected;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 180, maxWidth: 220),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w700,
              fontSize: 12.0,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: _FooterLinkLabel(
                label: item,
                onTap: () => handlePanelFooterLink(
                  context,
                  item,
                  onMenuSelected: onMenuSelected,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FooterLinkLabel extends StatefulWidget {
  const _FooterLinkLabel({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  State<_FooterLinkLabel> createState() => _FooterLinkLabelState();
}

class _FooterLinkLabelState extends State<_FooterLinkLabel> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 1),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: _hovered
                    ? AppPalette.primaryBlue.withValues(alpha: 0.5)
                    : Colors.transparent,
              ),
            ),
          ),
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            style: TextStyle(
            color: _hovered ? AppPalette.primaryBlue : Colors.grey.shade800,
            fontWeight: FontWeight.w500,
            fontSize: 13.8,
              height: 1.35,
            ),
            child: Text(widget.label),
          ),
        ),
      ),
    );
  }
}


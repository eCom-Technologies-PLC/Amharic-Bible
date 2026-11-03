import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/strings.dart';
import '../theme/app_colors.dart';
import '../tokens/tokens.dart';

/// The standard screen: app bar → body → optional bottom action area.
///
/// SafeArea and keyboard insets are handled here, not per screen. Bodies get
/// no padding by default (lists pad themselves via [AppListView] /
/// [AppSpacing.screen]); pass [padded] for plain content.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    this.title,
    this.titleWidget,
    this.actions,
    this.bottom,
    this.leading,
    required this.body,
    this.bottomBar,
    this.padded = false,
    this.showAppBar = true,
    this.reading = false,
    this.pageTitle,
    this.appBarHidden,
  });

  final String? title;
  final Widget? titleWidget;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final Widget? leading;
  final Widget body;

  /// Bottom action area (e.g. a [BottomActionBar] or a selection bar).
  final Widget? bottomBar;
  final bool padded;
  final bool showAppBar;

  /// The reading page: the screen and its app bar use the theme's paper
  /// color ([AppColors.paper]) instead of the page color.
  final bool reading;

  /// Names the browser tab on the web ("ዮሐንስ 3 · መጽሐፍ ቅዱስ"); defaults to
  /// [title]. Screens with a [titleWidget] pass it themselves.
  final String? pageTitle;

  /// For screens that can hide their app bar (immersive reading): when true
  /// the bar slides away, keeping the status-bar strip; null for a fixed bar.
  final bool? appBarHidden;

  @override
  Widget build(BuildContext context) {
    final scaffold = _scaffold(context);
    return kIsWeb ? _BrowserTitle(title: pageTitle ?? title, child: scaffold) : scaffold;
  }

  Widget _scaffold(BuildContext context) {
    final paper = reading ? context.appColors.paper : null;
    final appBar = AppBar(
      backgroundColor: paper,
      leading: leading,
      title: titleWidget ?? (title != null ? Text(title!, maxLines: 1, overflow: TextOverflow.ellipsis) : null),
      actions: [
        ...?actions,
        const SizedBox(width: AppSpacing.xs),
      ],
      bottom: bottom,
    );
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: paper,
      appBar: !showAppBar
          ? null
          : appBarHidden == null
          ? appBar
          : _CollapsibleAppBar(hidden: appBarHidden!, child: appBar),
      body: SafeArea(
        top: !showAppBar,
        bottom: bottomBar == null,
        child: padded ? Padding(padding: const EdgeInsets.all(AppSpacing.screen), child: body) : body,
      ),
      bottomNavigationBar: bottomBar,
    );
  }
}

/// An app bar that slides up out of view when [hidden], leaving the status-bar
/// strip; the body below follows it smoothly instead of jumping.
class _CollapsibleAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _CollapsibleAppBar({required this.hidden, required this.child});

  final bool hidden;
  final PreferredSizeWidget child;

  @override
  Size get preferredSize => child.preferredSize;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final full = top + child.preferredSize.height;
    return TweenAnimationBuilder<double>(
      tween: Tween(end: hidden ? 0 : 1),
      duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : AppMotion.medium,
      curve: AppMotion.curve,
      builder: (context, shown, bar) => ClipRect(
        child: Align(
          alignment: Alignment.topCenter,
          heightFactor: full == 0 ? 1 : (top + (full - top) * shown) / full,
          child: bar,
        ),
      ),
      child: child,
    );
  }
}

/// Sets the browser tab title while this screen is the one being shown.
///
/// Every built screen has one of these (tabs kept alive in the shell, screens
/// under a pushed route), so each compares its own location with the
/// router's current one and only the visible screen names the tab. It runs
/// again on every navigation, so going back restores the right title.
class _BrowserTitle extends StatefulWidget {
  const _BrowserTitle({required this.title, required this.child});

  final String? title;
  final Widget child;

  @override
  State<_BrowserTitle> createState() => _BrowserTitleState();
}

class _BrowserTitleState extends State<_BrowserTitle> {
  GoRouter? _router;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final router = GoRouter.maybeOf(context);
    if (router != _router) {
      _router?.routerDelegate.removeListener(_apply);
      _router = router;
      router?.routerDelegate.addListener(_apply);
    }
    _apply();
  }

  @override
  void didUpdateWidget(_BrowserTitle old) {
    super.didUpdateWidget(old);
    if (old.title != widget.title) _apply();
  }

  @override
  void dispose() {
    _router?.routerDelegate.removeListener(_apply);
    super.dispose();
  }

  void _apply() {
    if (!mounted) return;
    final router = _router;
    if (router != null) {
      Uri? mine;
      try {
        mine = GoRouterState.of(context).uri;
      } on GoError {
        // No route state: the router's error page, which is the current page.
      }
      if (mine != null && mine != router.routerDelegate.currentConfiguration.uri) return;
    }
    final app = S.of(context).appName;
    final t = widget.title;
    SystemChrome.setApplicationSwitcherDescription(
      ApplicationSwitcherDescription(
        label: t == null || t.isEmpty || t == app ? app : '$t · $app',
        primaryColor: Theme.of(context).colorScheme.primary.toARGB32(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Scrollable screen content with the standard padding and vertical rhythm.
///
/// On wide windows the content is centered at [AppDimens.contentMaxWidth]
/// while the list itself stays full width, so it scrolls from anywhere in the
/// window and its scrollbar sits at the edge.
class AppListView extends StatelessWidget {
  const AppListView({super.key, required this.children, this.padding, this.controller});

  final List<Widget> children;
  final EdgeInsetsGeometry? padding;
  final ScrollController? controller;

  /// Standard padding: top/bottom [AppSpacing.sm], sides 0 (tiles and
  /// [Gutter] add the screen padding themselves, so tiles can be full-width).
  static const defaultPadding = EdgeInsets.symmetric(vertical: AppSpacing.sm);

  /// [padding] plus the side margins that center content of at most
  /// [AppDimens.contentMaxWidth] in a list [width] wide. For screens that
  /// build their own `ListView` (e.g. `ListView.builder`).
  static EdgeInsets centered(BuildContext context, double width, [EdgeInsetsGeometry padding = defaultPadding]) {
    final side = width > AppDimens.contentMaxWidth ? (width - AppDimens.contentMaxWidth) / 2 : 0.0;
    return padding.resolve(Directionality.of(context)) + EdgeInsets.symmetric(horizontal: side);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => ListView(
      controller: controller,
      padding: centered(context, box.maxWidth, padding ?? defaultPadding),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: children,
    ),
  );
}

/// Centers a screen body that isn't an [AppListView] (tab views, screens with
/// their own lists) at [AppDimens.contentMaxWidth] on wide windows.
class ContentWidth extends StatelessWidget {
  const ContentWidth({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: AppDimens.contentMaxWidth),
      child: child,
    ),
  );
}

/// Insets a child by the standard horizontal screen padding.
class Gutter extends StatelessWidget {
  const Gutter({super.key, required this.child, this.vertical = 0});

  final Widget child;
  final double vertical;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(horizontal: AppSpacing.screen, vertical: vertical),
    child: child,
  );
}

/// Vertical space from the spacing scale.
class Gap extends StatelessWidget {
  const Gap(this.size, {super.key});

  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(width: size, height: size);
}

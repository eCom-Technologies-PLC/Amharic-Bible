import 'package:flutter/material.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: showAppBar
          ? AppBar(
              leading: leading,
              title: titleWidget ?? (title != null ? Text(title!, maxLines: 1, overflow: TextOverflow.ellipsis) : null),
              actions: [
                ...?actions,
                const SizedBox(width: AppSpacing.xs),
              ],
              bottom: bottom,
            )
          : null,
      body: SafeArea(
        top: !showAppBar,
        bottom: bottomBar == null,
        child: padded ? Padding(padding: const EdgeInsets.all(AppSpacing.screen), child: body) : body,
      ),
      bottomNavigationBar: bottomBar,
    );
  }
}

/// Scrollable screen content with the standard padding and vertical rhythm.
class AppListView extends StatelessWidget {
  const AppListView({super.key, required this.children, this.padding, this.controller});

  final List<Widget> children;
  final EdgeInsetsGeometry? padding;
  final ScrollController? controller;

  /// Standard padding: top/bottom [AppSpacing.sm], sides 0 (tiles and
  /// [Gutter] add the screen padding themselves, so tiles can be full-width).
  static const defaultPadding = EdgeInsets.symmetric(vertical: AppSpacing.sm);

  @override
  Widget build(BuildContext context) => ListView(
    controller: controller,
    padding: padding ?? defaultPadding,
    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
    children: children,
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

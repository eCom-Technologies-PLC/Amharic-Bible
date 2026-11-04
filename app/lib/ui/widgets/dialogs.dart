import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../tokens/tokens.dart';
import 'app_button.dart';

/// Dialogs confirm destructive or blocking actions; everything else (options,
/// pickers, details) uses [showAppBottomSheet].
Future<T?> showAppDialog<T>({
  required BuildContext context,
  required String title,
  Widget? content,
  required List<Widget> actions,
}) => showDialog<T>(
  context: context,
  builder: (context) => AlertDialog(
    title: Text(title),
    content: content,
    actions: actions,
    actionsAlignment: MainAxisAlignment.end,
    actionsOverflowButtonSpacing: AppSpacing.sm,
  ),
);

/// Confirm/cancel dialog; resolves to true when confirmed.
Future<bool> showConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  required String confirmLabel,
  required String cancelLabel,
  bool destructive = false,
}) async {
  // The dialog sits on the root navigator (showDialog's default); popping the
  // caller's navigator instead would close the screen behind it when the
  // caller is inside the bottom-bar shell.
  void close(bool value) => Navigator.of(context, rootNavigator: true).pop(value);
  final ok = await showAppDialog<bool>(
    context: context,
    title: title,
    content: Text(message),
    actions: [
      AppButton.ghost(label: cancelLabel, onPressed: () => close(false)),
      destructive
          ? AppButton.destructive(label: confirmLabel, onPressed: () => close(true))
          : AppButton(label: confirmLabel, onPressed: () => close(true)),
    ],
  );
  return ok ?? false;
}

/// A sheet with the standard padding, title and safe area: options, details
/// and short forms.
///
/// It rises from the bottom on phones. On wide windows (desktop browsers,
/// tablets on their side) it opens as a popover beside the control that
/// opened it: [anchor] when given, otherwise the spot just pressed. It opens
/// centered when nothing was pressed (a keyboard shortcut), or when
/// [centered] (a moment rather than a choice, such as finishing a plan).
/// Close it with the builder's context (`Navigator.of(sheet).pop()`).
Future<T?> showAppBottomSheet<T>({
  required BuildContext context,
  String? title,
  required WidgetBuilder builder,
  bool scrollable = true,
  BuildContext? anchor,
  bool centered = false,
}) {
  final physics = scrollable ? null : const NeverScrollableScrollPhysics();
  if (!context.isWideWindow) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 0, AppSpacing.screen, AppSpacing.xl),
            physics: physics,
            child: _SheetBody(title: title, builder: builder),
          ),
        ),
      ),
    );
  }
  return _showBeside<T>(
    context: context,
    title: title,
    anchor: centered ? null : _anchorOf(context, anchor),
    builder: (context) => SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      physics: physics,
      child: _SheetBody(title: title, builder: builder),
    ),
  );
}

/// Brief confirmation message at the bottom of the screen. With [actionLabel]
/// and [onAction] it offers one action, typically "Undo" after a removal, and
/// stays up longer so there is time to use it.
void showAppSnack(BuildContext context, String message, {String? actionLabel, VoidCallback? onAction}) {
  final action = actionLabel != null && onAction != null
      ? SnackBarAction(label: actionLabel, onPressed: onAction)
      : null;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        action: action,
        duration: action != null ? AppMotion.undoSnackBar : snackDuration(message),
      ),
    );
}

/// How long a snack bar stays up: long enough to read [message], from
/// [AppMotion.snackBar] for a few words up to [AppMotion.snackBarLongest]. A
/// message telling the reader what to do ("Install a text-to-speech voice in
/// your phone's settings") was gone in 2 seconds, before it could be read.
Duration snackDuration(String message) {
  final reading = Duration(milliseconds: message.length * 1000 ~/ AppMotion.snackBarReadingRate);
  return reading < AppMotion.snackBar
      ? AppMotion.snackBar
      : (reading > AppMotion.snackBarLongest ? AppMotion.snackBarLongest : reading);
}

/// One choice in [showOptionPicker].
class PickerOption<T> {
  const PickerOption(this.value, this.label, {this.subtitle});
  final T value;
  final String label;
  final String? subtitle;
}

/// Options with the current one checked, in a sheet (a popover on wide
/// windows, as [showAppBottomSheet]); resolves to the chosen value (null when
/// dismissed). Replaces dropdowns and segmented controls inside list rows,
/// which do not fit narrow screens.
Future<T?> showOptionPicker<T>({
  required BuildContext context,
  required String title,
  required List<PickerOption<T>> options,
  required T? selected,
  BuildContext? anchor,
}) {
  if (!context.isWideWindow) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => SafeArea(
        child: _OptionList<T>(title: title, options: options, selected: selected, inSheet: true),
      ),
    );
  }
  return _showBeside<T>(
    context: context,
    title: title,
    anchor: _anchorOf(context, anchor),
    builder: (context) => _OptionList<T>(title: title, options: options, selected: selected, inSheet: false),
  );
}

/// A popover under (or above) [anchor], [width] wide at most, for content made
/// for wide windows (`context.isWideWindow`), such as the desktop book picker;
/// on phones the caller shows a screen or [showAppBottomSheet] instead. Unlike
/// a sheet, [builder] lays out the whole popover, padding and scrolling
/// included, within the height there is room for. [title] names it for screen
/// readers. It closes with Esc or a click outside, or `Navigator.of(popover)`.
Future<T?> showAppPopover<T>({
  required BuildContext context,
  required BuildContext anchor,
  required String title,
  double width = AppDimens.popoverWidth,
  required WidgetBuilder builder,
}) {
  final rect = _anchorOf(context, anchor);
  return _showBeside<T>(context: context, title: title, anchor: rect, width: width, builder: builder);
}

/// Remembers where the pointer last went down, so that a sheet the press
/// opens appears beside it on a wide window ([showAppBottomSheet]). Wraps the
/// app.
class LastPress extends StatefulWidget {
  const LastPress({super.key, required this.child});

  final Widget child;

  /// The spot pressed just now (within [AppMotion.pressToSheet]), in global
  /// coordinates; null when nothing was.
  static Offset? recentOf(BuildContext context) => context.findAncestorStateOfType<_LastPressState>()?._recent;

  @override
  State<LastPress> createState() => _LastPressState();
}

class _LastPressState extends State<LastPress> {
  Offset? _spot;
  DateTime? _at;

  Offset? get _recent {
    final at = _at;
    return at != null && DateTime.now().difference(at) <= AppMotion.pressToSheet ? _spot : null;
  }

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  /// A key pressed since (a shortcut, typing) means what opens next isn't the
  /// press's doing.
  bool _onKey(KeyEvent event) {
    if (event is KeyDownEvent) _at = null;
    return false;
  }

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.translucent,
    onPointerDown: (event) {
      _spot = event.position;
      _at = DateTime.now();
    },
    child: widget.child,
  );
}

/// What a popover points to, in global coordinates: [anchor]'s box, or the
/// spot just pressed; null to center it.
Rect? _anchorOf(BuildContext context, BuildContext? anchor) {
  final box = anchor != null && anchor.mounted ? anchor.findRenderObject() : null;
  if (box is RenderBox && box.hasSize) return box.localToGlobal(Offset.zero) & box.size;
  final spot = LastPress.recentOf(context);
  return spot == null ? null : Rect.fromLTWH(spot.dx, spot.dy, 0, 0);
}

/// A sheet's content on a wide window: a popover pointing at [anchor], or a
/// centered panel when there is none. Both sit on the root navigator, above
/// the navigation rail or sidebar.
Future<T?> _showBeside<T>({
  required BuildContext context,
  required String? title,
  required Rect? anchor,
  required WidgetBuilder builder,
  double width = AppDimens.popoverWidth,
}) {
  if (anchor == null) {
    return showDialog<T>(
      context: context,
      builder: (context) => Dialog(
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: math.max(width, AppDimens.centeredSheetMaxWidth)),
          child: _Named(title: title, child: builder(context)),
        ),
      ),
    );
  }
  final navigator = Navigator.of(context, rootNavigator: true);
  return navigator.push(
    _PopoverRoute<T>(
      anchor: anchor,
      title: title,
      width: width,
      builder: builder,
      themes: InheritedTheme.capture(from: context, to: navigator.context),
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    ),
  );
}

class _SheetBody extends StatelessWidget {
  const _SheetBody({required this.title, required this.builder});

  final String? title;
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (title != null)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Text(title!, style: context.text.titleMedium),
        ),
      builder(context),
    ],
  );
}

class _OptionList<T> extends StatelessWidget {
  const _OptionList({required this.title, required this.options, required this.selected, required this.inSheet});

  final String title;
  final List<PickerOption<T>> options;
  final T? selected;

  /// In a bottom sheet, under its drag handle; otherwise in a popover or
  /// panel, which needs room above the title.
  final bool inSheet;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: EdgeInsets.only(top: inSheet ? 0 : AppSpacing.lg, bottom: inSheet ? AppSpacing.lg : AppSpacing.sm),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 0, AppSpacing.screen, AppSpacing.sm),
          child: Text(title, style: context.text.titleMedium),
        ),
        for (final o in options)
          ListTile(
            title: Text(o.label),
            subtitle: o.subtitle != null ? Text(o.subtitle!) : null,
            trailing: o.value == selected ? Icon(Icons.check, color: context.colors.primary) : null,
            selected: o.value == selected,
            onTap: () => Navigator.pop(context, o.value),
          ),
      ],
    ),
  );
}

/// Names a popover or panel for screen readers, as a dialog's title does.
class _Named extends StatelessWidget {
  const _Named({required this.title, required this.child});

  final String? title;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Semantics(scopesRoute: true, namesRoute: title != null, explicitChildNodes: true, label: title, child: child);
}

/// A sheet beside its control on a wide window, like a menu: it closes when
/// something else is clicked or with Esc.
class _PopoverRoute<T> extends PopupRoute<T> {
  _PopoverRoute({
    required this.anchor,
    required this.title,
    required this.width,
    required this.builder,
    required this.themes,
    required this.barrierLabel,
  });

  /// The control (or spot) it points to, in global coordinates.
  final Rect anchor;
  final String? title;
  final double width;
  final WidgetBuilder builder;
  final CapturedThemes themes;

  @override
  final String barrierLabel;

  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => true;

  @override
  Duration get transitionDuration => AppMotion.fast;

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) =>
      themes.wrap(
        Builder(
          builder: (context) => CustomSingleChildLayout(
            delegate: _PopoverLayout(
              anchor: anchor,
              width: width,
              margins: MediaQuery.paddingOf(context) + const EdgeInsets.all(AppSpacing.lg),
              textDirection: Directionality.of(context),
            ),
            child: _Named(
              title: title,
              child: Material(
                color: Theme.of(context).dialogTheme.backgroundColor,
                elevation: AppElevation.dialog,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                clipBehavior: Clip.antiAlias,
                child: builder(context),
              ),
            ),
          ),
        ),
      );

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => MediaQuery.disableAnimationsOf(context)
      ? child
      : FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: AppMotion.curve),
          child: child,
        );
}

/// Places a popover under its anchor, or above it when there is more room
/// there, starting at the anchor's leading edge and kept inside the window.
class _PopoverLayout extends SingleChildLayoutDelegate {
  _PopoverLayout({required this.anchor, required this.width, required this.margins, required this.textDirection});

  final Rect anchor;
  final double width;
  final EdgeInsets margins;
  final TextDirection textDirection;

  static const _gap = AppSpacing.xs;

  double _below(Size window) => window.height - margins.bottom - anchor.bottom - _gap;
  double get _above => anchor.top - _gap - margins.top;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final fit = math.min(width, constraints.maxWidth - margins.horizontal);
    final height = math.max(_below(constraints.biggest), _above);
    return BoxConstraints.tightFor(width: math.max(0, fit)).copyWith(maxHeight: math.max(0, height));
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final below = _below(size);
    final y = childSize.height <= below || below >= _above
        ? anchor.bottom + _gap
        : anchor.top - _gap - childSize.height;
    final start = textDirection == TextDirection.ltr ? anchor.left : anchor.right - childSize.width;
    final x = start.clamp(margins.left, math.max(margins.left, size.width - margins.right - childSize.width));
    final top = y.clamp(margins.top, math.max(margins.top, size.height - margins.bottom - childSize.height));
    return Offset(x.toDouble(), top.toDouble());
  }

  @override
  bool shouldRelayout(_PopoverLayout old) =>
      anchor != old.anchor || width != old.width || margins != old.margins || textDirection != old.textDirection;
}

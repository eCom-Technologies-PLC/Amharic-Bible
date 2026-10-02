import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/strings.dart';
import '../../domain/custom_plan.dart';
import '../../domain/plans.dart';
import '../../state/providers.dart';
import '../../ui/ui.dart';
import '../common.dart';
import 'plan_widgets.dart';

enum _Scope { all, oldTestament, newTestament, gospels, psalmsProverbs, chosen }

enum _LengthMode { period, endDate, perDay }

/// Calendar days a period runs for when building a plan.
int periodCalendarDays(PlanPeriod p) => switch (p) {
  PlanPeriod.week => 7,
  PlanPeriod.month => 30,
  PlanPeriod.threeMonths => 90,
  PlanPeriod.sixMonths => 180,
  PlanPeriod.year => 365,
};

const _everyDay = {1, 2, 3, 4, 5, 6, 7};
const _mondayToFriday = {1, 2, 3, 4, 5};
const _exceptSunday = {1, 2, 3, 4, 5, 6};
const _perDayChoices = [1, 2, 3, 4, 5, 6, 8, 10];

/// Me → Reading plans → Make your own plan: one scrolling form whose choices
/// open bottom sheets, with a live preview of the pace and end date.
class PlanBuilderScreen extends ConsumerStatefulWidget {
  const PlanBuilderScreen({super.key});

  @override
  ConsumerState<PlanBuilderScreen> createState() => _PlanBuilderScreenState();
}

class _PlanBuilderScreenState extends ConsumerState<PlanBuilderScreen> {
  final _name = TextEditingController();
  bool _saving = false;

  _Scope _scope = _Scope.newTestament;
  Set<String> _chosenBooks = {};
  _LengthMode _mode = _LengthMode.period;
  PlanPeriod _period = PlanPeriod.threeMonths;
  DateTime? _endDate;
  int _perDay = 3;
  Set<int> _weekdays = _everyDay;
  late DateTime _start = _today;

  DateTime get _today {
    final now = ref.read(clockProvider)();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  List<String> _books(BibleCatalog c) => switch (_scope) {
    _Scope.all => c.codes,
    _Scope.oldTestament => c.oldTestament,
    _Scope.newTestament => c.newTestament,
    _Scope.gospels => BibleCatalog.gospels,
    _Scope.psalmsProverbs => const ['PSA', 'PRO'],
    _Scope.chosen => [
      for (final b in c.codes)
        if (_chosenBooks.contains(b)) b,
    ],
  };

  int _readingDays(BibleCatalog c) {
    switch (_mode) {
      case _LengthMode.period:
        final end = _start.add(Duration(days: periodCalendarDays(_period) - 1));
        return readingDaysThrough(_start, end, _weekdays);
      case _LengthMode.endDate:
        final end = _endDate;
        return end == null ? 0 : readingDaysThrough(_start, end, _weekdays);
      case _LengthMode.perDay:
        final chapters = c.chaptersOf(_books(c)).length;
        return (chapters / _perDay).ceil();
    }
  }

  String _scopeLabel(S s, Map<String, String> names) => switch (_scope) {
    _Scope.all => s.scopeAll,
    _Scope.oldTestament => s.oldTestament,
    _Scope.newTestament => s.newTestament,
    _Scope.gospels => s.scopeGospels,
    _Scope.psalmsProverbs => s.scopePsalmsProverbs,
    _Scope.chosen =>
      _chosenBooks.length == 1 ? (names[_chosenBooks.first] ?? _chosenBooks.first) : s.booksChosen(_chosenBooks.length),
  };

  String _lengthLabel(S s, Settings settings) => switch (_mode) {
    _LengthMode.period => periodLabel(_period, s),
    _LengthMode.endDate => _endDate == null ? s.chooseEndDate : s.until(formatDate(_endDate!, settings, s)),
    _LengthMode.perDay => s.chaptersADay(_perDay),
  };

  String _weekdaysLabel(S s) {
    if (_weekdays.length == 7) return s.everyDay;
    if (_weekdays.length == 5 && _weekdays.containsAll(_mondayToFriday)) return s.mondayToFriday;
    if (_weekdays.length == 6 && _weekdays.containsAll(_exceptSunday)) return s.exceptSunday;
    return [for (final d in _weekdays.toList()..sort()) s.weekdayNames[d - 1]].join(', ');
  }

  String _startLabel(S s, Settings settings) {
    if (_start == _today) return s.today;
    if (_start == _today.add(const Duration(days: 1))) return s.tomorrow;
    return formatDate(_start, settings, s);
  }

  /// Name used when the user leaves the field empty (shown as its hint).
  String _suggestedName(S s, Map<String, String> names, Settings settings) =>
      '${_scopeLabel(s, names)} · ${_lengthLabel(s, settings)}';

  PlanDraft _draft(BibleCatalog catalog) => PlanDraft(
    catalog: catalog,
    books: _books(catalog),
    weekdays: _weekdays,
    start: _start,
    readingDays: _readingDays(catalog),
  );

  Future<void> _pickScope(S s, BibleCatalog catalog, Map<String, String> names) async {
    final v = await showOptionPicker<_Scope>(
      context: context,
      title: s.whatToRead,
      selected: _scope,
      options: [
        PickerOption(_Scope.all, s.scopeAll),
        PickerOption(_Scope.oldTestament, s.oldTestament),
        PickerOption(_Scope.newTestament, s.newTestament),
        PickerOption(_Scope.gospels, s.scopeGospels),
        PickerOption(_Scope.psalmsProverbs, s.scopePsalmsProverbs),
        PickerOption(_Scope.chosen, s.chooseBooks),
      ],
    );
    if (v == null || !mounted) return;
    if (v == _Scope.chosen) {
      final books = await _chooseBooks(s, catalog, names);
      if (books == null || books.isEmpty) return;
      setState(() {
        _scope = _Scope.chosen;
        _chosenBooks = books;
      });
    } else {
      setState(() => _scope = v);
    }
  }

  Future<Set<String>?> _chooseBooks(S s, BibleCatalog catalog, Map<String, String> names) {
    final chosen = {..._chosenBooks};
    return showAppBottomSheet<Set<String>>(
      context: context,
      title: s.chooseBooks,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) {
          Widget group(String label, List<String> books) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(label, style: context.text.titleSmall?.copyWith(color: context.colors.primary)),
              for (final b in books)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: chosen.contains(b),
                  title: Text(names[b] ?? b),
                  onChanged: (v) => setSheet(() => v == true ? chosen.add(b) : chosen.remove(b)),
                ),
            ],
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              group(s.oldTestament, catalog.oldTestament),
              const SizedBox(height: AppSpacing.md),
              group(s.newTestament, catalog.newTestament),
              const SizedBox(height: AppSpacing.md),
              AppButton(label: s.done, expand: true, onPressed: () => Navigator.pop(context, chosen)),
            ],
          );
        },
      ),
    );
  }

  Future<void> _pickLength(S s, Settings settings) async {
    const endDate = -1, perDay = -2;
    final v = await showOptionPicker<int>(
      context: context,
      title: s.howLong,
      selected: switch (_mode) {
        _LengthMode.period => _period.index,
        _LengthMode.endDate => endDate,
        _LengthMode.perDay => perDay,
      },
      options: [
        for (final p in PlanPeriod.values) PickerOption(p.index, periodLabel(p, s)),
        PickerOption(endDate, s.chooseEndDate),
        PickerOption(perDay, s.byChaptersADay),
      ],
    );
    if (v == null || !mounted) return;
    if (v >= 0) {
      setState(() {
        _mode = _LengthMode.period;
        _period = PlanPeriod.values[v];
      });
    } else if (v == endDate) {
      final d = await _pickDate(s.chooseEndDate, _endDate ?? _start.add(const Duration(days: 29)), _start);
      if (d != null) {
        setState(() {
          _mode = _LengthMode.endDate;
          _endDate = d;
        });
      }
    } else {
      final n = await showOptionPicker<int>(
        context: context,
        title: s.byChaptersADay,
        selected: _mode == _LengthMode.perDay ? _perDay : null,
        options: [for (final n in _perDayChoices) PickerOption(n, s.chaptersADay(n))],
      );
      if (n != null) {
        setState(() {
          _mode = _LengthMode.perDay;
          _perDay = n;
        });
      }
    }
  }

  Future<void> _pickWeekdays(S s) async {
    const custom = <int>{};
    final presets = [_everyDay, _exceptSunday, _mondayToFriday];
    final v = await showOptionPicker<Set<int>>(
      context: context,
      title: s.readingDays,
      selected: presets.where((p) => p.length == _weekdays.length && p.containsAll(_weekdays)).firstOrNull,
      options: [
        PickerOption(_everyDay, s.everyDay),
        PickerOption(_exceptSunday, s.exceptSunday),
        PickerOption(_mondayToFriday, s.mondayToFriday),
        PickerOption(custom, s.chooseDays),
      ],
    );
    if (v == null || !mounted) return;
    if (!identical(v, custom)) {
      setState(() => _weekdays = v);
      return;
    }
    final chosen = {..._weekdays};
    final picked = await showAppBottomSheet<Set<int>>(
      context: context,
      title: s.chooseDays,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (var d = 1; d <= 7; d++)
                  FilterChip(
                    label: Text(s.weekdayNames[d - 1]),
                    selected: chosen.contains(d),
                    onSelected: (on) => setSheet(() => on ? chosen.add(d) : chosen.remove(d)),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(label: s.done, expand: true, onPressed: () => Navigator.pop(context, chosen)),
          ],
        ),
      ),
    );
    if (picked != null) setState(() => _weekdays = picked);
  }

  Future<void> _pickStart(S s) async {
    const today = 0, tomorrow = 1, other = 2;
    final v = await showOptionPicker<int>(
      context: context,
      title: s.startDate,
      selected: _start == _today
          ? today
          : _start == _today.add(const Duration(days: 1))
          ? tomorrow
          : other,
      options: [PickerOption(today, s.today), PickerOption(tomorrow, s.tomorrow), PickerOption(other, s.chooseDate)],
    );
    if (v == null || !mounted) return;
    if (v == other) {
      final d = await _pickDate(s.startDate, _start, _today);
      if (d != null) setState(() => _start = d);
    } else {
      setState(() => _start = _today.add(Duration(days: v)));
    }
  }

  Future<DateTime?> _pickDate(String title, DateTime initial, DateTime first) {
    final last = _today.add(const Duration(days: 2 * 366));
    return showAppBottomSheet<DateTime>(
      context: context,
      title: title,
      builder: (context) => CalendarDatePicker(
        initialDate: initial.isBefore(first) ? first : (initial.isAfter(last) ? last : initial),
        firstDate: first,
        lastDate: last,
        onDateChanged: (d) => Navigator.pop(context, DateTime(d.year, d.month, d.day)),
      ),
    );
  }

  Future<void> _create(PlanDraft draft, String suggestedName) async {
    setState(() => _saving = true);
    final name = _name.text.trim().isEmpty ? suggestedName : _name.text.trim();
    final id = '${CustomPlanSpec.idPrefix}${const Uuid().v7()}';
    final spec = draft.build(id: id, name: name);
    await ref.read(userRepositoryProvider).saveCustomPlan(id, spec.encode());
    if (!mounted) return;
    invalidateUserData(ref);
    context.replace('/me/plans/$id');
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final settings = ref.watch(settingsProvider);
    final names = ref.watch(bookNamesProvider).value ?? const {};
    final catalog = ref.watch(bibleCatalogProvider).value;
    final draft = catalog == null ? null : _draft(catalog);
    final suggestedName = _suggestedName(s, names, settings);

    return AppScaffold(
      title: s.newPlan,
      body: AsyncView(
        value: ref.watch(bibleCatalogProvider),
        onRetry: () => ref.invalidate(bibleCatalogProvider),
        data: (catalog) => AppListView(
          children: [
            Gutter(
              vertical: AppSpacing.sm,
              child: AppTextField(
                controller: _name,
                label: s.planName,
                hint: suggestedName,
                maxLength: 60,
                textInputAction: TextInputAction.done,
              ),
            ),
            AppListTile(
              leadingIcon: Icons.menu_book_outlined,
              title: s.whatToRead,
              subtitle: _scopeLabel(s, names),
              chevron: true,
              onTap: () => _pickScope(s, catalog, names),
            ),
            AppListTile(
              leadingIcon: Icons.date_range_outlined,
              title: s.howLong,
              subtitle: _lengthLabel(s, settings),
              chevron: true,
              onTap: () => _pickLength(s, settings),
            ),
            AppListTile(
              leadingIcon: Icons.event_repeat_outlined,
              title: s.readingDays,
              subtitle: _weekdaysLabel(s),
              chevron: true,
              onTap: () => _pickWeekdays(s),
            ),
            AppListTile(
              leadingIcon: Icons.play_circle_outline,
              title: s.startDate,
              subtitle: _startLabel(s, settings),
              chevron: true,
              onTap: () => _pickStart(s),
            ),
            _Preview(draft: _draft(catalog), endBeforeStart: _mode == _LengthMode.endDate && _readingDays(catalog) < 1),
          ],
        ),
      ),
      bottomBar: BottomActionBar(
        children: [
          AppButton(
            label: s.createPlan,
            icon: Icons.check,
            size: AppButtonSize.lg,
            expand: true,
            loading: _saving,
            onPressed: draft != null && draft.valid && !_saving ? () => _create(draft, suggestedName) : null,
          ),
        ],
      ),
    );
  }
}

/// Live summary: pace, time a day, reading days, end date, and any warning.
class _Preview extends ConsumerWidget {
  const _Preview({required this.draft, required this.endBeforeStart});

  final PlanDraft draft;
  final bool endBeforeStart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final settings = ref.watch(settingsProvider);
    final problem = draft.chapters.isEmpty
        ? s.noBooksChosen
        : draft.weekdays.isEmpty
        ? s.noReadingDays
        : endBeforeStart
        ? s.endBeforeStart
        : draft.tooLong
        ? s.planTooLong
        : null;
    final warning = problem != null
        ? null
        : draft.heavy
        ? s.heavyPlan
        : draft.shortened
        ? s.tooManyDays
        : null;
    final perDay = draft.chaptersPerDay;
    final tenths = (perDay * 10).round();
    final perDayText = tenths % 10 == 0 ? '${tenths ~/ 10}' : (tenths / 10).toStringAsFixed(1);
    final pace = PlanPace.of(draft.minutesPerDay);

    return AppCard(
      eyebrow: s.preview,
      child: problem != null
          ? Text(problem, style: context.text.bodyMedium?.copyWith(color: context.colors.error))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.aboutChaptersADay(perDayText), style: context.text.titleMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${s.readingDayCount(draft.days)} · ${s.finishesOn(formatDate(draft.end, settings, s))}',
                  style: context.text.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: [
                    StatusBadge(s.minutesPerDay(draft.minutesPerDay), icon: Icons.schedule_outlined),
                    StatusBadge(switch (pace) {
                      PlanPace.light => s.paceLight,
                      PlanPace.steady => s.paceSteady,
                      PlanPace.intensive => s.paceIntensive,
                    }, tone: pace == PlanPace.intensive ? BadgeTone.warning : BadgeTone.info),
                  ],
                ),
                if (warning != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(warning, style: context.text.bodySmall?.copyWith(color: context.appColors.warning)),
                ],
              ],
            ),
    );
  }
}

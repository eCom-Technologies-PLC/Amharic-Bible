import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/strings.dart';
import '../../data/assistant_repository.dart';
import '../../domain/models.dart';
import '../../state/providers.dart';
import '../../state/study.dart';
import '../../ui/ui.dart';
import '../common.dart';
import 'verse_study_screen.dart' show openReader;

/// Verses the assistant is asked about: [start]..[end] in one chapter, at most five.
List<int> askVerses(int start, int? end) {
  final last = end == null || end < start || end ~/ 1000 != start ~/ 1000 ? start : end;
  return [for (var k = start; k <= last && k < start + 5; k++) k];
}

String perspectiveLabel(S s, AssistantPerspective p) => switch (p) {
  AssistantPerspective.general => s.perspectiveGeneral,
  AssistantPerspective.orthodox => s.perspectiveOrthodox,
  AssistantPerspective.protestant => s.perspectiveProtestant,
  AssistantPerspective.catholic => s.perspectiveCatholic,
  AssistantPerspective.academic => s.perspectiveAcademic,
};

String _taskLabel(S s, AssistantTask t) => switch (t) {
  AssistantTask.explain => s.aiExplain,
  AssistantTask.summarize => s.aiSummarize,
  AssistantTask.questions => s.aiQuestions,
  AssistantTask.sermon => s.aiSermon,
  AssistantTask.ask => s.aiAskQuestion,
};

/// The tasks offered as one-tap chips (a typed question is the fifth).
const _quickTasks = [
  (AssistantTask.explain, Icons.lightbulb_outline),
  (AssistantTask.summarize, Icons.short_text),
  (AssistantTask.questions, Icons.quiz_outlined),
  (AssistantTask.sermon, Icons.campaign_outlined),
];

/// One exchange: a task or a question, then its answer (or why there is none).
class _Turn {
  _Turn({required this.task, required this.question});

  final AssistantTask task;
  final String question;
  final key = GlobalKey();
  AssistantAnswer? answer;
  String? error;
}

/// The AI study assistant for a passage, as a conversation: tasks and
/// questions go in at the bottom, answers come back as labelled segments.
/// Scripture is always shown from the app's own text, AI explanations and
/// debated interpretations are marked as such, and sources open on a tap.
class AskScreen extends ConsumerStatefulWidget {
  const AskScreen({super.key, required this.vkeys});

  final List<int> vkeys;

  @override
  ConsumerState<AskScreen> createState() => _AskScreenState();
}

class _AskScreenState extends ConsumerState<AskScreen> {
  final _question = TextEditingController();
  AssistantLevel _level = AssistantLevel.simple;
  AssistantPerspective _perspective = AssistantPerspective.general;

  /// The conversation so far, while the screen is open.
  final _turns = <_Turn>[];

  bool get _waiting => _turns.isNotEmpty && _turns.last.answer == null && _turns.last.error == null;

  @override
  void dispose() {
    _question.dispose();
    super.dispose();
  }

  Future<void> _ask(String reference, AssistantTask task, [String question = '']) async {
    final turn = _Turn(task: task, question: question);
    setState(() => _turns.add(turn));
    if (question.isNotEmpty) _question.clear();
    _reveal(turn);
    await _fetch(turn, reference);
  }

  Future<void> _fetch(_Turn turn, String reference) async {
    final s = S.of(context);
    final version = await ref.read(currentVersionProvider.future);
    AssistantAnswer? answer;
    String? error;
    try {
      answer = await ref
          .read(assistantRepositoryProvider)
          .ask(
            task: turn.task,
            level: _level,
            perspective: _perspective,
            language: s.locale.languageCode,
            reference: reference,
            vkeys: widget.vkeys,
            versionId: version.id,
            question: turn.question,
          );
    } on AssistantUnavailable catch (e) {
      error = switch (e.reason) {
        'declined' => s.aiDeclined,
        'busy' => s.aiBusy,
        _ => s.loadError,
      };
    } on Exception {
      error = s.loadError;
    }
    if (!mounted) return;
    setState(() {
      turn.answer = answer;
      turn.error = error;
    });
    _reveal(turn);
  }

  /// Scrolls [turn] (the request, then its answer) to the top of the view.
  void _reveal(_Turn turn) => WidgetsBinding.instance.addPostFrameCallback((_) {
    final target = turn.key.currentContext;
    if (target != null && target.mounted) {
      Scrollable.ensureVisible(target, duration: AppMotion.medium, curve: AppMotion.curve);
    }
  });

  void _showOptions(S s) => showAppBottomSheet<void>(
    context: context,
    title: s.aiOptions,
    builder: (sheet) => StatefulBuilder(
      builder: (sheet, setSheet) {
        void change(void Function() update) {
          setState(update);
          setSheet(() {});
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LabeledGroup(
              label: s.aiLevel,
              child: FilterBar<AssistantLevel>(
                padding: EdgeInsets.zero,
                selected: _level,
                onSelected: (l) => change(() => _level = l),
                options: [
                  FilterOption(AssistantLevel.simple, s.aiLevelSimple),
                  FilterOption(AssistantLevel.scholar, s.aiLevelScholar),
                ],
              ),
            ),
            LabeledGroup(
              label: s.aiPerspective,
              child: Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final p in AssistantPerspective.values)
                    ChoiceChip(
                      label: Text(perspectiveLabel(s, p)),
                      selected: p == _perspective,
                      onSelected: (_) => change(() => _perspective = p),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    ),
  );

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final books = ref.watch(refBooksProvider).value ?? const <Book>[];
    final reference = books.isEmpty ? '' : formatKeys(books, widget.vkeys, amharic: s.isAmharic);

    if (!ref.watch(assistantRepositoryProvider).configured) {
      return AppScaffold(
        title: s.aiAssistant,
        body: EmptyState(message: s.aiNotConfigured, icon: Icons.auto_awesome_outlined),
      );
    }
    final ready = reference.isNotEmpty && !_waiting;
    final typed = _question.text.trim();
    void send() {
      if (ready && typed.isNotEmpty) _ask(reference, AssistantTask.ask, typed);
    }

    return AppScaffold(
      title: s.aiAssistant,
      // The composer sits in the body, so it stays above the keyboard.
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: AppListView(
              children: [
                Gutter(
                  vertical: AppSpacing.md,
                  child: Text(reference, style: context.text.titleMedium),
                ),
                Gutter(
                  child: Text(
                    s.aiDisclaimer,
                    style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
                  ),
                ),
                if (_turns.isEmpty)
                  Gutter(
                    vertical: AppSpacing.lg,
                    child: Text(s.aiStartWith, style: context.text.titleSmall?.copyWith(color: context.colors.primary)),
                  ),
                for (final turn in _turns)
                  _TurnView(
                    key: turn.key,
                    turn: turn,
                    label: turn.question.isNotEmpty ? turn.question : _taskLabel(s, turn.task),
                    books: books,
                    onRetry: () {
                      setState(() => turn.error = null);
                      _fetch(turn, reference);
                    },
                    onFollowUp: (q) {
                      if (ready) _ask(reference, AssistantTask.ask, q);
                    },
                  ),
              ],
            ),
          ),
          BottomActionBar(
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final (task, icon) in _quickTasks) ...[
                      ActionChip(
                        avatar: Icon(icon, size: AppIconSize.sm),
                        label: Text(_taskLabel(s, task)),
                        onPressed: ready ? () => _ask(reference, task) : null,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                    // Level and tradition, in a sheet; the chip shows the current ones.
                    ActionChip(
                      avatar: const Icon(Icons.tune, size: AppIconSize.sm),
                      label: Text('${_levelLabel(s)} · ${perspectiveLabel(s, _perspective)}'),
                      tooltip: s.aiOptions,
                      onPressed: () => _showOptions(s),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _question,
                      hint: s.aiQuestionHint,
                      textInputAction: TextInputAction.send,
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) => send(),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  IconButton.filled(
                    tooltip: s.aiSend,
                    icon: _waiting ? const InlineSpinner() : const Icon(Icons.arrow_upward),
                    onPressed: ready && typed.isNotEmpty ? send : null,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _levelLabel(S s) => switch (_level) {
    AssistantLevel.simple => s.aiLevelSimple,
    AssistantLevel.scholar => s.aiLevelScholar,
  };
}

/// One exchange: the reader's request at the end of the line, then the answer
/// (a placeholder while it is written, or why it failed, with Retry).
class _TurnView extends StatelessWidget {
  const _TurnView({
    super.key,
    required this.turn,
    required this.label,
    required this.books,
    required this.onRetry,
    required this.onFollowUp,
  });

  final _Turn turn;
  final String label;
  final List<Book> books;
  final VoidCallback onRetry;
  final ValueChanged<String> onFollowUp;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final answer = turn.answer;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.xxxl,
            AppSpacing.lg,
            AppSpacing.screen,
            AppSpacing.sm,
          ),
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: context.colors.primaryContainer,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                child: Text(label, style: context.text.bodyLarge?.copyWith(color: context.colors.onPrimaryContainer)),
              ),
            ),
          ),
        ),
        if (turn.error case final error?)
          ErrorState(message: error, onRetry: onRetry)
        else if (answer == null)
          const _Writing()
        else ...[
          Gutter(
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: StatusBadge(s.aiWritten, icon: Icons.auto_awesome_outlined, tone: BadgeTone.info),
            ),
          ),
          AnswerView(answer: answer, books: books, onFollowUp: onFollowUp),
        ],
      ],
    );
  }
}

/// While an answer is written: a line saying so, over a few grey bars.
class _Writing extends StatelessWidget {
  const _Writing();

  @override
  Widget build(BuildContext context) {
    final bar = BoxDecoration(
      color: context.colors.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(AppRadius.sm),
    );
    return Gutter(
      vertical: AppSpacing.sm,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            liveRegion: true,
            child: Text(
              S.of(context).aiWriting,
              style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
            ),
          ),
          for (final width in const [1.0, 0.9, 0.6])
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: FractionallySizedBox(
                alignment: AlignmentDirectional.centerStart,
                widthFactor: width,
                child: DecoratedBox(
                  decoration: bar,
                  child: const SizedBox(height: AppSpacing.md),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// An assistant answer, segment by segment, each labelled with what it is.
class AnswerView extends ConsumerWidget {
  const AnswerView({super.key, required this.answer, required this.books, required this.onFollowUp});

  final AssistantAnswer answer;
  final List<Book> books;
  final ValueChanged<String> onFollowUp;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final a = answer;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final seg in a.segments) _Segment(segment: seg, sources: a.sources, books: books),
        if (a.uncertainty case final u?)
          AppCard(
            eyebrow: s.aiUncertain,
            child: Text(u, style: context.text.bodyMedium),
          ),
        if (a.followUps.isNotEmpty) ...[
          SectionHeader(s.aiFollowUp),
          for (final q in a.followUps)
            AppListTile(leadingIcon: Icons.help_outline, title: q, chevron: true, onTap: () => onFollowUp(q)),
        ],
      ],
    );
  }
}

class _Segment extends ConsumerWidget {
  const _Segment({required this.segment, required this.sources, required this.books});

  final AnswerSegment segment;
  final Map<String, AssistantSource> sources;
  final List<Book> books;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final seg = segment;
    final cited = [for (final id in seg.sourceIds) ?sources[id]];
    // Each source the segment cites, as a chip that opens it.
    final citations = cited.isEmpty
        ? null
        : Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final c in cited)
                  ActionChip(
                    avatar: const Icon(Icons.source_outlined, size: AppIconSize.sm),
                    label: Text(c.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                    tooltip: '${s.aiCited}: ${c.title}',
                    onPressed: () => _showSource(context, c, books),
                  ),
              ],
            ),
          );

    if (seg.kind == SegmentKind.scripture) {
      // Scripture comes from the app's own text, never from the model.
      final version = ref.watch(currentVersionProvider).value;
      final verses = version == null
          ? const <int, Verse>{}
          : ref.watch(versesByKeyProvider((versionId: version.id, keys: seg.vkeys.join(',')))).value ??
                const <int, Verse>{};
      return AppCard(
        eyebrow:
            '${formatKeys(books, seg.vkeys, amharic: s.isAmharic)}${version != null ? ' (${version.abbrev})' : ''}',
        trailing: const Icon(Icons.menu_book_outlined),
        onTap: () => openReader(context, books, seg.vkeys.first),
        child: Text([for (final k in seg.vkeys) ?verses[k]?.text].join(' '), style: context.scriptureSnippet),
      );
    }
    final (label, tone, icon) = switch (seg.kind) {
      SegmentKind.quote => (s.aiQuoteLabel, BadgeTone.info, Icons.format_quote),
      SegmentKind.opinion => (s.aiInterpretationLabel, BadgeTone.warning, Icons.forum_outlined),
      _ => (s.aiExplanationLabel, BadgeTone.neutral, Icons.auto_awesome_outlined),
    };
    return Gutter(
      vertical: AppSpacing.sm,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              StatusBadge(label, tone: tone, icon: icon),
              if (!seg.verified) StatusBadge(s.aiUnverified, tone: BadgeTone.error, icon: Icons.report_outlined),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            seg.kind == SegmentKind.quote ? '“${seg.text}”' : seg.text,
            style: seg.kind == SegmentKind.quote
                ? context.text.bodyLarge?.copyWith(fontStyle: FontStyle.italic)
                : context.text.bodyLarge,
          ),
          ?citations,
        ],
      ),
    );
  }
}

/// A source the assistant was given (a verse, a lexicon entry, commentary…):
/// its text and credit, and the passage when it has one.
void _showSource(BuildContext context, AssistantSource source, List<Book> books) {
  final s = S.of(context);
  showAppBottomSheet<void>(
    context: context,
    title: source.title,
    builder: (sheet) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(source.text, style: source.kind == 'scripture' ? sheet.scriptureSnippet : sheet.text.bodyLarge),
        if (source.attribution.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Text(source.attribution, style: sheet.text.bodySmall),
        ],
        if (source.vkey case final k?) ...[
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: AppButton.secondary(
              label: s.openInReader,
              icon: Icons.menu_book_outlined,
              onPressed: () {
                Navigator.of(sheet).pop();
                openReader(context, books, k);
              },
            ),
          ),
        ],
      ],
    ),
  );
}

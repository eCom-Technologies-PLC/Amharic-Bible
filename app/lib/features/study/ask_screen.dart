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

/// The AI study assistant for a passage. Answers come back as labelled
/// segments: Scripture is always shown from the app's own text, AI
/// explanations and debated interpretations are marked as such, and quotes
/// name their source.
class AskScreen extends ConsumerStatefulWidget {
  const AskScreen({super.key, required this.vkeys});

  final List<int> vkeys;

  @override
  ConsumerState<AskScreen> createState() => _AskScreenState();
}

class _AskScreenState extends ConsumerState<AskScreen> {
  final _question = TextEditingController();
  AssistantTask _task = AssistantTask.explain;
  AssistantLevel _level = AssistantLevel.simple;
  AssistantPerspective _perspective = AssistantPerspective.general;
  AssistantAnswer? _answer;
  String? _error;
  bool _loading = false;

  @override
  void dispose() {
    _question.dispose();
    super.dispose();
  }

  Future<void> _ask(String reference) async {
    final s = S.of(context);
    final version = await ref.read(currentVersionProvider.future);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final answer = await ref
          .read(assistantRepositoryProvider)
          .ask(
            task: _task,
            level: _level,
            perspective: _perspective,
            language: s.locale.languageCode,
            reference: reference,
            vkeys: widget.vkeys,
            versionId: version.id,
            question: _question.text.trim(),
          );
      if (mounted) setState(() => _answer = answer);
    } on AssistantUnavailable catch (e) {
      if (mounted) {
        setState(
          () => _error = switch (e.reason) {
            'declined' => s.aiDeclined,
            'busy' => s.aiBusy,
            _ => s.loadError,
          },
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final books = ref.watch(refBooksProvider).value ?? const <Book>[];
    final reference = books.isEmpty ? '' : formatKeys(books, widget.vkeys, amharic: s.isAmharic);
    final configured = ref.watch(assistantRepositoryProvider).configured;
    final canAsk = configured && !_loading && (_task != AssistantTask.ask || _question.text.trim().isNotEmpty);

    if (!configured) {
      return AppScaffold(
        title: s.aiAssistant,
        body: EmptyState(message: s.aiNotConfigured, icon: Icons.auto_awesome_outlined),
      );
    }
    return AppScaffold(
      title: s.aiAssistant,
      bottomBar: BottomActionBar(
        children: [
          AppButton(
            label: s.aiSend,
            icon: Icons.auto_awesome_outlined,
            loading: _loading,
            expand: true,
            onPressed: canAsk && reference.isNotEmpty ? () => _ask(reference) : null,
          ),
        ],
      ),
      body: AppListView(
        children: [
          Gutter(
            vertical: AppSpacing.md,
            child: Text(reference, style: context.text.titleMedium),
          ),
          FilterBar<AssistantTask>(
            selected: _task,
            onSelected: (t) => setState(() => _task = t),
            options: [
              FilterOption(AssistantTask.explain, s.aiExplain),
              FilterOption(AssistantTask.summarize, s.aiSummarize),
              FilterOption(AssistantTask.questions, s.aiQuestions),
              FilterOption(AssistantTask.sermon, s.aiSermon),
              FilterOption(AssistantTask.ask, s.aiAskQuestion),
            ],
          ),
          if (_task == AssistantTask.ask)
            Gutter(
              vertical: AppSpacing.sm,
              child: AppTextField(
                controller: _question,
                hint: s.aiQuestionHint,
                multiline: true,
                onChanged: (_) => setState(() {}),
              ),
            ),
          FilterBar<AssistantLevel>(
            selected: _level,
            onSelected: (l) => setState(() => _level = l),
            options: [
              FilterOption(AssistantLevel.simple, s.aiLevelSimple),
              FilterOption(AssistantLevel.scholar, s.aiLevelScholar),
            ],
          ),
          AppListTile(
            leadingIcon: Icons.church_outlined,
            title: s.aiPerspective,
            subtitle: perspectiveLabel(s, _perspective),
            chevron: true,
            onTap: () async {
              final v = await showOptionPicker<AssistantPerspective>(
                context: context,
                title: s.aiPerspective,
                selected: _perspective,
                options: [for (final p in AssistantPerspective.values) PickerOption(p, perspectiveLabel(s, p))],
              );
              if (v != null) setState(() => _perspective = v);
            },
          ),
          Gutter(
            vertical: AppSpacing.sm,
            child: Text(
              s.aiDisclaimer,
              style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
            ),
          ),
          if (_loading) const Padding(padding: EdgeInsets.all(AppSpacing.xl), child: LoadingState()),
          if (_error case final e? when !_loading) ErrorState(message: e, onRetry: () => _ask(reference)),
          if (_answer case final a? when !_loading && _error == null)
            AnswerView(
              answer: a,
              books: books,
              onFollowUp: (q) {
                setState(() {
                  _task = AssistantTask.ask;
                  _question.text = q;
                });
                _ask(reference);
              },
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
    final citations = cited.isEmpty
        ? null
        : Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Text(
              '${s.aiCited}: ${cited.map((c) => c.title).join('; ')}',
              style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
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

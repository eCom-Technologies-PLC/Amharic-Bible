import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/strings.dart';
import '../../core/vkey.dart';
import '../../data/groups.dart';
import '../../domain/models.dart';
import '../../domain/plans.dart';
import '../../state/groups.dart';
import '../../state/providers.dart';
import '../../state/study.dart';
import '../../ui/ui.dart';
import '../common.dart';
import '../plans/plan_widgets.dart' show ReadingChips;
import '../study/verse_study_screen.dart' show openReader;
import 'groups_screen.dart' show groupErrorText;

/// Runs a group change, then reloads the group; failures become a message.
Future<void> _change(BuildContext context, WidgetRef ref, String groupId, Future<void> Function(GroupService) f) async {
  try {
    await f(ref.read(groupServiceProvider)!);
    ref.invalidate(groupDetailProvider(groupId));
  } catch (e) {
    if (context.mounted) showAppSnack(context, groupErrorText(S.of(context), e));
  }
}

/// Deletes a message or assignment for everyone, after confirming.
Future<void> _deletePost(BuildContext context, WidgetRef ref, String groupId, String postId) async {
  final s = S.of(context);
  final ok = await showConfirmDialog(
    context: context,
    title: s.deletePostConfirm,
    message: s.deletePostMessage,
    confirmLabel: s.delete,
    cancelLabel: s.cancel,
    destructive: true,
  );
  if (ok && context.mounted) await _change(context, ref, groupId, (g) => g.deletePost(postId));
}

String _passage(List<Book> books, int start, int? end, bool amharic) =>
    formatKeys(books, [for (var k = start; k <= (end ?? start) && k - start < 200; k++) k], amharic: amharic);

/// One study group: who is in it and a way to invite more, then the
/// discussion, assignments, the shared reading plan and members, in tabs.
class GroupScreen extends ConsumerWidget {
  const GroupScreen({super.key, required this.groupId});

  final String groupId;

  Future<void> _leave(BuildContext context, WidgetRef ref) async {
    final s = S.of(context);
    final ok = await showConfirmDialog(
      context: context,
      title: s.leaveGroup,
      message: s.leaveGroupConfirm,
      confirmLabel: s.leaveGroup,
      cancelLabel: s.cancel,
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    await _change(context, ref, groupId, (g) => g.leave(groupId));
    ref.invalidate(myGroupsProvider);
    if (context.mounted) context.pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final detail = ref.watch(groupDetailProvider(groupId));
    return DefaultTabController(
      length: 4,
      child: AppScaffold(
        title: detail.value?.group.name ?? s.studyGroups,
        actions: [
          // Leaving is rare and final: in the menu, not beside the title.
          PopupMenuButton<String>(
            tooltip: s.moreActions,
            onSelected: (_) => _leave(context, ref),
            itemBuilder: (_) => [PopupMenuItem(value: 'leave', child: Text(s.leaveGroup))],
          ),
        ],
        body: AsyncView(
          value: detail,
          onRetry: () => ref.invalidate(groupDetailProvider(groupId)),
          data: (d) => ContentWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _GroupHeader(detail: d),
                TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  tabs: [
                    Tab(text: s.discussion),
                    Tab(text: s.assignments),
                    Tab(text: s.readingPlan),
                    Tab(text: s.members),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _Discussion(detail: d),
                      _Assignments(detail: d),
                      _Plan(detail: d),
                      _Members(detail: d),
                    ],
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

/// Who is in the group (the first few, then the count) and Invite.
class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.detail});

  final GroupDetail detail;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final members = detail.members;
    return Gutter(
      vertical: AppSpacing.sm,
      child: Row(
        children: [
          for (final m in members.take(4))
            Padding(
              padding: const EdgeInsetsDirectional.only(end: AppSpacing.xs),
              child: Tooltip(
                message: m.name,
                child: MonogramAvatar(name: m.name, small: true),
              ),
            ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              s.memberCount(members.length),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant),
            ),
          ),
          Builder(
            builder: (button) => AppButton.secondary(
              label: s.invite,
              icon: Icons.person_add_alt_1_outlined,
              size: AppButtonSize.sm,
              onPressed: () => showAppBottomSheet<void>(
                context: context,
                title: s.invite,
                anchor: button,
                builder: (_) => _InviteCode(groupId: detail.group.id),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The group's invite code, with Copy, Share and (for teachers) a new code.
/// Watches the group, so a new code shows at once.
class _InviteCode extends ConsumerWidget {
  const _InviteCode({required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final g = ref.watch(groupDetailProvider(groupId)).value?.group;
    if (g == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelectableText(g.inviteCode, style: context.text.headlineSmall),
        Text(s.inviteCodeHint, style: context.text.bodySmall),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            AppButton(
              label: s.share,
              icon: Icons.share_outlined,
              size: AppButtonSize.sm,
              onPressed: () => shareText(context, s.inviteMessage(g.name, g.inviteCode)),
            ),
            AppButton.secondary(
              label: s.copy,
              icon: Icons.copy,
              size: AppButtonSize.sm,
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: g.inviteCode));
                if (context.mounted) showAppSnack(context, s.copied);
              },
            ),
            if (g.isTeacher)
              AppButton.ghost(
                label: s.newInviteCode,
                icon: Icons.refresh,
                size: AppButtonSize.sm,
                onPressed: () => _change(context, ref, g.id, (svc) => svc.newInviteCode(g.id)),
              ),
          ],
        ),
      ],
    );
  }
}

class _Discussion extends ConsumerStatefulWidget {
  const _Discussion({required this.detail});
  final GroupDetail detail;

  @override
  ConsumerState<_Discussion> createState() => _DiscussionState();
}

class _DiscussionState extends ConsumerState<_Discussion> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final body = _text.text.trim();
    if (body.isEmpty) return;
    final id = widget.detail.group.id;
    await _change(context, ref, id, (g) => g.postMessage(id, body));
    _text.clear();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final d = widget.detail;
    final me = ref.watch(groupServiceProvider)?.userId;
    final settings = ref.watch(settingsProvider);
    final books = ref.watch(refBooksProvider).value ?? const <Book>[];
    // Newest first, shown from the bottom up: the latest sits by the composer.
    final messages = d.posts.where((p) => !p.isAssignment).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: messages.isEmpty
              ? EmptyState(message: s.noMessages, icon: Icons.forum_outlined)
              : ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  itemCount: messages.length,
                  itemBuilder: (context, i) {
                    final p = messages[i];
                    return _Message(
                      name: d.nameOf(p.userId),
                      date: formatDate(p.createdAt.toLocal(), settings, s),
                      passage: p.vkeyStart == null ? null : _passage(books, p.vkeyStart!, p.vkeyEnd, s.isAmharic),
                      day: p.day,
                      body: p.body,
                      mine: p.userId == me,
                      onDelete: p.userId == me || d.group.isTeacher
                          ? () => _deletePost(context, ref, d.group.id, p.id)
                          : null,
                    );
                  },
                ),
        ),
        const Divider(),
        // The composer at the bottom, so it stays above the keyboard.
        Gutter(
          vertical: AppSpacing.sm,
          child: Row(
            children: [
              Expanded(
                child: AppTextField(
                  controller: _text,
                  hint: s.writeMessage,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              IconButton.filled(tooltip: s.send, icon: const Icon(Icons.send), onPressed: _send),
            ],
          ),
        ),
      ],
    );
  }
}

/// A message in the discussion: the writer's own at the end of the line,
/// others' at the start with their initial. The writer and teachers can
/// delete it (after confirming).
class _Message extends StatelessWidget {
  const _Message({
    required this.name,
    required this.date,
    required this.passage,
    required this.day,
    required this.body,
    required this.mine,
    required this.onDelete,
  });

  final String name;
  final String date;
  final String? passage;
  final int? day;
  final String body;
  final bool mine;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final scheme = context.colors;
    final ink = mine ? scheme.onPrimaryContainer : scheme.onSurface;
    final bubble = DecoratedBox(
      decoration: BoxDecoration(
        color: mine ? scheme.primaryContainer : scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (passage case final passage?)
              Text(passage, style: context.text.labelMedium?.copyWith(color: mine ? ink : scheme.primary)),
            if (day case final day?) Text(s.day(day), style: context.text.labelMedium?.copyWith(color: ink)),
            Text(body, style: context.text.bodyMedium?.copyWith(color: ink)),
          ],
        ),
      ),
    );
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        mine ? AppSpacing.xxxl : AppSpacing.screen,
        AppSpacing.xs,
        mine ? AppSpacing.screen : AppSpacing.xxxl,
        AppSpacing.xs,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!mine) ...[MonogramAvatar(name: name, small: true), const SizedBox(width: AppSpacing.sm)],
          Expanded(
            child: Column(
              crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Text(
                  '$name · $date',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (mine && onDelete != null) _deleteButton(s),
                    Flexible(child: bubble),
                    if (!mine && onDelete != null) _deleteButton(s),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _deleteButton(S s) =>
      IconButton(tooltip: s.delete, icon: const Icon(Icons.delete_outline), onPressed: onDelete);
}

class _Assignments extends ConsumerWidget {
  const _Assignments({required this.detail});
  final GroupDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final d = detail;
    final me = ref.watch(groupServiceProvider)?.userId;
    final settings = ref.watch(settingsProvider);
    final books = ref.watch(refBooksProvider).value ?? const <Book>[];
    final items = d.posts.where((p) => p.isAssignment).toList();
    return AppListView(
      children: [
        if (d.group.isTeacher)
          Gutter(
            vertical: AppSpacing.sm,
            child: AppButton.secondary(
              label: s.newAssignment,
              icon: Icons.add_task,
              expand: true,
              onPressed: () => showAppBottomSheet<void>(
                context: context,
                title: s.newAssignment,
                builder: (sheet) => _AssignmentForm(groupId: d.group.id, onDone: () => Navigator.of(sheet).pop()),
              ),
            ),
          ),
        if (items.isEmpty) EmptyState(message: s.noAssignments, icon: Icons.task_alt),
        for (final p in items)
          AppCard(
            eyebrow: p.dueDate != null ? s.dueOn(formatDate(p.dueDate!, settings, s)) : s.assignment,
            trailing: d.group.isTeacher
                ? IconButton(
                    tooltip: s.delete,
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _deletePost(context, ref, d.group.id, p.id),
                  )
                : null,
            actions: [
              if (d.group.isTeacher)
                Text(
                  s.doneCount((d.doneBy[p.id] ?? const {}).length, d.members.length),
                  style: context.text.labelMedium,
                ),
              (d.doneBy[p.id]?.contains(me) ?? false)
                  ? AppButton.ghost(
                      label: s.doneLabel,
                      icon: Icons.check_circle,
                      size: AppButtonSize.sm,
                      onPressed: () => _change(context, ref, d.group.id, (g) => g.setAssignmentDone(p.id, false)),
                    )
                  : AppButton.secondary(
                      label: s.markDone,
                      size: AppButtonSize.sm,
                      onPressed: () => _change(context, ref, d.group.id, (g) => g.setAssignmentDone(p.id, true)),
                    ),
            ],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.body, style: context.text.bodyLarge),
                if (p.vkeyStart != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  AppButton.ghost(
                    label: _passage(books, p.vkeyStart!, p.vkeyEnd, s.isAmharic),
                    icon: Icons.menu_book_outlined,
                    size: AppButtonSize.sm,
                    tight: true,
                    onPressed: () => openReader(context, books, p.vkeyStart!),
                  ),
                ],
                const SizedBox(height: AppSpacing.xs),
                Text(d.nameOf(p.userId), style: context.text.bodySmall),
              ],
            ),
          ),
      ],
    );
  }
}

/// Days until an assignment is due.
const _dueOptions = [0, 1, 3, 7, 14];

class _AssignmentForm extends ConsumerStatefulWidget {
  const _AssignmentForm({required this.groupId, required this.onDone});
  final String groupId;
  final VoidCallback onDone;

  @override
  ConsumerState<_AssignmentForm> createState() => _AssignmentFormState();
}

class _AssignmentFormState extends ConsumerState<_AssignmentForm> {
  final _body = TextEditingController();
  final _passage = TextEditingController();
  int _dueIn = 7;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _body.dispose();
    _passage.dispose();
    super.dispose();
  }

  String _dueLabel(S s, int days) => days == 0 ? s.noDueDate : s.inDays(days);

  Future<void> _submit() async {
    final s = S.of(context);
    final body = _body.text.trim();
    if (body.isEmpty) {
      setState(() => _error = s.assignmentNeedsText);
      return;
    }
    int? start, end;
    if (_passage.text.trim().isNotEmpty) {
      final r = (await ref.read(referenceParserProvider.future)).parse(_passage.text);
      final book = r == null
          ? null
          : (await ref.read(refBooksProvider.future)).where((b) => b.code == r.bookCode).firstOrNull;
      if (r == null || book == null) {
        setState(() => _error = s.passageNotRecognized);
        return;
      }
      if (r.verse != null) {
        start = vkey(book.num, r.chapter, r.verse!);
        end = vkey(book.num, r.chapter, r.verseEnd ?? r.verse!);
      } else {
        // A whole chapter: from verse 1 to its last verse in the reader's version.
        final version = await ref.read(currentVersionProvider.future);
        final c = await ref.read(contentRepositoryProvider).chapter(version.id, book.code, r.chapter);
        start = vkey(book.num, r.chapter, 1);
        end = c?.verses.lastOrNull?.vkey ?? start;
      }
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final now = DateTime.now();
    if (!mounted) return;
    await _change(
      context,
      ref,
      widget.groupId,
      (g) => g.postAssignment(
        widget.groupId,
        body,
        vkeyStart: start,
        vkeyEnd: end,
        dueDate: _dueIn == 0 ? null : DateTime(now.year, now.month, now.day + _dueIn),
      ),
    );
    if (mounted) setState(() => _busy = false);
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextField(controller: _body, label: s.assignmentText, hint: s.assignmentHint, autofocus: true),
        const SizedBox(height: AppSpacing.md),
        AppTextField(controller: _passage, label: s.passageOptional, hint: 'ዮሐ 3፥16 · John 3', error: _error),
        AppListTile(
          leadingIcon: Icons.event_outlined,
          title: s.dueDate,
          subtitle: _dueLabel(s, _dueIn),
          chevron: true,
          onTap: () async {
            final v = await showOptionPicker<int>(
              context: context,
              title: s.dueDate,
              selected: _dueIn,
              options: [for (final d in _dueOptions) PickerOption(d, _dueLabel(s, d))],
            );
            if (v != null) setState(() => _dueIn = v);
          },
        ),
        const SizedBox(height: AppSpacing.sm),
        AppButton(label: s.postAssignment, loading: _busy, expand: true, onPressed: _busy ? null : _submit),
      ],
    );
  }
}

class _Plan extends ConsumerWidget {
  const _Plan({required this.detail});
  final GroupDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final d = detail;
    final g = d.group;
    final me = ref.watch(groupServiceProvider)?.userId;
    final plans = ref.watch(plansProvider).value ?? const <ReadingPlan>[];
    final plan = plans.where((p) => p.id == g.planId).firstOrNull;
    final lang = s.locale.languageCode;

    Future<void> choosePlan() async {
      final v = await showOptionPicker<String>(
        context: context,
        title: s.readingPlan,
        selected: g.planId,
        options: [for (final p in plans) PickerOption(p.id, p.nameFor(lang), subtitle: s.days(p.length))],
      );
      if (v != null && context.mounted) {
        final now = DateTime.now();
        await _change(context, ref, g.id, (svc) => svc.setPlan(g.id, v, DateTime(now.year, now.month, now.day)));
      }
    }

    if (plan == null || g.planStart == null) {
      return EmptyState(
        message: g.isTeacher ? s.chooseGroupPlan : s.noGroupPlan,
        icon: Icons.event_note_outlined,
        action: g.isTeacher ? AppButton.secondary(label: s.choosePlan, onPressed: choosePlan) : null,
      );
    }
    final mine = {
      for (final e in d.progress.entries)
        if (e.value.contains(me)) e.key,
    };
    final progress = PlanProgress(
      plan: plan,
      startedAt: g.planStart!,
      completed: mine,
      today: ref.watch(clockProvider)(),
    );
    final day = progress.scheduledDay;
    final doneToday = mine.contains(day);
    return AppListView(
      children: [
        AppCard(
          eyebrow: '${plan.nameFor(lang)} · ${s.dayOf(day, plan.length)}',
          actions: [
            doneToday
                ? AppButton.ghost(
                    label: s.doneLabel,
                    icon: Icons.check_circle,
                    size: AppButtonSize.sm,
                    onPressed: () => _change(context, ref, g.id, (svc) => svc.setDayDone(g.id, day, false)),
                  )
                : AppButton.secondary(
                    label: s.markDone,
                    size: AppButtonSize.sm,
                    onPressed: () => _change(context, ref, g.id, (svc) => svc.setDayDone(g.id, day, true)),
                  ),
          ],
          child: ReadingChips(readings: plan.readingsFor(day)),
        ),
        SectionHeader(s.groupProgress),
        for (final m in d.members)
          AppListTile(
            leadingIcon: (d.progress[day]?.contains(m.userId) ?? false) ? Icons.check_circle : Icons.circle_outlined,
            title: m.name,
            subtitle: s.daysRead(d.progress.values.where((users) => users.contains(m.userId)).length, plan.length),
          ),
        if (g.isTeacher)
          AppListTile(leadingIcon: Icons.swap_horiz, title: s.changePlan, chevron: true, onTap: choosePlan),
      ],
    );
  }
}

class _Members extends ConsumerWidget {
  const _Members({required this.detail});
  final GroupDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final d = detail;
    final g = d.group;
    final me = ref.watch(groupServiceProvider)?.userId;
    return AppListView(
      children: [
        AppCard(
          eyebrow: s.inviteCode,
          child: _InviteCode(groupId: g.id),
        ),
        SectionHeader('${s.members} (${d.members.length})'),
        for (final m in d.members)
          AppListTile(
            leading: MonogramAvatar(name: m.name, small: true),
            title: m.name,
            subtitle: m.isTeacher ? s.teacher : s.member,
            trailing: g.isTeacher && m.userId != me
                ? IconButton(
                    tooltip: s.manageMember,
                    icon: const Icon(Icons.more_vert),
                    onPressed: () async {
                      final action = await showOptionPicker<String>(
                        context: context,
                        title: m.name,
                        selected: null,
                        options: [
                          PickerOption(m.isTeacher ? 'member' : 'teacher', m.isTeacher ? s.makeMember : s.makeTeacher),
                          PickerOption('remove', s.removeFromGroup),
                        ],
                      );
                      if (action == null || !context.mounted) return;
                      await _change(
                        context,
                        ref,
                        g.id,
                        (svc) => action == 'remove'
                            ? svc.removeMember(g.id, m.userId)
                            : svc.setTeacher(g.id, m.userId, action == 'teacher'),
                      );
                    },
                  )
                : null,
          ),
      ],
    );
  }
}

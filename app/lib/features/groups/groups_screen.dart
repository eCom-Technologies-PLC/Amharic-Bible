import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/strings.dart';
import '../../data/groups.dart';
import '../../state/account.dart';
import '../../state/groups.dart';
import '../../ui/ui.dart';

String groupErrorText(S s, Object e) => switch (e) {
  GroupException(reason: 'notFound') => s.groupCodeNotFound,
  GroupException(reason: 'full') => s.groupFull,
  _ => s.loadError,
};

/// The signed-in user's study groups, with create and join.
class GroupsScreen extends ConsumerWidget {
  const GroupsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final service = ref.watch(groupServiceProvider);
    final email = ref.watch(accountEmailProvider).value;
    if (service == null) {
      return AppScaffold(
        title: s.studyGroups,
        body: EmptyState(message: s.accountsNotConfigured, icon: Icons.groups_outlined),
      );
    }
    if (email == null) {
      return AppScaffold(
        title: s.studyGroups,
        body: EmptyState(
          message: s.groupsSignIn,
          icon: Icons.groups_outlined,
          action: AppButton.secondary(label: s.signIn, onPressed: () => context.push('/me/account')),
        ),
      );
    }
    return AppScaffold(
      title: s.studyGroups,
      bottomBar: BottomActionBar(
        children: [
          AppButton(label: s.createGroup, icon: Icons.add, onPressed: () => _showGroupForm(context, ref, create: true)),
          AppButton.outline(
            label: s.joinGroup,
            icon: Icons.login,
            onPressed: () => _showGroupForm(context, ref, create: false),
          ),
        ],
      ),
      body: AsyncView(
        value: ref.watch(myGroupsProvider),
        onRetry: () => ref.invalidate(myGroupsProvider),
        data: (groups) => groups.isEmpty
            ? EmptyState(message: s.noGroups, icon: Icons.groups_outlined)
            : AppListView(
                children: [
                  for (final g in groups)
                    AppListTile(
                      leadingIcon: Icons.groups_outlined,
                      title: g.name,
                      subtitle: g.isTeacher ? s.teacher : s.member,
                      chevron: true,
                      onTap: () => context.push('/groups/${g.id}'),
                    ),
                ],
              ),
      ),
    );
  }
}

Future<void> _showGroupForm(BuildContext context, WidgetRef ref, {required bool create}) {
  final s = S.of(context);
  return showAppBottomSheet<void>(
    context: context,
    title: create ? s.createGroup : s.joinGroup,
    builder: (sheet) => _GroupForm(
      create: create,
      onDone: (id) {
        Navigator.of(sheet).pop();
        ref.invalidate(myGroupsProvider);
        context.push('/groups/$id');
      },
    ),
  );
}

class _GroupForm extends ConsumerStatefulWidget {
  const _GroupForm({required this.create, required this.onDone});

  final bool create;
  final ValueChanged<String> onDone;

  @override
  ConsumerState<_GroupForm> createState() => _GroupFormState();
}

class _GroupFormState extends ConsumerState<_GroupForm> {
  final _first = TextEditingController(); // group name, or invite code
  final _name = TextEditingController(); // the user's display name
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _first.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final s = S.of(context);
    final first = _first.text.trim(), name = _name.text.trim();
    if (first.isEmpty || name.isEmpty) {
      setState(() => _error = s.fillBothFields);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final service = ref.read(groupServiceProvider)!;
    try {
      final id = widget.create
          ? await service.create(name: first, displayName: name)
          : await service.join(code: first, displayName: name);
      widget.onDone(id);
    } catch (e) {
      if (mounted) setState(() => _error = groupErrorText(s, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextField(
          controller: _first,
          label: widget.create ? s.groupName : s.inviteCode,
          hint: widget.create ? s.groupNameHint : 'ABCD2345',
          autofocus: true,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          controller: _name,
          label: s.yourName,
          helper: s.yourNameHint,
          error: _error,
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: widget.create ? s.createGroup : s.joinGroup,
          loading: _busy,
          expand: true,
          onPressed: _busy ? null : _submit,
        ),
      ],
    );
  }
}

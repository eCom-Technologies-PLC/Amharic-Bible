import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/strings.dart';
import '../../data/sync/account_service.dart';
import '../../data/sync/sync_engine.dart';
import '../../state/account.dart';
import '../../state/providers.dart';
import '../../ui/ui.dart';
import '../common.dart';

/// Optional sign-in (email one-time code), sync status, export and account
/// deletion.
class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  bool _codeSent = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    final invalidCode = S.of(context).invalidCode;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on InvalidCode {
      _error = invalidCode;
    } catch (e) {
      _error = '$e';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _export() async {
    final json = await exportUserData(ref.read(userDbProvider));
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, 'amharic-bible-data.json'));
    await file.writeAsString(json);
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path, mimeType: 'application/json')]));
  }

  Future<void> _confirmDelete(AccountService service) async {
    final s = S.of(context);
    final ok = await showConfirmDialog(
      context: context,
      title: s.deleteAccount,
      message: s.deleteAccountConfirm,
      confirmLabel: s.delete,
      cancelLabel: s.cancel,
      destructive: true,
    );
    if (ok) await _run(service.deleteAccount);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final service = ref.watch(accountServiceProvider);
    final email = ref.watch(accountEmailProvider).value;

    return AppScaffold(
      title: s.account,
      body: AppListView(
        children: [
          Gutter(
            vertical: AppSpacing.sm,
            child: Text(s.accountOptional, style: context.text.bodyMedium),
          ),
          if (service == null)
            AppListTile(leadingIcon: Icons.cloud_off_outlined, title: s.accountsNotConfigured)
          else if (email == null)
            Gutter(vertical: AppSpacing.sm, child: _signInForm(s, service))
          else
            ..._signedIn(s, service, email),
          if (_error != null && !_codeSent)
            Gutter(
              child: Text(_error!, style: context.text.bodySmall?.copyWith(color: context.colors.error)),
            ),
          const SizedBox(height: AppSpacing.lg),
          const Divider(),
          AppListTile(leadingIcon: Icons.file_download_outlined, title: s.exportData, chevron: true, onTap: _export),
        ],
      ),
    );
  }

  Widget _signInForm(S s, AccountService service) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      AppTextField(
        controller: _email,
        label: s.email,
        enabled: !_codeSent,
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.send,
        autofillHints: const [AutofillHints.email],
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: AppSpacing.lg),
      if (!_codeSent)
        AppButton(
          label: s.sendCode,
          expand: true,
          loading: _busy,
          onPressed: !_email.text.contains('@')
              ? null
              : () => _run(() async {
                  await service.sendCode(_email.text);
                  _codeSent = true;
                }),
        )
      else ...[
        AppTextField(
          controller: _code,
          label: s.enterCode,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.oneTimeCode],
          maxLength: 8,
          autofocus: true,
          error: _error,
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            AppButton.ghost(label: s.cancel, onPressed: _busy ? null : () => setState(() => _codeSent = false)),
            const Spacer(),
            AppButton(
              label: s.verify,
              loading: _busy,
              onPressed: () => _run(() async {
                await service.verifyCode(_email.text, _code.text);
                // Start from the email step next time (after sign-out).
                _codeSent = false;
                _code.clear();
              }),
            ),
          ],
        ),
      ],
    ],
  );

  List<Widget> _signedIn(S s, AccountService service, String email) {
    final sync = ref.watch(syncControllerProvider);
    final settings = ref.watch(settingsProvider);
    final last = sync.lastSyncedAt;
    final when = last == null
        ? s.never
        : '${formatDate(last, settings, s)} ${last.hour.toString().padLeft(2, '0')}:${last.minute.toString().padLeft(2, '0')}';
    return [
      AppListTile(leadingIcon: Icons.account_circle_outlined, title: s.signedInAs(email)),
      AppListTile(
        leading: sync.busy
            ? const InlineSpinner(size: AppIconSize.md)
            : Icon(
                sync.failed ? Icons.sync_problem : Icons.cloud_done_outlined,
                color: sync.failed ? context.colors.error : context.appColors.success,
              ),
        title: sync.busy ? s.syncing : (sync.failed ? s.syncFailed : s.lastSynced),
        subtitle: sync.busy ? null : when,
        trailing: AppButton.ghost(
          label: s.syncNow,
          size: AppButtonSize.sm,
          onPressed: sync.busy ? null : () => ref.read(syncControllerProvider.notifier).sync(),
        ),
      ),
      Gutter(
        vertical: AppSpacing.sm,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppButton.outline(label: s.signOut, expand: true, onPressed: _busy ? null : () => _run(service.signOut)),
            const SizedBox(height: AppSpacing.sm),
            AppButton.ghost(
              label: s.deleteAccount,
              expand: true,
              onPressed: _busy ? null : () => _confirmDelete(service),
            ),
          ],
        ),
      ),
    ];
  }
}

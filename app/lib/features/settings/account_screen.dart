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
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.deleteAccount),
        content: Text(s.deleteAccountConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(s.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: Text(s.delete),
          ),
        ],
      ),
    );
    if (ok == true) await _run(service.deleteAccount);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final service = ref.watch(accountServiceProvider);
    final email = ref.watch(accountEmailProvider).value;
    final t = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text(s.account)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(s.accountOptional, style: t.bodyMedium),
          const SizedBox(height: 16),
          if (service == null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.cloud_off_outlined),
              title: Text(s.accountsNotConfigured),
            )
          else if (email == null)
            ..._signInForm(s, service)
          else
            ..._signedIn(s, service, email),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          const Divider(height: 32),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.file_download_outlined),
            title: Text(s.exportData),
            onTap: _export,
          ),
        ],
      ),
    );
  }

  List<Widget> _signInForm(S s, AccountService service) => [
    TextField(
      controller: _email,
      enabled: !_codeSent,
      keyboardType: TextInputType.emailAddress,
      onChanged: (_) => setState(() {}),
      autofillHints: const [AutofillHints.email],
      decoration: InputDecoration(labelText: s.email, border: const OutlineInputBorder()),
    ),
    const SizedBox(height: 12),
    if (!_codeSent)
      FilledButton(
        onPressed: _busy || !_email.text.contains('@')
            ? null
            : () => _run(() async {
                await service.sendCode(_email.text);
                _codeSent = true;
              }),
        child: Text(s.sendCode),
      )
    else ...[
      Text(s.enterCode),
      const SizedBox(height: 8),
      TextField(
        controller: _code,
        keyboardType: TextInputType.number,
        autofillHints: const [AutofillHints.oneTimeCode],
        maxLength: 8,
        decoration: const InputDecoration(border: OutlineInputBorder()),
      ),
      Row(
        children: [
          TextButton(onPressed: _busy ? null : () => setState(() => _codeSent = false), child: Text(s.cancel)),
          const Spacer(),
          FilledButton(
            onPressed: _busy
                ? null
                : () => _run(() async {
                    await service.verifyCode(_email.text, _code.text);
                    // Start from the email step next time (after sign-out).
                    _codeSent = false;
                    _code.clear();
                  }),
            child: Text(s.verify),
          ),
        ],
      ),
    ],
  ];

  List<Widget> _signedIn(S s, AccountService service, String email) {
    final sync = ref.watch(syncControllerProvider);
    final settings = ref.watch(settingsProvider);
    final last = sync.lastSyncedAt;
    return [
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.account_circle_outlined),
        title: Text(s.signedInAs(email)),
      ),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: sync.busy
            ? const SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 2))
            : Icon(sync.failed ? Icons.sync_problem : Icons.cloud_done_outlined),
        title: Text(sync.busy ? s.syncing : (sync.failed ? s.syncFailed : s.lastSynced)),
        subtitle: sync.busy || last == null
            ? (last == null && !sync.busy ? Text(s.never) : null)
            : Text(
                '${formatDate(last, settings, s)} ${last.hour.toString().padLeft(2, '0')}:${last.minute.toString().padLeft(2, '0')}',
              ),
        trailing: TextButton(
          onPressed: sync.busy ? null : () => ref.read(syncControllerProvider.notifier).sync(),
          child: Text(s.syncNow),
        ),
      ),
      const SizedBox(height: 8),
      OutlinedButton(onPressed: _busy ? null : () => _run(service.signOut), child: Text(s.signOut)),
      const SizedBox(height: 8),
      TextButton(
        style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
        onPressed: _busy ? null : () => _confirmDelete(service),
        child: Text(s.deleteAccount),
      ),
    ];
  }
}

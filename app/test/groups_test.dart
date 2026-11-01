import 'dart:io';

import 'package:amharic_bible/app.dart';
import 'package:amharic_bible/data/audio_repository.dart';
import 'package:amharic_bible/data/groups.dart';
import 'package:amharic_bible/state/account.dart';
import 'package:amharic_bible/state/groups.dart';
import 'package:amharic_bible/state/providers.dart';
import 'package:amharic_bible/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'fakes.dart';
import 'helpers.dart';

/// In-memory groups with the same rules as the SQL functions, for widget tests.
class FakeGroups implements GroupService {
  FakeGroups(this.userId);

  @override
  String userId;
  final groups = <String, StudyGroup>{};
  final members = <String, List<GroupMember>>{};
  final posts = <String, List<GroupPost>>{};
  final done = <String, Set<String>>{};
  final progress = <String, Map<int, Set<String>>>{};
  var _n = 0;

  bool _teacher(String gid) => members[gid]!.any((m) => m.userId == userId && m.isTeacher);

  @override
  Future<List<StudyGroup>> myGroups() async => [
    for (final g in groups.values)
      if (members[g.id]!.any((m) => m.userId == userId)) _as(g),
  ];

  StudyGroup _as(StudyGroup g) => StudyGroup(
    id: g.id,
    name: g.name,
    inviteCode: g.inviteCode,
    isTeacher: _teacher(g.id),
    planId: g.planId,
    planStart: g.planStart,
  );

  @override
  Future<GroupDetail> detail(String groupId) async => GroupDetail(
    group: _as(groups[groupId]!),
    members: members[groupId]!,
    posts: posts[groupId]!.reversed.toList(),
    doneBy: done,
    progress: progress[groupId] ?? {},
  );

  @override
  Future<String> create({
    required String name,
    required String displayName,
    String? planId,
    DateTime? planStart,
  }) async {
    final id = 'g${_n++}';
    groups[id] = StudyGroup(id: id, name: name, inviteCode: 'ABCD234$_n', isTeacher: true);
    members[id] = [GroupMember(userId: userId, name: displayName, isTeacher: true)];
    posts[id] = [];
    return id;
  }

  @override
  Future<String> join({required String code, required String displayName}) async {
    final g = groups.values.where((g) => g.inviteCode == code.toUpperCase()).firstOrNull;
    if (g == null) throw const GroupException('notFound');
    members[g.id]!.add(GroupMember(userId: userId, name: displayName, isTeacher: false));
    return g.id;
  }

  @override
  Future<void> leave(String groupId) async => members[groupId]!.removeWhere((m) => m.userId == userId);

  @override
  Future<void> postMessage(String groupId, String body, {int? vkeyStart, int? vkeyEnd, int? day}) async =>
      posts[groupId]!.add(
        GroupPost(id: 'p${_n++}', userId: userId, isAssignment: false, body: body, createdAt: DateTime(2026, 11, 2)),
      );

  @override
  Future<void> postAssignment(String groupId, String body, {int? vkeyStart, int? vkeyEnd, DateTime? dueDate}) async {
    if (!_teacher(groupId)) throw const GroupException('failed');
    posts[groupId]!.add(
      GroupPost(
        id: 'p${_n++}',
        userId: userId,
        isAssignment: true,
        body: body,
        createdAt: DateTime(2026, 11, 2),
        vkeyStart: vkeyStart,
        vkeyEnd: vkeyEnd,
        dueDate: dueDate,
      ),
    );
  }

  @override
  Future<void> deletePost(String postId) async {
    for (final l in posts.values) {
      l.removeWhere((p) => p.id == postId);
    }
  }

  @override
  Future<void> setAssignmentDone(String postId, bool isDone) async =>
      isDone ? (done[postId] ??= {}).add(userId) : done[postId]?.remove(userId);

  @override
  Future<void> setDayDone(String groupId, int day, bool isDone) async {
    final days = progress[groupId] ??= {};
    isDone ? (days[day] ??= {}).add(userId) : days[day]?.remove(userId);
  }

  @override
  Future<void> setPlan(String groupId, String? planId, DateTime? planStart) async {
    final g = groups[groupId]!;
    groups[groupId] = StudyGroup(
      id: g.id,
      name: g.name,
      inviteCode: g.inviteCode,
      isTeacher: g.isTeacher,
      planId: planId,
      planStart: planStart,
    );
    progress.remove(groupId);
  }

  @override
  Future<String> newInviteCode(String groupId) async => 'NEWCODE2';

  @override
  Future<void> setTeacher(String groupId, String userId, bool teacher) async {}

  @override
  Future<void> removeMember(String groupId, String userId) async =>
      members[groupId]!.removeWhere((m) => m.userId == userId);
}

/// The tabs scroll sideways on small screens; bring one into view, then open it.
Future<void> openTab(WidgetTester tester, String label) async {
  final tab = find.descendant(of: find.byType(TabBar), matching: find.text(label));
  await tester.ensureVisible(tab);
  await tester.pumpAndSettle();
  await tester.tap(tab);
  await tester.pumpAndSettle();
}

void main() {
  late Database contentDb, userDb;

  setUp(() async {
    (rootBundle as CachingAssetBundle).clear();
    contentDb = await openSampleContentDb();
    userDb = await openTestUserDb();
  });

  Future<void> pump(
    WidgetTester tester, {
    GroupService? groups,
    bool signedIn = true,
    String initial = '/me/groups',
  }) async {
    final account = FakeAccountService(FakeServer());
    if (signedIn) await account.verifyCode('t@example.com', '123456');
    // Small phone with large text: any overflow fails the test.
    tester.view.physicalSize = const Size(640, 1280);
    tester.view.devicePixelRatio = 2;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(() {
      tester.view.reset();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          contentDbProvider.overrideWithValue(contentDb),
          userDbProvider.overrideWithValue(userDb),
          initialSettingsProvider.overrideWithValue(const Settings(languageCode: 'en', versionId: 'WEB')),
          accountServiceProvider.overrideWithValue(account),
          groupServiceProvider.overrideWithValue(groups),
          audioRepositoryProvider.overrideWithValue(AudioRepository(baseUrl: '', storageDir: Directory.systemTemp)),
          routerProvider.overrideWithValue(buildRouter(initialLocation: initial)),
        ],
        child: const AmharicBibleApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('without accounts or sign-in, groups explain what is needed', (tester) async {
    await pump(tester);
    expect(find.textContaining('not set up'), findsWidgets); // no group service in this build
    await pump(tester, groups: FakeGroups('t'), signedIn: false);
    expect(find.text('Sign in to use study groups.'), findsOneWidget);
  });

  testWidgets('a teacher creates a group, discusses, assigns, and sets the plan', (tester) async {
    final groups = FakeGroups('teacher');
    await pump(tester, groups: groups);
    expect(find.textContaining('not in a group yet'), findsOneWidget);
    await tester.tap(find.text('Create group'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Youth study');
    await tester.enterText(find.byType(TextField).at(1), 'Pastor Abebe');
    await tester.tap(find.widgetWithText(AppButton, 'Create group').last);
    await tester.pumpAndSettle();

    // Discussion
    expect(find.text('Youth study'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Welcome, everyone!');
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome, everyone!'), findsOneWidget);
    expect(find.textContaining('Pastor Abebe ·'), findsOneWidget);

    // Assignments
    await openTab(tester, 'Assignments');
    await tester.pumpAndSettle();
    await tester.tap(find.text('New assignment'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Read and write one prayer.');
    await tester.enterText(find.byType(TextField).at(1), 'John 3:16');
    await tester.tap(find.text('Post assignment'));
    await tester.pumpAndSettle();
    expect(find.text('Read and write one prayer.'), findsOneWidget);
    expect(find.text('John 3:16'), findsOneWidget);
    expect(find.text('0 of 1 done'), findsOneWidget);
    await tester.tap(find.text('Mark done'));
    await tester.pumpAndSettle();
    expect(find.text('1 of 1 done'), findsOneWidget);

    // Plan
    await openTab(tester, 'Reading plan');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose a plan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('The Gospels in 30 days'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Day 1 of 30'), findsOneWidget);
    expect(find.text('0 of 30 days read'), findsOneWidget);
    await tester.tap(find.text('Mark done'));
    await tester.pumpAndSettle();
    expect(find.text('1 of 30 days read'), findsOneWidget);

    // Members
    await openTab(tester, 'Members');
    await tester.pumpAndSettle();
    expect(find.text('ABCD2341'), findsOneWidget);
    expect(find.text('Teacher'), findsOneWidget);
  });

  testWidgets('a member joins with a code and cannot give assignments', (tester) async {
    final groups = FakeGroups('teacher');
    final gid = await groups.create(name: 'Youth study', displayName: 'Pastor Abebe');
    groups.userId = 'member';
    await pump(tester, groups: groups);
    await tester.tap(find.text('Join with a code'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'WRONG123');
    await tester.enterText(find.byType(TextField).at(1), 'Hanna');
    await tester.tap(find.widgetWithText(AppButton, 'Join with a code').last);
    await tester.pumpAndSettle();
    expect(find.text('No group has this code.'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(0), groups.groups[gid]!.inviteCode.toLowerCase());
    await tester.tap(find.widgetWithText(AppButton, 'Join with a code').last);
    await tester.pumpAndSettle();
    expect(find.text('Youth study'), findsOneWidget);
    await openTab(tester, 'Assignments');
    await tester.pumpAndSettle();
    expect(find.text('New assignment'), findsNothing);
    await openTab(tester, 'Reading plan');
    await tester.pumpAndSettle();
    expect(find.text('The teacher has not chosen a reading plan yet.'), findsOneWidget);
  });
}

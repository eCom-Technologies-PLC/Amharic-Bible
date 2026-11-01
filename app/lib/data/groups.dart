import 'package:supabase_flutter/supabase_flutter.dart';

/// Study groups (server/supabase/migrations/20261102000000_study_groups.sql):
/// people read a plan together, discuss it, and a teacher can give assignments.
class StudyGroup {
  const StudyGroup({
    required this.id,
    required this.name,
    required this.inviteCode,
    required this.isTeacher,
    this.planId,
    this.planStart,
  });

  final String id;
  final String name;
  final String inviteCode;
  final bool isTeacher; // the signed-in user's role
  final String? planId;
  final DateTime? planStart;
}

class GroupMember {
  const GroupMember({required this.userId, required this.name, required this.isTeacher});
  final String userId;
  final String name;
  final bool isTeacher;
}

class GroupPost {
  const GroupPost({
    required this.id,
    required this.userId,
    required this.isAssignment,
    required this.body,
    required this.createdAt,
    this.vkeyStart,
    this.vkeyEnd,
    this.day,
    this.dueDate,
  });

  final String id;
  final String userId;
  final bool isAssignment;
  final String body;
  final DateTime createdAt;
  final int? vkeyStart;
  final int? vkeyEnd;
  final int? day; // the plan day a message is about
  final DateTime? dueDate;
}

/// Everything the group screen shows.
class GroupDetail {
  const GroupDetail({
    required this.group,
    required this.members,
    required this.posts,
    required this.doneBy,
    required this.progress,
  });

  final StudyGroup group;
  final List<GroupMember> members;
  final List<GroupPost> posts; // newest first
  final Map<String, Set<String>> doneBy; // assignment id -> user ids who finished it
  final Map<int, Set<String>> progress; // plan day -> user ids who read it

  String nameOf(String userId) => members.where((m) => m.userId == userId).firstOrNull?.name ?? '—';
}

class GroupException implements Exception {
  const GroupException(this.reason);
  final String reason; // notFound | full | failed
}

abstract interface class GroupService {
  /// The signed-in user's id, or null.
  String? get userId;

  Future<List<StudyGroup>> myGroups();
  Future<GroupDetail> detail(String groupId);
  Future<String> create({required String name, required String displayName, String? planId, DateTime? planStart});
  Future<String> join({required String code, required String displayName});
  Future<void> leave(String groupId);
  Future<void> postMessage(String groupId, String body, {int? vkeyStart, int? vkeyEnd, int? day});
  Future<void> postAssignment(String groupId, String body, {int? vkeyStart, int? vkeyEnd, DateTime? dueDate});
  Future<void> deletePost(String postId);
  Future<void> setAssignmentDone(String postId, bool done);
  Future<void> setDayDone(String groupId, int day, bool done);
  Future<void> setPlan(String groupId, String? planId, DateTime? planStart);
  Future<String> newInviteCode(String groupId);
  Future<void> setTeacher(String groupId, String userId, bool teacher);
  Future<void> removeMember(String groupId, String userId);
}

String _date(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Groups rows' user_id by [key]: {key value -> user ids}.
Map<K, Set<String>> _usersBy<K>(List<Map<String, dynamic>> rows, String key) {
  final out = <K, Set<String>>{};
  for (final r in rows) {
    (out[r[key] as K] ??= {}).add(r['user_id'] as String);
  }
  return out;
}

DateTime? _parseDate(Object? v) => v == null ? null : DateTime.parse(v as String);

/// [GroupService] on Supabase: reads through row-level security, writes
/// through the migration's functions.
class SupabaseGroupService implements GroupService {
  SupabaseGroupService(this.client);

  final SupabaseClient client;

  @override
  String? get userId => client.auth.currentUser?.id;

  Future<T> _call<T>(Future<T> Function() f) async {
    try {
      return await f();
    } on PostgrestException catch (e) {
      throw GroupException(switch (e.code) {
        'P0002' => 'notFound',
        '54000' => 'full',
        _ => 'failed',
      });
    }
  }

  static StudyGroup _group(Map<String, dynamic> g, bool teacher) => StudyGroup(
    id: g['id'] as String,
    name: g['name'] as String,
    inviteCode: g['invite_code'] as String,
    isTeacher: teacher,
    planId: g['plan_id'] as String?,
    planStart: _parseDate(g['plan_start']),
  );

  @override
  Future<List<StudyGroup>> myGroups() => _call(() async {
    final rows = await client.from('group_members').select('role, study_groups(*)').eq('user_id', userId!);
    return [for (final r in rows) _group(r['study_groups'] as Map<String, dynamic>, r['role'] == 'teacher')]
      ..sort((a, b) => a.name.compareTo(b.name));
  });

  @override
  Future<GroupDetail> detail(String groupId) => _call(() async {
    final g = await client.from('study_groups').select().eq('id', groupId).single();
    final members = await client.from('group_members').select().eq('group_id', groupId).order('joined_at');
    final posts = await client
        .from('group_posts')
        .select()
        .eq('group_id', groupId)
        .order('created_at', ascending: false)
        .limit(300);
    final assignmentIds = [
      for (final p in posts)
        if (p['kind'] == 'assignment') p['id'],
    ];
    final done = assignmentIds.isEmpty
        ? const <Map<String, dynamic>>[]
        : await client.from('assignment_done').select().inFilter('post_id', assignmentIds);
    final progress = await client.from('group_progress').select().eq('group_id', groupId);
    final me = members.where((m) => m['user_id'] == userId).firstOrNull;
    return GroupDetail(
      group: _group(g, me?['role'] == 'teacher'),
      members: [
        for (final m in members)
          GroupMember(
            userId: m['user_id'] as String,
            name: m['display_name'] as String,
            isTeacher: m['role'] == 'teacher',
          ),
      ],
      posts: [
        for (final p in posts)
          GroupPost(
            id: p['id'] as String,
            userId: p['user_id'] as String,
            isAssignment: p['kind'] == 'assignment',
            body: p['body'] as String,
            createdAt: DateTime.parse(p['created_at'] as String),
            vkeyStart: p['vkey_start'] as int?,
            vkeyEnd: p['vkey_end'] as int?,
            day: p['day'] as int?,
            dueDate: _parseDate(p['due_date']),
          ),
      ],
      doneBy: _usersBy<String>(done, 'post_id'),
      progress: _usersBy<int>(progress, 'day'),
    );
  });

  @override
  Future<String> create({required String name, required String displayName, String? planId, DateTime? planStart}) =>
      _call(() async {
        final r = await client.rpc<Map<String, dynamic>>(
          'create_group',
          params: {
            'name': name,
            'display_name': displayName,
            'plan_id': planId,
            'plan_start': planStart == null ? null : _date(planStart),
          },
        );
        return r['id'] as String;
      });

  @override
  Future<String> join({required String code, required String displayName}) =>
      _call(() => client.rpc<String>('join_group', params: {'code': code, 'display_name': displayName}));

  @override
  Future<void> leave(String groupId) => _call(() => client.rpc<void>('leave_group', params: {'gid': groupId}));

  @override
  Future<void> postMessage(String groupId, String body, {int? vkeyStart, int? vkeyEnd, int? day}) => _call(
    () => client.rpc<String>(
      'post_message',
      params: {'gid': groupId, 'body': body, 'vkey_start': vkeyStart, 'vkey_end': vkeyEnd, 'day': day},
    ),
  );

  @override
  Future<void> postAssignment(String groupId, String body, {int? vkeyStart, int? vkeyEnd, DateTime? dueDate}) => _call(
    () => client.rpc<String>(
      'post_assignment',
      params: {
        'gid': groupId,
        'body': body,
        'vkey_start': vkeyStart,
        'vkey_end': vkeyEnd,
        'due_date': dueDate == null ? null : _date(dueDate),
      },
    ),
  );

  @override
  Future<void> deletePost(String postId) => _call(() => client.rpc<void>('delete_post', params: {'pid': postId}));

  @override
  Future<void> setAssignmentDone(String postId, bool done) =>
      _call(() => client.rpc<void>('set_assignment_done', params: {'pid': postId, 'done': done}));

  @override
  Future<void> setDayDone(String groupId, int day, bool done) =>
      _call(() => client.rpc<void>('set_group_day', params: {'gid': groupId, 'day': day, 'done': done}));

  @override
  Future<void> setPlan(String groupId, String? planId, DateTime? planStart) => _call(
    () => client.rpc<void>(
      'set_group_plan',
      params: {'gid': groupId, 'plan_id': planId, 'plan_start': planStart == null ? null : _date(planStart)},
    ),
  );

  @override
  Future<String> newInviteCode(String groupId) =>
      _call(() => client.rpc<String>('new_invite_code', params: {'gid': groupId}));

  @override
  Future<void> setTeacher(String groupId, String userId, bool teacher) => _call(
    () => client.rpc<void>(
      'set_member_role',
      params: {'gid': groupId, 'member': userId, 'new_role': teacher ? 'teacher' : 'member'},
    ),
  );

  @override
  Future<void> removeMember(String groupId, String userId) =>
      _call(() => client.rpc<void>('remove_member', params: {'gid': groupId, 'member': userId}));
}

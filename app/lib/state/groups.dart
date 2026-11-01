import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/groups.dart';
import 'account.dart';

/// Null when the app was built without accounts (main() overrides this).
final groupServiceProvider = Provider<GroupService?>((ref) => null);

/// The signed-in user's groups; empty when signed out.
final myGroupsProvider = FutureProvider<List<StudyGroup>>((ref) async {
  final service = ref.watch(groupServiceProvider);
  final email = await ref.watch(accountEmailProvider.future);
  if (service == null || email == null) return const [];
  return service.myGroups();
});

final groupDetailProvider = FutureProvider.family<GroupDetail, String>(
  (ref, id) => ref.watch(groupServiceProvider)!.detail(id),
);

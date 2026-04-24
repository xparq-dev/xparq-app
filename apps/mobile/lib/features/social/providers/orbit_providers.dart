import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xparq_app/features/auth/providers/auth_providers.dart';
import 'package:xparq_app/features/auth/models/planet_model.dart';
import 'package:xparq_app/features/social/repositories/orbit_repository.dart';

final orbitRepositoryProvider = Provider<OrbitRepository>((ref) {
  return OrbitRepository();
});

/// Stream of UID -> Status (pending, accepted) that the current user is orbiting.
final myOrbitingStatusProvider = StreamProvider<Map<String, String>>((ref) {
  final user = ref.watch(supabaseAuthStateProvider).valueOrNull;
  if (user == null) return Stream.value({});

  return ref.watch(orbitRepositoryProvider).watchOrbitingStatus(user.id);
});

/// Stream of incoming orbit requests (UIDs).
final incomingRequestsProvider = StreamProvider<List<String>>((ref) {
  final user = ref.watch(supabaseAuthStateProvider).valueOrNull;
  if (user == null) return Stream.value([]);

  return ref.watch(orbitRepositoryProvider).watchIncomingRequests(user.id);
});

class OrbitListParams {
  final String uid;
  final String collection;
  OrbitListParams(this.uid, this.collection);

  @override
  bool operator ==(Object other) =>
      other is OrbitListParams &&
      other.uid == uid &&
      other.collection == collection;

  @override
  int get hashCode => Object.hash(uid, collection);
}

final orbitListProvider =
    StreamProvider.family<List<PlanetModel>, OrbitListParams>((ref, params) {
      return ref
          .watch(orbitRepositoryProvider)
          .watchOrbitSubcollection(params.uid, params.collection)
          .asyncMap((uids) async {
            final authRepo = ref.read(authRepositoryProvider);
            final List<PlanetModel> profiles = [];
            for (final uid in uids) {
              final data = await authRepo.fetchPlanetProfile(uid);
              if (data != null) {
                profiles.add(PlanetModel.fromMap(data, uid));
              }
            }
            return profiles;
          });
    });

final orbitCountProvider = StreamProvider.family<int, OrbitListParams>((
  ref,
  params,
) {
  return ref
      .watch(orbitRepositoryProvider)
      .watchOrbitSubcollection(params.uid, params.collection)
      .map((list) => list.length);
});

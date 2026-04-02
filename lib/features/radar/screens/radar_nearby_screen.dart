import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xparq_app/features/radar/providers/radar_provider.dart';
import 'package:xparq_app/features/radar/widgets/nearby_user_tile.dart';

class RadarNearbyScreen extends ConsumerStatefulWidget {
  const RadarNearbyScreen({super.key, this.currentUserId, this.radiusKm = 5});

  final String? currentUserId;
  final double radiusKm;

  @override
  ConsumerState<RadarNearbyScreen> createState() => _RadarNearbyScreenState();
}

class _RadarNearbyScreenState extends ConsumerState<RadarNearbyScreen> {
  late final RadarRequest _request;

  @override
  void initState() {
    super.initState();
    _request = RadarRequest(
      currentUserId: widget.currentUserId,
      radiusKm: widget.radiusKm,
    );

    Future.microtask(() {
      ref.read(radarProvider(_request).notifier).fetchNearby();
    });
  }

  Future<void> _refresh() async {
    await ref.read(radarProvider(_request).notifier).fetchNearby();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<RadarNearbyState>(radarProvider(_request), (previous, next) {
      if (previous?.errorMessage == next.errorMessage ||
          next.errorMessage == null) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(next.errorMessage!)));
    });

    final state = ref.watch(radarProvider(_request));

    return Scaffold(
      appBar: AppBar(
        title: Text('Nearby Radar (${widget.radiusKm.toStringAsFixed(0)} km)'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: state.isLoading
              ? ListView(
                  children: [
                    SizedBox(height: 220),
                    Center(child: CircularProgressIndicator()),
                  ],
                )
              : state.users.isEmpty
              ? ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    SizedBox(height: 160),
                    Center(
                      child: Text(
                        'No nearby users found.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: state.users.length,
                  itemBuilder: (context, index) {
                    final user = state.users[index];
                    return NearbyUserTile(user: user);
                  },
                ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: state.isLoading ? null : _refresh,
        icon: const Icon(Icons.radar),
        label: const Text('Scan'),
      ),
    );
  }
}

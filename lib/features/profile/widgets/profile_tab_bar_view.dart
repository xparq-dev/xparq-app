// lib/features/profile/widgets/profile_tab_bar_view.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xparq_app/features/auth/models/planet_model.dart';
import 'package:xparq_app/features/auth/providers/auth_providers.dart';
import 'package:xparq_app/features/profile/widgets/about_tab.dart';
import 'package:xparq_app/features/profile/widgets/pulse_list_tab.dart';
import 'package:xparq_app/features/profile/widgets/warp_list_tab.dart';

class ProfileTabBarView extends ConsumerWidget {
  final PlanetModel profile;

  const ProfileTabBarView({super.key, required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(supabaseAuthStateProvider).valueOrNull;
    final isOwnProfile = profile.id == currentUser?.id;

    return TabBarView(
      children: [
        AboutTab(profile: profile, isOwnProfile: isOwnProfile),
        PulseListTab(uid: profile.id),
        WarpListTab(uid: profile.id),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xparq_app/features/profile/models/user_model.dart';
import 'package:xparq_app/features/profile/providers/profile_provider.dart';
import 'package:xparq_app/features/profile/widgets/profile_form.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key, required this.userId});

  final String userId;

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _bioController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _bioController = TextEditingController();

    Future.microtask(() {
      ref.read(profileProvider(widget.userId).notifier).load(id: widget.userId);
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  void _applyUser(UserModel? user) {
    if (user == null) {
      return;
    }

    if (_nameController.text != user.name) {
      _nameController.text = user.name;
    }

    if (_bioController.text != user.bio) {
      _bioController.text = user.bio;
    }
  }

  Future<void> _updateProfile() async {
    FocusScope.of(context).unfocus();

    await ref
        .read(profileProvider(widget.userId).notifier)
        .update(
          id: widget.userId,
          name: _nameController.text,
          bio: _bioController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<ProfileState>(profileProvider(widget.userId), (previous, next) {
      _applyUser(next.user);

      if (previous?.errorMessage != next.errorMessage &&
          next.errorMessage != null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(next.errorMessage!)));
      }

      if (previous?.successMessage != next.successMessage &&
          next.successMessage != null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(next.successMessage!)));
      }
    });

    final state = ref.watch(profileProvider(widget.userId));
    _applyUser(state.user);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: SafeArea(
          child: state.isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: ProfileForm(
                        nameController: _nameController,
                        bioController: _bioController,
                        isLoading: state.isUpdating,
                        onSave: _updateProfile,
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

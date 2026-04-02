// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'connectivity_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$connectivityNotifierHash() =>
    r'23e5d6298833309679f706e4b6a9edfaa68aaf74';

/// See also [ConnectivityNotifier].
@ProviderFor(ConnectivityNotifier)
final connectivityNotifierProvider =
    AutoDisposeStreamNotifierProvider<
      ConnectivityNotifier,
      List<ConnectivityResult>
    >.internal(
      ConnectivityNotifier.new,
      name: r'connectivityNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$connectivityNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$ConnectivityNotifier =
    AutoDisposeStreamNotifier<List<ConnectivityResult>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package

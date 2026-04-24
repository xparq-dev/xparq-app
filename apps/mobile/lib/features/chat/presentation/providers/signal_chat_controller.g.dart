// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'signal_chat_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$signalChatControllerHash() =>
    r'db9ce9a79f2f718e7161be1ebc2d23c8de7b7b47';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

abstract class _$SignalChatController
    extends BuildlessAutoDisposeNotifier<SignalChatState> {
  late final String chatId;

  SignalChatState build(
    String chatId,
  );
}

/// See also [SignalChatController].
@ProviderFor(SignalChatController)
const signalChatControllerProvider = SignalChatControllerFamily();

/// See also [SignalChatController].
class SignalChatControllerFamily extends Family<SignalChatState> {
  /// See also [SignalChatController].
  const SignalChatControllerFamily();

  /// See also [SignalChatController].
  SignalChatControllerProvider call(
    String chatId,
  ) {
    return SignalChatControllerProvider(
      chatId,
    );
  }

  @override
  SignalChatControllerProvider getProviderOverride(
    covariant SignalChatControllerProvider provider,
  ) {
    return call(
      provider.chatId,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'signalChatControllerProvider';
}

/// See also [SignalChatController].
class SignalChatControllerProvider extends AutoDisposeNotifierProviderImpl<
    SignalChatController, SignalChatState> {
  /// See also [SignalChatController].
  SignalChatControllerProvider(
    String chatId,
  ) : this._internal(
          () => SignalChatController()..chatId = chatId,
          from: signalChatControllerProvider,
          name: r'signalChatControllerProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$signalChatControllerHash,
          dependencies: SignalChatControllerFamily._dependencies,
          allTransitiveDependencies:
              SignalChatControllerFamily._allTransitiveDependencies,
          chatId: chatId,
        );

  SignalChatControllerProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.chatId,
  }) : super.internal();

  final String chatId;

  @override
  SignalChatState runNotifierBuild(
    covariant SignalChatController notifier,
  ) {
    return notifier.build(
      chatId,
    );
  }

  @override
  Override overrideWith(SignalChatController Function() create) {
    return ProviderOverride(
      origin: this,
      override: SignalChatControllerProvider._internal(
        () => create()..chatId = chatId,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        chatId: chatId,
      ),
    );
  }

  @override
  AutoDisposeNotifierProviderElement<SignalChatController, SignalChatState>
      createElement() {
    return _SignalChatControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is SignalChatControllerProvider && other.chatId == chatId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, chatId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin SignalChatControllerRef
    on AutoDisposeNotifierProviderRef<SignalChatState> {
  /// The parameter `chatId` of this provider.
  String get chatId;
}

class _SignalChatControllerProviderElement
    extends AutoDisposeNotifierProviderElement<SignalChatController,
        SignalChatState> with SignalChatControllerRef {
  _SignalChatControllerProviderElement(super.provider);

  @override
  String get chatId => (origin as SignalChatControllerProvider).chatId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package

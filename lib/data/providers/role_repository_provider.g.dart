// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'role_repository_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(roleRepository)
final roleRepositoryProvider = RoleRepositoryProvider._();

final class RoleRepositoryProvider
    extends $FunctionalProvider<RoleRepository, RoleRepository, RoleRepository>
    with $Provider<RoleRepository> {
  RoleRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'roleRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$roleRepositoryHash();

  @$internal
  @override
  $ProviderElement<RoleRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  RoleRepository create(Ref ref) {
    return roleRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RoleRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RoleRepository>(value),
    );
  }
}

String _$roleRepositoryHash() => r'f1a9e6e51becbb8b83ec8672a8b01ba704549337';

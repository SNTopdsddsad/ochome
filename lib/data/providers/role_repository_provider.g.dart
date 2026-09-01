// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'role_repository_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 对外只提供 [RoleRepository]，默认实现为 [DriftRoleRepository]。
///
/// 页面应 `ref.watch/read(roleRepositoryProvider)`，不要直接 new 实现类。
/// 测试时 `overrideWithValue` 即可换成假实现。

@ProviderFor(roleRepository)
final roleRepositoryProvider = RoleRepositoryProvider._();

/// 对外只提供 [RoleRepository]，默认实现为 [DriftRoleRepository]。
///
/// 页面应 `ref.watch/read(roleRepositoryProvider)`，不要直接 new 实现类。
/// 测试时 `overrideWithValue` 即可换成假实现。

final class RoleRepositoryProvider
    extends $FunctionalProvider<RoleRepository, RoleRepository, RoleRepository>
    with $Provider<RoleRepository> {
  /// 对外只提供 [RoleRepository]，默认实现为 [DriftRoleRepository]。
  ///
  /// 页面应 `ref.watch/read(roleRepositoryProvider)`，不要直接 new 实现类。
  /// 测试时 `overrideWithValue` 即可换成假实现。
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

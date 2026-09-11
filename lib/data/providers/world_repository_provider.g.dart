// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'world_repository_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 对外只提供 [WorldRepository]，默认实现为 [DriftWorldRepository]。
///
/// 页面应 `ref.watch/read(worldRepositoryProvider)`，不要直接 new 实现类。
/// 测试时 `overrideWithValue` 即可换成假实现。

@ProviderFor(worldRepository)
final worldRepositoryProvider = WorldRepositoryProvider._();

/// 对外只提供 [WorldRepository]，默认实现为 [DriftWorldRepository]。
///
/// 页面应 `ref.watch/read(worldRepositoryProvider)`，不要直接 new 实现类。
/// 测试时 `overrideWithValue` 即可换成假实现。

final class WorldRepositoryProvider
    extends
        $FunctionalProvider<WorldRepository, WorldRepository, WorldRepository>
    with $Provider<WorldRepository> {
  /// 对外只提供 [WorldRepository]，默认实现为 [DriftWorldRepository]。
  ///
  /// 页面应 `ref.watch/read(worldRepositoryProvider)`，不要直接 new 实现类。
  /// 测试时 `overrideWithValue` 即可换成假实现。
  WorldRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'worldRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$worldRepositoryHash();

  @$internal
  @override
  $ProviderElement<WorldRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  WorldRepository create(Ref ref) {
    return worldRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WorldRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WorldRepository>(value),
    );
  }
}

String _$worldRepositoryHash() => r'f7bd89db8d0141a6900010d4e063911e1114dae8';

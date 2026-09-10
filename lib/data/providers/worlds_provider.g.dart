// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'worlds_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 世界观列表的响应式数据源，底层订阅 [WorldRepository.watchAll]。

@ProviderFor(worlds)
final worldsProvider = WorldsProvider._();

/// 世界观列表的响应式数据源，底层订阅 [WorldRepository.watchAll]。

final class WorldsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<World>>,
          List<World>,
          Stream<List<World>>
        >
    with $FutureModifier<List<World>>, $StreamProvider<List<World>> {
  /// 世界观列表的响应式数据源，底层订阅 [WorldRepository.watchAll]。
  WorldsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'worldsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$worldsHash();

  @$internal
  @override
  $StreamProviderElement<List<World>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<World>> create(Ref ref) {
    return worlds(ref);
  }
}

String _$worldsHash() => r'9c233a6d341ee674b76a6f37ab0e8a3f400776a1';

/// 归属某世界观的角色，供世界观编辑页「角色」页签使用。

@ProviderFor(rolesInWorld)
final rolesInWorldProvider = RolesInWorldFamily._();

/// 归属某世界观的角色，供世界观编辑页「角色」页签使用。

final class RolesInWorldProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Role>>,
          List<Role>,
          Stream<List<Role>>
        >
    with $FutureModifier<List<Role>>, $StreamProvider<List<Role>> {
  /// 归属某世界观的角色，供世界观编辑页「角色」页签使用。
  RolesInWorldProvider._({
    required RolesInWorldFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'rolesInWorldProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$rolesInWorldHash();

  @override
  String toString() {
    return r'rolesInWorldProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<Role>> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<List<Role>> create(Ref ref) {
    final argument = this.argument as int;
    return rolesInWorld(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is RolesInWorldProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$rolesInWorldHash() => r'b0e9e4c0c3d6bda0fc4a5727110a426e3f1fa3ba';

/// 归属某世界观的角色，供世界观编辑页「角色」页签使用。

final class RolesInWorldFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<Role>>, int> {
  RolesInWorldFamily._()
    : super(
        retry: null,
        name: r'rolesInWorldProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// 归属某世界观的角色，供世界观编辑页「角色」页签使用。

  RolesInWorldProvider call(int worldId) =>
      RolesInWorldProvider._(argument: worldId, from: this);

  @override
  String toString() => r'rolesInWorldProvider';
}

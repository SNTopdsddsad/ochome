// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'roles_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 角色列表的响应式数据源，底层订阅 [RoleRepository.watchAll]。

@ProviderFor(roles)
final rolesProvider = RolesProvider._();

/// 角色列表的响应式数据源，底层订阅 [RoleRepository.watchAll]。

final class RolesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Role>>,
          List<Role>,
          Stream<List<Role>>
        >
    with $FutureModifier<List<Role>>, $StreamProvider<List<Role>> {
  /// 角色列表的响应式数据源，底层订阅 [RoleRepository.watchAll]。
  RolesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'rolesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$rolesHash();

  @$internal
  @override
  $StreamProviderElement<List<Role>> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<List<Role>> create(Ref ref) {
    return roles(ref);
  }
}

String _$rolesHash() => r'e17afe777cc642bcef020bafe54ca053b0ad99b1';

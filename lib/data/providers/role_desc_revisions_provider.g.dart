// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'role_desc_revisions_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 单个角色的设定修订列表，新的在前。

@ProviderFor(roleDescRevisions)
final roleDescRevisionsProvider = RoleDescRevisionsFamily._();

/// 单个角色的设定修订列表，新的在前。

final class RoleDescRevisionsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<RoleDescRevision>>,
          List<RoleDescRevision>,
          Stream<List<RoleDescRevision>>
        >
    with
        $FutureModifier<List<RoleDescRevision>>,
        $StreamProvider<List<RoleDescRevision>> {
  /// 单个角色的设定修订列表，新的在前。
  RoleDescRevisionsProvider._({
    required RoleDescRevisionsFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'roleDescRevisionsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$roleDescRevisionsHash();

  @override
  String toString() {
    return r'roleDescRevisionsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<RoleDescRevision>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<RoleDescRevision>> create(Ref ref) {
    final argument = this.argument as int;
    return roleDescRevisions(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is RoleDescRevisionsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$roleDescRevisionsHash() => r'35053c3d3f364100c8b36ffe1ca35a05b3e54298';

/// 单个角色的设定修订列表，新的在前。

final class RoleDescRevisionsFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<RoleDescRevision>>, int> {
  RoleDescRevisionsFamily._()
    : super(
        retry: null,
        name: r'roleDescRevisionsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// 单个角色的设定修订列表，新的在前。

  RoleDescRevisionsProvider call(int roleId) =>
      RoleDescRevisionsProvider._(argument: roleId, from: this);

  @override
  String toString() => r'roleDescRevisionsProvider';
}

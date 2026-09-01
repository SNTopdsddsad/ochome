// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 进程内共享的 [AppDatabase]。
///
/// [keepAlive] 避免页面销毁后反复开关库；[Ref.onDispose] 在 ProviderScope
/// 拆除时关闭连接。测试可传入 `NativeDatabase.memory()` 覆盖本 provider。

@ProviderFor(appDatabase)
final appDatabaseProvider = AppDatabaseProvider._();

/// 进程内共享的 [AppDatabase]。
///
/// [keepAlive] 避免页面销毁后反复开关库；[Ref.onDispose] 在 ProviderScope
/// 拆除时关闭连接。测试可传入 `NativeDatabase.memory()` 覆盖本 provider。

final class AppDatabaseProvider
    extends $FunctionalProvider<AppDatabase, AppDatabase, AppDatabase>
    with $Provider<AppDatabase> {
  /// 进程内共享的 [AppDatabase]。
  ///
  /// [keepAlive] 避免页面销毁后反复开关库；[Ref.onDispose] 在 ProviderScope
  /// 拆除时关闭连接。测试可传入 `NativeDatabase.memory()` 覆盖本 provider。
  AppDatabaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appDatabaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appDatabaseHash();

  @$internal
  @override
  $ProviderElement<AppDatabase> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AppDatabase create(Ref ref) {
    return appDatabase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppDatabase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppDatabase>(value),
    );
  }
}

String _$appDatabaseHash() => r'59cce38d45eeaba199eddd097d8e149d66f9f3e1';

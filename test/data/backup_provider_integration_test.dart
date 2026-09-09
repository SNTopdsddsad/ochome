import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ochome/data/models/role.dart';
import 'package:ochome/data/providers/app_database_provider.dart';
import 'package:ochome/data/providers/backup_coordinator_provider.dart';
import 'package:ochome/data/providers/role_repository_provider.dart';
import 'package:ochome/data/providers/role_assets_provider.dart';
import 'package:ochome/data/providers/role_desc_revisions_provider.dart';
import 'package:ochome/data/providers/roles_provider.dart';
import 'package:ochome/data/services/data_storage.dart';
import 'package:ochome/features/backup/backup_coordinator.dart';
import 'package:ochome/features/backup/backup_models.dart';

import '../fakes/backup_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late FakeBackupTransport cloud;
  DataStorage? storage;
  ProviderContainer? container;
  BackupCoordinator? coordinator;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('backup-provider-test');
    cloud = FakeBackupTransport();
    final temporary = await Directory('${root.path}/temporary').create();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async {
            if (call.method == 'getTemporaryDirectory') return temporary.path;
            throw MissingPluginException(
              'Unexpected directory request: ${call.method}',
            );
          },
        );
    storage = null;
    container = null;
    coordinator = null;
  });
  tearDown(() async {
    await coordinator?.dispose();
    final owner = container;
    if (owner != null) {
      if (owner.exists(appDatabaseProvider)) {
        await owner.read(appDatabaseProvider).close();
      }
      owner.dispose();
    }
    await storage?.close();
    await cloud.controller.close();
    await root.delete(recursive: true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
  });

  Future<void> openProviders() async {
    storage = await initializeDataStorage(supportDirectory: () async => root);
    container = ProviderContainer(
      overrides: [backupTransportProvider.overrideWithValue(cloud)],
    );
    coordinator = await container!.read(backupCoordinatorProvider.future);
  }

  test(
    'real provider reopens switched root and rejects a captured old repository',
    () async {
      createFixture(root);
      await openProviders();
      final owner = container!;
      final service = coordinator!;
      final oldRepository = owner.read(roleRepositoryProvider);
      final original = (await oldRepository.getById(1))!;
      await service.startBackup();
      await waitForJob(service, (job) => job.phase == BackupPhase.completed);
      final descriptor = (await service.listBackups()).snapshots.single;
      await oldRepository.update(_rename(original, '本机后续编辑'));
      expect((await oldRepository.getById(1))!.name, '本机后续编辑');
      await service.prepareRestore(BackupSource.snapshot(descriptor));
      await waitForJob(
        service,
        (job) => job.phase == BackupPhase.readyForReview,
      );
      await service.confirmRestore(service.currentJob!.operationId);
      final restoredRepository = owner.read(roleRepositoryProvider);
      expect(identical(restoredRepository, oldRepository), isFalse);
      expect((await restoredRepository.getById(1))!.name, original.name);
      expect(storage!.epoch, greaterThan(0));
      await expectLater(
        oldRepository.update(_rename(original, '过期写入')),
        throwsA(isA<StateError>()),
      );
      expect((await restoredRepository.getById(1))!.name, original.name);
      expect(storage!.rollbackDirectory, isNull);
    },
  );

  for (final paused in [false, true]) {
    test(
      'restore reconnects database subscriptions (paused: $paused)',
      () async {
        createFixture(root);
        await openProviders();
        final owner = container!;
        final service = coordinator!;
        final roles = owner.listen(rolesProvider, (_, _) {});
        final assets = owner.listen(roleAssetsProvider(1), (_, _) {});
        final revisions = owner.listen(roleDescRevisionsProvider(1), (_, _) {});
        final original = (await owner.read(rolesProvider.future)).first;
        await owner.read(roleAssetsProvider(1).future);
        await owner.read(roleDescRevisionsProvider(1).future);
        if (paused) {
          roles.pause();
          assets.pause();
          revisions.pause();
        }
        await service.startBackup();
        await waitForJob(service, (job) => job.phase == BackupPhase.completed);
        final descriptor = (await service.listBackups()).snapshots.single;
        await owner
            .read(roleRepositoryProvider)
            .update(_rename(original, '恢复前的编辑'));
        await service.prepareRestore(BackupSource.snapshot(descriptor));
        await waitForJob(
          service,
          (job) => job.phase == BackupPhase.readyForReview,
        );
        final activation = service.confirmRestore(
          service.currentJob!.operationId,
        );
        try {
          await activation.timeout(const Duration(seconds: 3));
          expect(service.currentJob!.phase, BackupPhase.completed);
          if (paused) {
            roles.resume();
            assets.resume();
            revisions.resume();
          }
          expect(
            (await owner.read(rolesProvider.future)).first.name,
            original.name,
          );
          await owner.read(roleAssetsProvider(1).future);
          await owner.read(roleDescRevisionsProvider(1).future);
        } finally {
          roles.close();
          assets.close();
          revisions.close();
          await activation;
        }
      },
    );
  }

  test('pristine initialization materializes the ordinary DB only after storage bootstrap', () async {
    await openProviders();
    expect(storage!.isRecoveryOnly, isFalse);
    expect(await container!.read(roleRepositoryProvider).list(), isEmpty);
    expect(
      await File('${storage!.activeDirectory.path}/ochome.sqlite').exists(),
      isTrue,
    );
    expect((await coordinator!.currentContents()).summary.roleCount, 0);
  });

  test('real recovery bootstrap/provider flow never creates an empty damaged database', () async {
    final sourceRoot = await Directory.systemTemp.createTemp(
      'backup-provider-source',
    );
    createFixture(sourceRoot);
    final source = await DataStorage.open(sourceRoot);
    final producer = BackupCoordinator(
      storage: source,
      transport: cloud,
      closeDatabase: () async {},
      reopenDatabase: () async {},
    );
    await producer.startBackup();
    await waitForJob(producer, (job) => job.phase == BackupPhase.completed);
    final descriptor = (await producer.listBackups()).snapshots.single;
    await producer.dispose();
    await source.close();
    await sourceRoot.delete(recursive: true);

    final broken = File('${root.path}/ochome.sqlite');
    await broken.writeAsString('corrupt original bytes', flush: true);
    await openProviders();
    expect(storage!.isRecoveryOnly, isTrue);
    expect(container!.exists(appDatabaseProvider), isFalse);
    expect(await broken.readAsString(), 'corrupt original bytes');
    await coordinator!.prepareRestore(BackupSource.snapshot(descriptor));
    await waitForJob(
      coordinator!,
      (job) => job.phase == BackupPhase.readyForReview,
    );
    expect(coordinator!.currentJob!.restorePreview!.currentUnreadable, isTrue);
    expect(container!.exists(appDatabaseProvider), isFalse);
    await coordinator!.confirmRestore(coordinator!.currentJob!.operationId);
    expect(storage!.isRecoveryOnly, isFalse);
    expect(await container!.read(roleRepositoryProvider).list(), isNotEmpty);
    expect(await broken.readAsString(), 'corrupt original bytes');
  });
}

Role _rename(Role role, String name) => Role(
  id: role.id,
  name: name,
  sex: role.sex,
  age: role.age,
  birthday: role.birthday,
  race: role.race,
  occupation: role.occupation,
  desc: role.desc,
  coverImg: role.coverImg,
  customAttributes: role.customAttributes,
);

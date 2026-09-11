import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'app.dart';
import 'data/services/data_storage.dart';
import 'theme/zaidang_spacing.dart';
import 'theme/zaidang_theme.dart';
import 'theme/zaidang_type.dart';
import 'widgets/storage_error_details.dart';

/// Resolve/recover the data root before any business database provider opens it.
class AppStorageBootstrap extends StatefulWidget {
  const AppStorageBootstrap({super.key, this.initialize});
  final Future<DataStorage> Function()? initialize;
  @override
  State<AppStorageBootstrap> createState() => _AppStorageBootstrapState();
}

class _AppStorageBootstrapState extends State<AppStorageBootstrap> {
  late Future<DataStorage> _initialization = _initialize();

  Future<DataStorage> _initialize() async {
    try {
      final storage = await (widget.initialize ?? initializeDataStorage)();
      if (kDebugMode && storage.isRecoveryOnly) {
        debugPrint('Local storage recovery: ${storage.recoveryError}');
      }
      return storage;
    } catch (error) {
      if (kDebugMode) debugPrint('Local storage startup failed: $error');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<DataStorage>(
    future: _initialization,
    builder: (context, snapshot) {
      if (snapshot.hasData) return const MyApp();
      return MaterialApp(
        title: '崽档',
        theme: zaidangLightTheme(),
        darkTheme: zaidangDarkTheme(),
        home: Scaffold(
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(ZaidangSpacing.xxl),
                  child: snapshot.hasError
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.folder_off_outlined, size: 36),
                            const SizedBox(height: ZaidangSpacing.xl),
                            Text(
                              '暂时无法打开本机资料',
                              style: ZaidangType.of(context).heading,
                            ),
                            const SizedBox(height: ZaidangSpacing.md),
                            const Text(
                              '原文件会保留。请检查可用空间，并确认没有另一份应用正在使用这些资料。',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: ZaidangSpacing.xl),
                            StorageErrorDetails(error: snapshot.error),
                            FilledButton(
                              onPressed: () => setState(
                                () => _initialization = _initialize(),
                              ),
                              child: const Text('重试'),
                            ),
                          ],
                        )
                      : const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: ZaidangSpacing.xl),
                            Text('正在检查本机资料…'),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

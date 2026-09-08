import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:file_selector/file_selector.dart';

import 'file_fingerprint_store.dart';

/// One source read, one bounded chunk in flight. The worker writes and hashes
/// the same bytes off the UI isolate, acknowledges each chunk after writing,
/// and drains/closes on every failure before the pending file is removed.
class ManagedFileImporter {
  static Future<FileFingerprint> copy(
    XFile source,
    File target, {
    FileFingerprintStore? fingerprints,
  }) async {
    final result = await ManagedFileWork.run(() => _copy(source, target));
    if (fingerprints != null) await fingerprints.remember(target, result);
    return result;
  }

  static Future<FileFingerprint> _copy(XFile source, File target) async {
    if (await target.exists()) {
      throw FileSystemException('不能覆盖已有原文件', target.path);
    }
    await target.parent.create(recursive: true);
    final expectedBytes = await source.length();
    final pending = File(
      '${target.parent.path}/.${target.uri.pathSegments.last}.pending',
    );
    if (await pending.exists()) {
      throw FileSystemException('导入准备文件已存在', pending.path);
    }
    final receive = ReceivePort();
    final responses = StreamIterator<dynamic>(receive);
    Isolate? worker;
    SendPort? requests;
    var workerCompleted = false;
    try {
      worker = await Isolate.spawn(
        _importWorker,
        [receive.sendPort, pending.path, expectedBytes],
        onExit: receive.sendPort,
        onError: receive.sendPort,
      );
      Future<dynamic> response() async {
        if (!await responses.moveNext()) {
          throw const FileSystemException('文件导入进程意外结束');
        }
        final result = responses.current;
        if (result == null || result is List) {
          throw const FileSystemException('文件导入进程意外结束');
        }
        if (result is Map && result['error'] is String) {
          throw FileSystemException(result['error'] as String, target.path);
        }
        return result;
      }

      requests = await response() as SendPort;
      await for (final chunk in source.openRead()) {
        // Platform XFile streams use bounded chunks; split oversized custom
        // stream chunks too, so no whole media message reaches the worker.
        for (var offset = 0; offset < chunk.length; offset += 64 * 1024) {
          final end = offset + 64 * 1024 < chunk.length
              ? offset + 64 * 1024
              : chunk.length;
          requests.send(
            TransferableTypedData.fromList([
              Uint8List.fromList(chunk.sublist(offset, end)),
            ]),
          );
          await response();
        }
      }
      requests.send(null);
      final completed = await response() as Map;
      workerCompleted = true;
      final fingerprint = FileFingerprint(
        sha256: completed['sha256'] as String,
        bytes: completed['bytes'] as int,
      );
      await pending.rename(target.path);
      return fingerprint;
    } catch (_) {
      if (requests != null && !workerCompleted) {
        requests.send('abort');
        // A failed worker already closed its output before reporting error;
        // an active worker must acknowledge abort before cleanup.
        if (responses.current != null &&
            responses.current is! List &&
            (responses.current is! Map ||
                (responses.current as Map)['error'] == null)) {
          await responses.moveNext();
        }
      }
      rethrow;
    } finally {
      worker?.kill(priority: Isolate.immediate);
      await responses.cancel();
      receive.close();
      if (await pending.exists()) await pending.delete();
    }
  }
}

Future<void> _importWorker(List<Object> args) async {
  final replies = args[0] as SendPort;
  final pending = File(args[1] as String);
  final expectedBytes = args[2] as int;
  final receive = ReceivePort();
  RandomAccessFile? output;
  try {
    output = await pending.open(mode: FileMode.writeOnly);
    final digestOutput = _DigestSink();
    final digestInput = sha256.startChunkedConversion(digestOutput);
    var bytes = 0;
    replies.send(receive.sendPort);
    await for (final message in receive) {
      if (message == 'abort') {
        await output!.close();
        output = null;
        replies.send(false);
        break;
      }
      if (message == null) {
        digestInput.close();
        if (bytes != expectedBytes) throw const FileSystemException('文件复制不完整');
        await output!.flush();
        await output.close();
        output = null;
        replies.send({
          'sha256': digestOutput.digest!.toString(),
          'bytes': bytes,
        });
        break;
      }
      final chunk = (message as TransferableTypedData)
          .materialize()
          .asUint8List();
      bytes += chunk.length;
      if (bytes > expectedBytes) {
        throw const FileSystemException('文件大小在导入时发生变化');
      }
      digestInput.add(chunk);
      await output!.writeFrom(chunk);
      replies.send(true);
    }
  } catch (error) {
    try {
      await output?.close();
    } catch (_) {
      /* Report initial failure. */
    }
    output = null;
    replies.send({'error': error.toString()});
  } finally {
    await output?.close();
    receive.close();
  }
}

class _DigestSink implements Sink<Digest> {
  Digest? digest;
  @override
  void add(Digest data) {
    digest = data;
  }

  @override
  void close() {}
}

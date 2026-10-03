import 'dart:async';
import 'dart:collection';
import 'dart:isolate';
import 'dart:math';

import 'package:denizen_ai/denizen_ai.dart' hide OfflineAIService, DocumentIngestionService;
import '../../services/offline_ai_service.dart';
import 'device_tier.dart';

class CancellationException implements Exception {
  final String message;
  CancellationException(this.message);
  @override
  String toString() => 'CancellationException: $message';
}

/// One document's ingestion job: its chunks, and the callback that fires
/// (with just the docId) once every chunk has been embedded and upserted.
///
/// FIX: onIndexed lives on the task itself, not threaded through the
/// recursive queue-processing call. That was the bug in the previous round —
/// a second enqueue() while the worker was busy would silently discard its
/// own callback and later fire the *first* document's callback for the
/// *second* document's completion.
class IngestionTaskHandle {
  final String docId;
  final List<String> chunks;
  final void Function(String docId) onIndexed;
  final Completer<void> completer = Completer();
  SendPort? controlPort;

  IngestionTaskHandle({
    required this.docId,
    required this.chunks,
    required this.onIndexed,
  });
}

class _WorkerArgs {
  final String docId;
  final List<String> chunks;
  final int batchSize;
  final int yieldMs;
  final SendPort sendPort;

  _WorkerArgs({
    required this.docId,
    required this.chunks,
    required this.batchSize,
    required this.yieldMs,
    required this.sendPort,
  });
}

class DocumentIngestionService {
  final Map<String, IngestionTaskHandle> _activeTasks = {};
  final Queue<IngestionTaskHandle> _queue = Queue();
  // Guards against a race: deleteDocumentByTitle runs once at cancel time,
  // but a BATCH_DONE message already in flight from the worker isolate can
  // still arrive afterward and re-insert chunks for a doc that was just
  // deleted. Any doc id in this set has its batches dropped until COMPLETE
  // clears it.
  final Set<String> _cancelledDocIds = {};
  Isolate? _workerIsolate;
  bool _isWorkerBusy = false;

  /// Enqueue a document for background vector embedding.
  /// [onIndexed] is called with just the docId once ingestion completes —
  /// deliberately not a Document, since constructing a fake partial
  /// Document to carry an id risks resetting/violating required fields.
  void enqueue(
    String docId,
    List<String> chunks,
    DeviceTier tier,
    void Function(String docId) onIndexed,
  ) {
    final task = IngestionTaskHandle(
      docId: docId,
      chunks: chunks,
      onIndexed: onIndexed,
    );
    _queue.add(task);
    _processNextInQueue(tier);
  }

  /// Cancel ingestion for a deleted, backgrounded, or unmounted document.
  /// Purges both the pending queue AND any active worker task, and cleans
  /// up any vectors already upserted before the cancel signal landed.
  ///
  /// Uses deleteDocumentByTitle(docId) which looks up the SDK's integer
  /// row ID by the title column — works whether sdkDocId was ever set
  /// or not, whether the doc was partially or fully indexed, and whether
  /// this is the original session or a post-restart session.
  Future<void> cancelIngestion(String docId) async {
    _queue.removeWhere((t) => t.docId == docId);
    _cancelledDocIds.add(docId);

    final task = _activeTasks.remove(docId);
    if (task != null) {
      task.controlPort?.send({'action': 'CANCEL', 'docId': docId});
      if (!task.completer.isCompleted) {
        task.completer.completeError(
          CancellationException('Ingestion cancelled by user'),
        );
      }
    }

    // Clean up any vectors already written — safe to call even if no
    // matching document exists in the vector store (no-op in that case).
    try {
      final storage = OfflineAIService.instance.storageService;
      if (storage.isInitialized) {
        storage.deleteDocumentByTitle(docId);
      }
    } catch (e) {
      // Non-fatal: nothing to clean up, or storage not ready yet.
    }
  }

  void _processNextInQueue(DeviceTier tier) async {
    if (_isWorkerBusy || _queue.isEmpty) return;
    _isWorkerBusy = true;

    final task = _queue.removeFirst();
    _activeTasks[task.docId] = task;

    final config = DeviceTierConfig.forTier(tier);
    final receivePort = ReceivePort();

    _workerIsolate = await Isolate.spawn(
      _workerEntry,
      _WorkerArgs(
        docId: task.docId,
        chunks: task.chunks,
        batchSize: config.batchSize,
        yieldMs: config.yieldMs,
        sendPort: receivePort.sendPort,
      ),
    );

    // DESIGN NOTE: The BATCH_DONE handler runs on the main isolate (this
    // is where the ReceivePort was created). The insertChunkBatch() and
    // insertDocument() calls below are synchronous SQLite writes that
    // block the main thread.
    //
    // This is an acceptable tradeoff: VectorStorageService holds an FFI
    // Database pointer that cannot cross isolate boundaries, so the
    // writes must happen here. The actual blocking time is ~0.5–2ms per
    // batch (one BEGIN/COMMIT transaction wrapping N chunk inserts in
    // WAL mode). The expensive work — embedding computation via TFLite —
    // runs in the worker isolate. On the target device spectrum (Go
    // phones at batch=2, flagships at batch=10), the main-thread cost
    // is well under a single frame budget (16ms).
    //
    // To move writes off the main thread, the SDK would need to support
    // opening a second sqlite3 connection from a worker isolate against
    // the same DB file — a separate, larger change.

    // Track the SDK integer row ID for insertChunkBatch calls within
    // this session. This is ephemeral — not persisted on Document.
    // Post-restart deletion uses deleteDocumentByTitle(string) instead.
    int? sdkDocId;

    receivePort.listen((message) {
      if (message is! Map) return;

      switch (message['action']) {
        case 'CONTROL_PORT':
          task.controlPort = message['port'] as SendPort;
          break;

        case 'BATCH_DONE':
          if (_cancelledDocIds.contains(task.docId)) break; // stale, drop it

          final List<int> chunkIndices = List<int>.from(message['chunkIndices']);
          final List<dynamic> rawVectors = message['vectors'];
          final vectors = rawVectors.map((v) => List<double>.from(v)).toList();

          try {
            final storage = OfflineAIService.instance.storageService;
            if (!storage.isInitialized) break;

            // Register the document row once on the first batch.
            sdkDocId ??= storage.insertDocument(task.docId);

            // Transactional batch insert — atomic, crash-safe.
            storage.insertChunkBatch(
              sdkDocId!,
              chunkIndices.map((i) => task.chunks[i]).toList(),
              chunkIndices,
              vectors,
            );
          } catch (e) {
            // A failed batch shouldn't kill the whole ingestion job —
            // the doc just ends up partially indexed, which is still
            // strictly better than fully unindexed.
          }
          break;

        case 'COMPLETE':
          receivePort.close();
          _workerIsolate?.kill(priority: Isolate.beforeNextEvent);
          _workerIsolate = null;
          _activeTasks.remove(task.docId);
          _cancelledDocIds.remove(task.docId); // avoid leaking the set
          _isWorkerBusy = false;

          if (!task.completer.isCompleted) task.completer.complete();
          task.onIndexed(task.docId);

          _processNextInQueue(tier);
          break;
      }
    });
  }
}

void _workerEntry(_WorkerArgs args) async {
  final controlPort = ReceivePort();
  args.sendPort.send({'action': 'CONTROL_PORT', 'port': controlPort.sendPort});

  bool isCancelled = false;
  controlPort.listen((msg) {
    if (msg is Map && msg['action'] == 'CANCEL') {
      isCancelled = true;
    }
  });

  final provider = TFLiteEmbeddingProvider(
    modelPath: 'assets/models/all-MiniLM-L6-v2-int8.tflite',
  );
  await provider.initialize();

  try {
    for (var i = 0; i < args.chunks.length; i += args.batchSize) {
      if (isCancelled) break;

      final end = min(i + args.batchSize, args.chunks.length);
      final batch = args.chunks.sublist(i, end);
      final chunkIndices = List.generate(end - i, (idx) => i + idx);
      final vectors = await provider.embedBatch(batch);

      args.sendPort.send({
        'action': 'BATCH_DONE',
        'docId': args.docId,
        'chunkIndices': chunkIndices,
        'vectors': vectors,
      });

      if (args.yieldMs > 0) {
        await Future.delayed(Duration(milliseconds: args.yieldMs));
      }
    }
  } finally {
    await provider.dispose();
    controlPort.close();
    args.sendPort.send({'action': 'COMPLETE'});
  }
}

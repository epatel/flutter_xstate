/// Step 8: Multi-Machine Communication
///
/// Demonstrates:
/// - Running two separate state machines simultaneously
/// - Inter-machine communication using ActorSystem
/// - Download manager machine + UI controller machine
/// - Sending events between machines with sendTo
/// - Progress reporting between actors
///
/// Run with: flutter run -d chrome
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_xstate/flutter_xstate.dart';

// ============================================================================
// DOWNLOAD MACHINE - Handles the actual download process
// ============================================================================

class DownloadContext {
  final String? url;
  final double progress; // 0.0 to 1.0
  final String? error;
  final String? filename;

  const DownloadContext({
    this.url,
    this.progress = 0.0,
    this.error,
    this.filename,
  });

  DownloadContext copyWith({
    String? url,
    double? progress,
    String? error,
    String? filename,
    bool clearError = false,
  }) =>
      DownloadContext(
        url: url ?? this.url,
        progress: progress ?? this.progress,
        error: clearError ? null : (error ?? this.error),
        filename: filename ?? this.filename,
      );
}

sealed class DownloadEvent extends XEvent {}

/// Request to start a download (sent from UI machine)
class StartDownloadEvent extends DownloadEvent {
  final String url;
  final String filename;

  StartDownloadEvent({required this.url, required this.filename});

  @override
  String get type => 'START_DOWNLOAD';
}

/// Internal: progress update during download
class DownloadProgressEvent extends DownloadEvent {
  final double progress;

  DownloadProgressEvent(this.progress);

  @override
  String get type => 'DOWNLOAD_PROGRESS';
}

/// Internal: download completed successfully
class DownloadCompleteEvent extends DownloadEvent {
  @override
  String get type => 'DOWNLOAD_COMPLETE';
}

/// Internal: download failed
class DownloadFailedEvent extends DownloadEvent {
  final String error;

  DownloadFailedEvent(this.error);

  @override
  String get type => 'DOWNLOAD_FAILED';
}

/// Request to cancel download (sent from UI machine)
class CancelDownloadEvent extends DownloadEvent {
  @override
  String get type => 'CANCEL_DOWNLOAD';
}

/// Request to retry download (sent from UI machine)
class RetryDownloadEvent extends DownloadEvent {
  @override
  String get type => 'RETRY_DOWNLOAD';
}

/// Request to reset to idle (sent from UI machine)
class ResetDownloadEvent extends DownloadEvent {
  @override
  String get type => 'RESET_DOWNLOAD';
}

// Timer for simulating download
Timer? _downloadTimer;

/// Simulate a download with progress updates
void _simulateDownload(
  StateMachineActor<DownloadContext, DownloadEvent> actor,
  String url,
) {
  var progress = 0.0;
  _downloadTimer?.cancel();

  _downloadTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
    progress += 0.05;

    if (progress >= 1.0) {
      timer.cancel();
      _downloadTimer = null;

      // Simulate random failures (20% chance)
      if (url.contains('fail')) {
        actor.send(DownloadFailedEvent('Network error: Connection timed out'));
      } else {
        actor.send(DownloadCompleteEvent());
      }
    } else {
      actor.send(DownloadProgressEvent(progress));
    }
  });
}

void _cancelSimulatedDownload() {
  _downloadTimer?.cancel();
  _downloadTimer = null;
}

StateMachine<DownloadContext, DownloadEvent> createDownloadMachine() {
  return StateMachine.create<DownloadContext, DownloadEvent>(
    (m) => m
      ..context(const DownloadContext())
      ..initial('idle')

      // IDLE - Waiting for download request
      ..state(
        'idle',
        (s) => s
          ..on<StartDownloadEvent>('downloading', actions: [
            (ctx, event) {
              final e = event as StartDownloadEvent;
              return ctx.copyWith(
                url: e.url,
                filename: e.filename,
                progress: 0.0,
                clearError: true,
              );
            },
          ]),
      )

      // DOWNLOADING - Download in progress
      ..state(
        'downloading',
        (s) => s
          ..entry([
            (ctx, event) {
              // This is a side effect - in a real app, use invoke() for async
              // For demo purposes, we trigger simulation when entry action runs
              return ctx;
            },
          ])
          ..on<DownloadProgressEvent>(null, actions: [
            // null target = self-transition (stay in same state)
            (ctx, event) =>
                ctx.copyWith(progress: (event as DownloadProgressEvent).progress),
          ])
          ..on<DownloadCompleteEvent>('completed', actions: [
            (ctx, _) => ctx.copyWith(progress: 1.0),
          ])
          ..on<DownloadFailedEvent>('error', actions: [
            (ctx, event) =>
                ctx.copyWith(error: (event as DownloadFailedEvent).error),
          ])
          ..on<CancelDownloadEvent>('idle', actions: [
            (ctx, _) {
              _cancelSimulatedDownload();
              return ctx.copyWith(progress: 0.0, clearError: true);
            },
          ]),
      )

      // COMPLETED - Download finished successfully
      ..state(
        'completed',
        (s) => s
          ..on<ResetDownloadEvent>('idle', actions: [
            (ctx, _) => const DownloadContext(),
          ])
          ..on<StartDownloadEvent>('downloading', actions: [
            (ctx, event) {
              final e = event as StartDownloadEvent;
              return ctx.copyWith(
                url: e.url,
                filename: e.filename,
                progress: 0.0,
              );
            },
          ]),
      )

      // ERROR - Download failed
      ..state(
        'error',
        (s) => s
          ..on<RetryDownloadEvent>('downloading', actions: [
            (ctx, _) => ctx.copyWith(progress: 0.0, clearError: true),
          ])
          ..on<ResetDownloadEvent>('idle', actions: [
            (ctx, _) => const DownloadContext(),
          ]),
      ),
    id: 'download',
  );
}

// ============================================================================
// UI MACHINE - Manages UI state and communicates with download machine
// ============================================================================

class UIContext {
  final String selectedFile;
  final bool showCompletionDialog;
  final int downloadCount; // Track how many downloads completed

  const UIContext({
    this.selectedFile = '',
    this.showCompletionDialog = false,
    this.downloadCount = 0,
  });

  UIContext copyWith({
    String? selectedFile,
    bool? showCompletionDialog,
    int? downloadCount,
  }) =>
      UIContext(
        selectedFile: selectedFile ?? this.selectedFile,
        showCompletionDialog: showCompletionDialog ?? this.showCompletionDialog,
        downloadCount: downloadCount ?? this.downloadCount,
      );
}

sealed class UIEvent extends XEvent {}

/// User selected a file to download
class SelectFileEvent extends UIEvent {
  final String filename;
  final String url;

  SelectFileEvent({required this.filename, required this.url});

  @override
  String get type => 'SELECT_FILE';
}

/// User clicked download button
class RequestDownloadEvent extends UIEvent {
  @override
  String get type => 'REQUEST_DOWNLOAD';
}

/// User clicked cancel button
class RequestCancelEvent extends UIEvent {
  @override
  String get type => 'REQUEST_CANCEL';
}

/// User clicked retry button
class RequestRetryEvent extends UIEvent {
  @override
  String get type => 'REQUEST_RETRY';
}

/// Download machine reported completion (inter-machine event)
class DownloadCompletedNotification extends UIEvent {
  final String filename;

  DownloadCompletedNotification(this.filename);

  @override
  String get type => 'DOWNLOAD_COMPLETED_NOTIFICATION';
}

/// Download machine reported error (inter-machine event)
class DownloadErrorNotification extends UIEvent {
  final String error;

  DownloadErrorNotification(this.error);

  @override
  String get type => 'DOWNLOAD_ERROR_NOTIFICATION';
}

/// User dismissed the completion dialog
class DismissDialogEvent extends UIEvent {
  @override
  String get type => 'DISMISS_DIALOG';
}

/// User wants to start fresh
class ResetUIEvent extends UIEvent {
  @override
  String get type => 'RESET_UI';
}

StateMachine<UIContext, UIEvent> createUIMachine() {
  return StateMachine.create<UIContext, UIEvent>(
    (m) => m
      ..context(const UIContext())
      ..initial('browsing')

      // BROWSING - User is selecting files
      ..state(
        'browsing',
        (s) => s
          ..on<SelectFileEvent>(null, actions: [
            (ctx, event) =>
                ctx.copyWith(selectedFile: (event as SelectFileEvent).filename),
          ])
          ..on<RequestDownloadEvent>(
            'waitingForDownload',
            // Guard: only if a file is selected
            guard: (ctx, _) => ctx.selectedFile.isNotEmpty,
          ),
      )

      // WAITING FOR DOWNLOAD - Waiting for download machine to work
      ..state(
        'waitingForDownload',
        (s) => s
          ..on<RequestCancelEvent>('browsing')
          ..on<DownloadCompletedNotification>('showingResult', actions: [
            (ctx, event) => ctx.copyWith(
                  showCompletionDialog: true,
                  downloadCount: ctx.downloadCount + 1,
                ),
          ])
          ..on<DownloadErrorNotification>('showingError'),
      )

      // SHOWING RESULT - Download completed, showing success
      ..state(
        'showingResult',
        (s) => s
          ..on<DismissDialogEvent>('browsing', actions: [
            (ctx, _) => ctx.copyWith(
                  showCompletionDialog: false,
                  selectedFile: '',
                ),
          ])
          ..on<SelectFileEvent>('browsing', actions: [
            (ctx, event) {
              final e = event as SelectFileEvent;
              return ctx.copyWith(
                selectedFile: e.filename,
                showCompletionDialog: false,
              );
            },
          ]),
      )

      // SHOWING ERROR - Download failed, showing error
      ..state(
        'showingError',
        (s) => s
          ..on<RequestRetryEvent>('waitingForDownload')
          ..on<ResetUIEvent>('browsing', actions: [
            (ctx, _) => ctx.copyWith(selectedFile: ''),
          ]),
      ),
    id: 'ui',
  );
}

// ============================================================================
// COORDINATOR - Manages both machines and their communication
// ============================================================================

class MachineCoordinator {
  late final StateMachineActor<DownloadContext, DownloadEvent> downloadActor;
  late final StateMachineActor<UIContext, UIEvent> uiActor;

  final List<String> _files = [
    'document.pdf',
    'image.png',
    'video.mp4',
    'music.mp3',
    'fail_test.zip', // This one will fail (contains 'fail')
  ];

  List<String> get availableFiles => _files;

  void initialize() {
    // Create actors
    downloadActor = createDownloadMachine().createActor();
    uiActor = createUIMachine().createActor();

    // Set up communication: Download machine -> UI machine
    downloadActor.addListener(() {
      final downloadState = downloadActor.snapshot;

      // Notify UI when download completes
      if (downloadState.value.matches('completed')) {
        final filename = downloadState.context.filename ?? 'unknown';
        uiActor.send(DownloadCompletedNotification(filename));
      }

      // Notify UI when download fails
      if (downloadState.value.matches('error')) {
        final error = downloadState.context.error ?? 'Unknown error';
        uiActor.send(DownloadErrorNotification(error));
      }
    });

    // Start both machines
    downloadActor.start();
    uiActor.start();
  }

  // UI -> Download machine communication
  void startDownload(String filename, String url) {
    downloadActor.send(StartDownloadEvent(url: url, filename: filename));
    // Also trigger the simulation
    _simulateDownload(downloadActor, url);
  }

  void cancelDownload() {
    downloadActor.send(CancelDownloadEvent());
  }

  void retryDownload() {
    final ctx = downloadActor.snapshot.context;
    if (ctx.url != null) {
      downloadActor.send(RetryDownloadEvent());
      _simulateDownload(downloadActor, ctx.url!);
    }
  }

  void resetDownload() {
    downloadActor.send(ResetDownloadEvent());
  }

  void dispose() {
    _cancelSimulatedDownload();
    downloadActor.stop();
    uiActor.stop();
  }
}

// ============================================================================
// APP
// ============================================================================

void main() {
  runApp(const MultiMachineApp());
}

class MultiMachineApp extends StatelessWidget {
  const MultiMachineApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Step 8: Multi-Machine',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const DownloadScreen(),
    );
  }
}

class DownloadScreen extends StatefulWidget {
  const DownloadScreen({super.key});

  @override
  State<DownloadScreen> createState() => _DownloadScreenState();
}

class _DownloadScreenState extends State<DownloadScreen> {
  late final MachineCoordinator _coordinator;

  @override
  void initState() {
    super.initState();
    _coordinator = MachineCoordinator()..initialize();

    // Listen for changes to trigger rebuilds
    _coordinator.downloadActor.addListener(_onStateChange);
    _coordinator.uiActor.addListener(_onStateChange);
  }

  void _onStateChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _coordinator.downloadActor.removeListener(_onStateChange);
    _coordinator.uiActor.removeListener(_onStateChange);
    _coordinator.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final downloadState = _coordinator.downloadActor.snapshot;
    final uiState = _coordinator.uiActor.snapshot;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Step 8: Multi-Machine'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          // State indicators
          _buildStateIndicators(downloadState, uiState),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // File selection
                  _buildFileSelector(uiState),

                  const SizedBox(height: 24),

                  // Download progress
                  _buildDownloadProgress(downloadState),

                  const SizedBox(height: 24),

                  // Action buttons
                  _buildActionButtons(downloadState, uiState),

                  const Spacer(),

                  // Download counter
                  _buildDownloadCounter(uiState),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStateIndicators(
    StateSnapshot<DownloadContext> downloadState,
    StateSnapshot<UIContext> uiState,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.grey.shade100,
      child: Row(
        children: [
          Expanded(
            child: _StateChip(
              label: 'Download',
              state: downloadState.value.toString(),
              color: _getDownloadColor(downloadState),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _StateChip(
              label: 'UI',
              state: uiState.value.toString(),
              color: _getUIColor(uiState),
            ),
          ),
        ],
      ),
    );
  }

  Color _getDownloadColor(StateSnapshot<DownloadContext> state) {
    if (state.value.matches('downloading')) return Colors.blue;
    if (state.value.matches('completed')) return Colors.green;
    if (state.value.matches('error')) return Colors.red;
    return Colors.grey;
  }

  Color _getUIColor(StateSnapshot<UIContext> state) {
    if (state.value.matches('waitingForDownload')) return Colors.blue;
    if (state.value.matches('showingResult')) return Colors.green;
    if (state.value.matches('showingError')) return Colors.red;
    return Colors.grey;
  }

  Widget _buildFileSelector(StateSnapshot<UIContext> uiState) {
    final isEnabled = uiState.value.matches('browsing') ||
        uiState.value.matches('showingResult');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select a file to download:',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _coordinator.availableFiles.map((file) {
                final isSelected = uiState.context.selectedFile == file;
                final willFail = file.contains('fail');

                return FilterChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(file),
                      if (willFail) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.warning_amber,
                          size: 16,
                          color: Colors.orange.shade700,
                        ),
                      ],
                    ],
                  ),
                  selected: isSelected,
                  onSelected: isEnabled
                      ? (_) {
                          _coordinator.uiActor.send(SelectFileEvent(
                            filename: file,
                            url: 'https://example.com/$file',
                          ));
                        }
                      : null,
                );
              }).toList(),
            ),
            if (_coordinator.availableFiles.any((f) => f.contains('fail')))
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '* Files marked with warning will simulate a download failure',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.orange.shade700,
                      ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDownloadProgress(StateSnapshot<DownloadContext> downloadState) {
    final isDownloading = downloadState.value.matches('downloading');
    final isCompleted = downloadState.value.matches('completed');
    final isError = downloadState.value.matches('error');
    final progress = downloadState.context.progress;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Download Progress',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                if (isDownloading)
                  Text(
                    '${(progress * 100).toInt()}%',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.blue,
                        ),
                  ),
                if (isCompleted)
                  Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green),
                      const SizedBox(width: 4),
                      Text(
                        'Complete!',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Colors.green,
                                ),
                      ),
                    ],
                  ),
                if (isError)
                  Row(
                    children: [
                      const Icon(Icons.error, color: Colors.red),
                      const SizedBox(width: 4),
                      Text(
                        'Failed',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Colors.red,
                                ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: isDownloading ? progress : (isCompleted ? 1.0 : 0.0),
                minHeight: 12,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation(
                  isError
                      ? Colors.red
                      : isCompleted
                          ? Colors.green
                          : Colors.blue,
                ),
              ),
            ),
            if (downloadState.context.filename != null) ...[
              const SizedBox(height: 8),
              Text(
                'File: ${downloadState.context.filename}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (isError && downloadState.context.error != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  downloadState.context.error!,
                  style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(
    StateSnapshot<DownloadContext> downloadState,
    StateSnapshot<UIContext> uiState,
  ) {
    final canStartDownload = uiState.value.matches('browsing') &&
        uiState.context.selectedFile.isNotEmpty &&
        downloadState.value.matches('idle');

    final canCancel = downloadState.value.matches('downloading');
    final canRetry = downloadState.value.matches('error');
    final canReset = downloadState.value.matches('completed') ||
        downloadState.value.matches('error');

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: [
        // Start Download
        FilledButton.icon(
          onPressed: canStartDownload
              ? () {
                  final file = uiState.context.selectedFile;
                  _coordinator.uiActor.send(RequestDownloadEvent());
                  _coordinator.startDownload(
                    file,
                    'https://example.com/$file',
                  );
                }
              : null,
          icon: const Icon(Icons.download),
          label: const Text('Start Download'),
        ),

        // Cancel
        OutlinedButton.icon(
          onPressed: canCancel
              ? () {
                  _coordinator.uiActor.send(RequestCancelEvent());
                  _coordinator.cancelDownload();
                }
              : null,
          icon: const Icon(Icons.cancel),
          label: const Text('Cancel'),
        ),

        // Retry
        OutlinedButton.icon(
          onPressed: canRetry
              ? () {
                  _coordinator.uiActor.send(RequestRetryEvent());
                  _coordinator.retryDownload();
                }
              : null,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),

        // Reset
        TextButton.icon(
          onPressed: canReset
              ? () {
                  _coordinator.uiActor.send(ResetUIEvent());
                  _coordinator.resetDownload();
                }
              : null,
          icon: const Icon(Icons.restart_alt),
          label: const Text('Reset'),
        ),
      ],
    );
  }

  Widget _buildDownloadCounter(StateSnapshot<UIContext> uiState) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.indigo.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_done, color: Colors.indigo),
          const SizedBox(width: 8),
          Text(
            'Total Downloads: ${uiState.context.downloadCount}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.indigo,
                ),
          ),
        ],
      ),
    );
  }
}

class _StateChip extends StatelessWidget {
  final String label;
  final String state;
  final Color color;

  const _StateChip({
    required this.label,
    required this.state,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            state,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontFamily: 'monospace',
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

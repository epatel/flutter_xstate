/// Step 4: Media Player - Hierarchical/Nested States
///
/// Demonstrates:
/// - Compound states with nested children
/// - Parent state entry/exit actions
/// - Transitions between nested states
/// - State matching with dot notation (active.playing)
///
/// Run with: flutter run -d chrome

import 'package:flutter/material.dart';
import 'package:flutter_xstate/flutter_xstate.dart';

// ============================================================================
// CONTEXT
// ============================================================================

class PlayerContext {
  final String? currentTrack;
  final int position; // seconds
  final int duration; // seconds
  final double volume;

  const PlayerContext({
    this.currentTrack,
    this.position = 0,
    this.duration = 180, // 3 minutes default
    this.volume = 0.7,
  });

  PlayerContext copyWith({
    String? currentTrack,
    int? position,
    int? duration,
    double? volume,
    bool clearTrack = false,
  }) => PlayerContext(
    currentTrack: clearTrack ? null : (currentTrack ?? this.currentTrack),
    position: position ?? this.position,
    duration: duration ?? this.duration,
    volume: volume ?? this.volume,
  );

  String get positionDisplay {
    final mins = position ~/ 60;
    final secs = position % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  String get durationDisplay {
    final mins = duration ~/ 60;
    final secs = duration % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
}

// ============================================================================
// EVENTS
// ============================================================================

sealed class PlayerEvent extends XEvent {}

class LoadTrackEvent extends PlayerEvent {
  final String track;
  final int duration;

  LoadTrackEvent(this.track, {this.duration = 180});

  @override
  String get type => 'LOAD_TRACK';
}

class PlayEvent extends PlayerEvent {
  @override
  String get type => 'PLAY';
}

class PauseEvent extends PlayerEvent {
  @override
  String get type => 'PAUSE';
}

class StopEvent extends PlayerEvent {
  @override
  String get type => 'STOP';
}

class SeekEvent extends PlayerEvent {
  final int position;

  SeekEvent(this.position);

  @override
  String get type => 'SEEK';
}

class VolumeEvent extends PlayerEvent {
  final double volume;

  VolumeEvent(this.volume);

  @override
  String get type => 'VOLUME';
}

class TickEvent extends PlayerEvent {
  @override
  String get type => 'TICK';
}

// ============================================================================
// STATE MACHINE
// ============================================================================

final playerMachine = StateMachine.create<PlayerContext, PlayerEvent>(
  (m) => m
    ..context(const PlayerContext())
    ..initial('stopped')
    // STOPPED - No track loaded or playback stopped
    ..state(
      'stopped',
      (s) => s
        ..entry([(ctx, _) => ctx.copyWith(position: 0, clearTrack: true)])
        ..on<LoadTrackEvent>(
          'active.paused',
          actions: [
            (ctx, event) {
              final e = event as LoadTrackEvent;
              return ctx.copyWith(
                currentTrack: e.track,
                duration: e.duration,
                position: 0,
              );
            },
          ],
        ),
    )
    // ACTIVE - Compound state containing playing/paused
    ..state(
      'active',
      (s) => s
        ..initial('paused') // Default child state
        // Entry action for the parent state
        ..entry([
          (ctx, _) {
            debugPrint('Entered active state');
            return ctx;
          },
        ])
        // Exit action for the parent state
        ..exit([
          (ctx, _) {
            debugPrint('Exited active state');
            return ctx;
          },
        ])
        // These transitions are available in ANY child state
        ..on<StopEvent>('stopped')
        ..on<LoadTrackEvent>(
          'active.paused',
          actions: [
            (ctx, event) {
              final e = event as LoadTrackEvent;
              return ctx.copyWith(
                currentTrack: e.track,
                duration: e.duration,
                position: 0,
              );
            },
          ],
        )
        ..on<SeekEvent>(
          null,
          actions: [
            (ctx, event) {
              final e = event as SeekEvent;
              return ctx.copyWith(position: e.position.clamp(0, ctx.duration));
            },
          ],
        )
        ..on<VolumeEvent>(
          null,
          actions: [
            (ctx, event) {
              final e = event as VolumeEvent;
              return ctx.copyWith(volume: e.volume.clamp(0.0, 1.0));
            },
          ],
        )
        // PLAYING - Nested state
        ..state(
          'playing',
          (child) => child
            ..on<PauseEvent>('active.paused')
            ..on<TickEvent>(
              null,
              actions: [
                (ctx, _) {
                  final newPos = ctx.position + 1;
                  if (newPos >= ctx.duration) {
                    return ctx.copyWith(position: ctx.duration);
                  }
                  return ctx.copyWith(position: newPos);
                },
              ],
            ),
        )
        // PAUSED - Nested state
        ..state('paused', (child) => child..on<PlayEvent>('active.playing')),
    ),
  id: 'player',
);

// ============================================================================
// APP
// ============================================================================

void main() {
  runApp(const PlayerApp());
}

class PlayerApp extends StatelessWidget {
  const PlayerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Step 4: Media Player',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.purple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: StateMachineProvider<PlayerContext, PlayerEvent>(
        machine: playerMachine,
        autoStart: true,
        child: const PlayerScreen(),
      ),
    );
  }
}

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: const Text('Step 4: Hierarchical States'),
        backgroundColor: Colors.transparent,
      ),
      body: Center(
        child: StateMachineBuilder<PlayerContext, PlayerEvent>(
          builder: (context, state, send) {
            final ctx = state.context;
            final isStopped = state.value.matches('stopped');
            final isActive = state.value.matches('active');
            final isPlaying = state.value.matches('active.playing');
            final isPaused = state.value.matches('active.paused');

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // State visualization
                  _StateTree(
                    isStopped: isStopped,
                    isActive: isActive,
                    isPlaying: isPlaying,
                    isPaused: isPaused,
                  ),
                  const SizedBox(height: 32),

                  // Player card
                  Container(
                    constraints: const BoxConstraints(maxWidth: 400),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.grey[850],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        // Album art placeholder
                        Container(
                          width: 200,
                          height: 200,
                          decoration: BoxDecoration(
                            color: isActive
                                ? Colors.purple.withValues(alpha: 0.3)
                                : Colors.grey[800],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            isPlaying ? Icons.music_note : Icons.album,
                            size: 80,
                            color: isActive ? Colors.purple : Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Track name
                        Text(
                          ctx.currentTrack ?? 'No track loaded',
                          style: Theme.of(context).textTheme.titleLarge,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),

                        // Progress bar (only when active)
                        if (isActive) ...[
                          Row(
                            children: [
                              Text(
                                ctx.positionDisplay,
                                style: TextStyle(color: Colors.grey[400]),
                              ),
                              Expanded(
                                child: Slider(
                                  value: ctx.position.toDouble(),
                                  max: ctx.duration.toDouble(),
                                  onChanged: (v) => send(SeekEvent(v.toInt())),
                                ),
                              ),
                              Text(
                                ctx.durationDisplay,
                                style: TextStyle(color: Colors.grey[400]),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Volume
                          Row(
                            children: [
                              Icon(Icons.volume_down, color: Colors.grey[400]),
                              Expanded(
                                child: Slider(
                                  value: ctx.volume,
                                  onChanged: (v) => send(VolumeEvent(v)),
                                ),
                              ),
                              Icon(Icons.volume_up, color: Colors.grey[400]),
                            ],
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Controls
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Stop button
                            IconButton(
                              onPressed: isActive
                                  ? () => send(StopEvent())
                                  : null,
                              icon: const Icon(Icons.stop),
                              iconSize: 32,
                            ),
                            const SizedBox(width: 16),

                            // Play/Pause button
                            IconButton.filled(
                              onPressed: () {
                                if (isStopped) {
                                  // Load a sample track
                                  send(
                                    LoadTrackEvent(
                                      'Sample Track',
                                      duration: 180,
                                    ),
                                  );
                                } else if (isPlaying) {
                                  send(PauseEvent());
                                } else {
                                  send(PlayEvent());
                                }
                              },
                              icon: Icon(
                                isStopped
                                    ? Icons.play_arrow
                                    : isPlaying
                                    ? Icons.pause
                                    : Icons.play_arrow,
                              ),
                              iconSize: 48,
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.purple,
                                foregroundColor: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 16),

                            // Tick button (simulate time passing)
                            IconButton(
                              onPressed: isPlaying
                                  ? () => send(TickEvent())
                                  : null,
                              icon: const Icon(Icons.fast_forward),
                              iconSize: 32,
                              tooltip: 'Advance 1 second',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Track list
                  Container(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sample Tracks',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        _TrackTile(
                          title: 'Ambient Dreams',
                          duration: 240,
                          onTap: () => send(
                            LoadTrackEvent('Ambient Dreams', duration: 240),
                          ),
                        ),
                        _TrackTile(
                          title: 'Electronic Pulse',
                          duration: 180,
                          onTap: () => send(
                            LoadTrackEvent('Electronic Pulse', duration: 180),
                          ),
                        ),
                        _TrackTile(
                          title: 'Acoustic Session',
                          duration: 300,
                          onTap: () => send(
                            LoadTrackEvent('Acoustic Session', duration: 300),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // State indicator
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'State: ${state.value}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _StateTree extends StatelessWidget {
  final bool isStopped;
  final bool isActive;
  final bool isPlaying;
  final bool isPaused;

  const _StateTree({
    required this.isStopped,
    required this.isActive,
    required this.isPlaying,
    required this.isPaused,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[700]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'State Hierarchy',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(color: Colors.grey[400]),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Stopped state
              _StateBox(
                label: 'stopped',
                isActive: isStopped,
                color: Colors.red,
              ),
              const SizedBox(width: 16),
              // Active compound state
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isActive
                      ? Colors.purple.withValues(alpha: 0.2)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isActive ? Colors.purple : Colors.grey[600]!,
                    width: isActive ? 2 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'active',
                      style: TextStyle(
                        color: isActive ? Colors.purple : Colors.grey[500],
                        fontWeight: isActive
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _StateBox(
                          label: 'playing',
                          isActive: isPlaying,
                          color: Colors.green,
                        ),
                        const SizedBox(width: 8),
                        _StateBox(
                          label: 'paused',
                          isActive: isPaused,
                          color: Colors.orange,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StateBox extends StatelessWidget {
  final String label;
  final bool isActive;
  final Color color;

  const _StateBox({
    required this.label,
    required this.isActive,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isActive ? color.withValues(alpha: 0.2) : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isActive ? color : Colors.grey[600]!,
          width: isActive ? 2 : 1,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isActive ? color : Colors.grey[500],
          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _TrackTile extends StatelessWidget {
  final String title;
  final int duration;
  final VoidCallback onTap;

  const _TrackTile({
    required this.title,
    required this.duration,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final mins = duration ~/ 60;
    final secs = duration % 60;
    final durationStr =
        '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';

    return ListTile(
      leading: const Icon(Icons.music_note),
      title: Text(title),
      trailing: Text(durationStr, style: TextStyle(color: Colors.grey[400])),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}

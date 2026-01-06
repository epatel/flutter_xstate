import 'package:flutter/material.dart';

import '../core/state_config.dart';
import '../core/state_machine.dart';
import '../core/state_machine_actor.dart';
import '../events/x_event.dart';
import 'state_machine_inspector.dart';

/// A visual debugging panel for state machines.
///
/// Displays:
/// - Live state visualization
/// - Transition history timeline
/// - Current context
/// - Statistics
///
/// Example:
/// ```dart
/// StateMachineInspectorPanel<AuthContext, AuthEvent>(
///   actor: authActor,
///   machine: authMachine,
/// )
/// ```
class StateMachineInspectorPanel<TContext, TEvent extends XEvent>
    extends StatefulWidget {
  /// The state machine actor to inspect.
  final StateMachineActor<TContext, TEvent> actor;

  /// The state machine definition (for showing structure).
  final StateMachine<TContext, TEvent> machine;

  /// Inspector configuration.
  final InspectorConfig config;

  /// Optional event builders for the event sender.
  /// Maps event type names to builder functions.
  final Map<String, TEvent Function()>? eventBuilders;

  /// Whether to show in compact mode.
  final bool compact;

  /// Custom context formatter.
  final String Function(TContext)? contextFormatter;

  const StateMachineInspectorPanel({
    super.key,
    required this.actor,
    required this.machine,
    this.config = const InspectorConfig(),
    this.eventBuilders,
    this.compact = false,
    this.contextFormatter,
  });

  @override
  State<StateMachineInspectorPanel<TContext, TEvent>> createState() =>
      _StateMachineInspectorPanelState<TContext, TEvent>();
}

class _StateMachineInspectorPanelState<TContext, TEvent extends XEvent>
    extends State<StateMachineInspectorPanel<TContext, TEvent>> {
  late StateMachineInspector<TContext, TEvent> _inspector;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _inspector = StateMachineInspector<TContext, TEvent>(config: widget.config);
    _inspector.attach(widget.actor);
  }

  @override
  void didUpdateWidget(StateMachineInspectorPanel<TContext, TEvent> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.actor != widget.actor) {
      _inspector.detach();
      _inspector.attach(widget.actor);
    }
  }

  @override
  void dispose() {
    _inspector.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _inspector,
      builder: (context, _) {
        if (widget.compact) {
          return _buildCompactView(context);
        }
        return _buildFullView(context);
      },
    );
  }

  Widget _buildCompactView(BuildContext context) {
    final currentState = _inspector.currentStateValue ?? 'unknown';
    final history = _inspector.lastTransitions(3);

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.bug_report, size: 16, color: Colors.green[400]),
              const SizedBox(width: 8),
              Text(
                'State: ',
                style: TextStyle(color: Colors.grey[400], fontSize: 12),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.blue),
                ),
                child: Text(
                  currentState,
                  style: const TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '${_inspector.history.length} transitions',
                style: TextStyle(color: Colors.grey[500], fontSize: 10),
              ),
            ],
          ),
          if (history.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...history.reversed.map((record) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    '${record.event?.type ?? '?'}: ${record.previousState.value} → ${record.nextState.value}',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 10,
                      fontFamily: 'monospace',
                    ),
                  ),
                )),
          ],
        ],
      ),
    );
  }

  Widget _buildFullView(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[700]!),
      ),
      child: Column(
        children: [
          _buildHeader(context),
          _buildTabBar(context),
          Expanded(
            child: _buildTabContent(context),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final currentState = _inspector.currentStateValue ?? 'unknown';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Row(
        children: [
          Icon(Icons.bug_report, color: Colors.green[400]),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'State Machine Inspector',
                style: TextStyle(
                  color: Colors.grey[300],
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                widget.machine.id,
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.blue),
            ),
            child: Text(
              currentState,
              style: const TextStyle(
                color: Colors.blue,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(BuildContext context) {
    final tabs = ['States', 'History', 'Context', 'Stats'];
    if (widget.eventBuilders != null && widget.eventBuilders!.isNotEmpty) {
      tabs.add('Events');
    }

    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[700]!)),
      ),
      child: Row(
        children: tabs.asMap().entries.map((entry) {
          final index = entry.key;
          final label = entry.value;
          final isSelected = index == _selectedTab;

          return Expanded(
            child: InkWell(
              onTap: () => setState(() => _selectedTab = index),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isSelected ? Colors.blue : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isSelected ? Colors.blue : Colors.grey[500],
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTabContent(BuildContext context) {
    switch (_selectedTab) {
      case 0:
        return _StateTreeView<TContext, TEvent>(
          machine: widget.machine,
          currentState: _inspector.currentStateValue,
        );
      case 1:
        return _TransitionHistoryView<TContext>(
          history: _inspector.history,
          onClear: () => _inspector.clearHistory(),
        );
      case 2:
        return _ContextView<TContext>(
          context: widget.actor.snapshot.context,
          formatter: widget.contextFormatter,
        );
      case 3:
        return _StatsView(stats: _inspector.stats);
      case 4:
        if (widget.eventBuilders != null) {
          return _EventSenderView<TEvent>(
            eventBuilders: widget.eventBuilders!,
            onSend: widget.actor.send,
          );
        }
        return const SizedBox.shrink();
      default:
        return const SizedBox.shrink();
    }
  }
}

// =============================================================================
// STATE TREE VIEW
// =============================================================================

class _StateTreeView<TContext, TEvent extends XEvent> extends StatelessWidget {
  final StateMachine<TContext, TEvent> machine;
  final String? currentState;

  const _StateTreeView({
    required this.machine,
    required this.currentState,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: _buildStateNode(context, machine.root, 0),
    );
  }

  Widget _buildStateNode(
    BuildContext context,
    StateConfig<TContext, TEvent> config,
    int depth,
  ) {
    final isActive = currentState?.startsWith(config.id) ?? false;
    final isExactMatch = currentState == config.id ||
        currentState?.split('.').last == config.id;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: depth * 20.0),
          child: Row(
            children: [
              // Connection line
              if (depth > 0) ...[
                Container(
                  width: 16,
                  height: 2,
                  color: Colors.grey[700],
                ),
                const SizedBox(width: 4),
              ],
              // State box
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isExactMatch
                      ? Colors.green.withValues(alpha: 0.2)
                      : isActive
                          ? Colors.blue.withValues(alpha: 0.1)
                          : Colors.grey[800],
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isExactMatch
                        ? Colors.green
                        : isActive
                            ? Colors.blue
                            : Colors.grey[600]!,
                    width: isExactMatch ? 2 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _getStateIcon(config.type, isActive),
                    const SizedBox(width: 8),
                    Text(
                      config.id,
                      style: TextStyle(
                        color: isExactMatch
                            ? Colors.green
                            : isActive
                                ? Colors.blue
                                : Colors.grey[400],
                        fontWeight: isExactMatch || isActive
                            ? FontWeight.bold
                            : FontWeight.normal,
                        fontFamily: 'monospace',
                      ),
                    ),
                    if (config.type == StateType.compound ||
                        config.type == StateType.parallel) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey[700],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          config.type == StateType.parallel
                              ? 'parallel'
                              : 'compound',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                    if (config.type == StateType.final_) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'final',
                          style: TextStyle(
                            color: Colors.orange,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Transitions badge
              if (config.on.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${config.on.length} events',
                    style: const TextStyle(
                      color: Colors.purple,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        // Child states
        if (config.states.isNotEmpty) ...[
          const SizedBox(height: 8),
          ...config.states.values
              .map((child) => _buildStateNode(context, child, depth + 1)),
        ],
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _getStateIcon(StateType type, bool isActive) {
    final color = isActive ? Colors.blue : Colors.grey[500];

    switch (type) {
      case StateType.atomic:
        return Icon(Icons.circle, size: 12, color: color);
      case StateType.compound:
        return Icon(Icons.folder_outlined, size: 14, color: color);
      case StateType.parallel:
        return Icon(Icons.view_column, size: 14, color: color);
      case StateType.final_:
        return Icon(Icons.stop_circle_outlined, size: 14, color: color);
      case StateType.history:
        return Icon(Icons.history, size: 14, color: color);
    }
  }
}

// =============================================================================
// TRANSITION HISTORY VIEW
// =============================================================================

class _TransitionHistoryView<TContext> extends StatelessWidget {
  final List<TransitionRecord<TContext>> history;
  final VoidCallback onClear;

  const _TransitionHistoryView({
    required this.history,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 48, color: Colors.grey[700]),
            const SizedBox(height: 16),
            Text(
              'No transitions yet',
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Text(
                '${history.length} transitions',
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: onClear,
                icon: const Icon(Icons.clear_all, size: 16),
                label: const Text('Clear'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey[400],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: history.length,
            itemBuilder: (context, index) {
              final record = history[history.length - 1 - index];
              return _TransitionTile(record: record, index: index);
            },
          ),
        ),
      ],
    );
  }
}

class _TransitionTile<TContext> extends StatelessWidget {
  final TransitionRecord<TContext> record;
  final int index;

  const _TransitionTile({required this.record, required this.index});

  @override
  Widget build(BuildContext context) {
    final timeStr =
        '${record.timestamp.hour.toString().padLeft(2, '0')}:${record.timestamp.minute.toString().padLeft(2, '0')}:${record.timestamp.second.toString().padLeft(2, '0')}.${record.timestamp.millisecond.toString().padLeft(3, '0')}';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[700]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  record.event?.type ?? 'INIT',
                  style: const TextStyle(
                    color: Colors.purple,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              const Spacer(),
              Text(
                timeStr,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 10,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    record.previousState.value.toString(),
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.arrow_forward, color: Colors.grey[600], size: 16),
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    record.nextState.value.toString(),
                    style: const TextStyle(
                      color: Colors.blue,
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (record.duration.inMicroseconds > 0) ...[
            const SizedBox(height: 4),
            Text(
              '${record.duration.inMicroseconds}µs',
              style: TextStyle(color: Colors.grey[600], fontSize: 10),
            ),
          ],
        ],
      ),
    );
  }
}

// =============================================================================
// CONTEXT VIEW
// =============================================================================

class _ContextView<TContext> extends StatelessWidget {
  final TContext context;
  final String Function(TContext)? formatter;

  const _ContextView({
    required this.context,
    this.formatter,
  });

  @override
  Widget build(BuildContext context_) {
    final contextStr = formatter?.call(context) ?? context.toString();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.data_object, color: Colors.grey[500], size: 16),
              const SizedBox(width: 8),
              Text(
                'Current Context',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[850],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[700]!),
            ),
            child: SelectableText(
              contextStr,
              style: TextStyle(
                color: Colors.grey[300],
                fontFamily: 'monospace',
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// STATS VIEW
// =============================================================================

class _StatsView extends StatelessWidget {
  final InspectorStats stats;

  const _StatsView({required this.stats});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StatCard(
            icon: Icons.swap_horiz,
            label: 'Total Transitions',
            value: stats.totalTransitions.toString(),
            color: Colors.blue,
          ),
          const SizedBox(height: 12),
          _StatCard(
            icon: Icons.timer,
            label: 'Avg. Duration',
            value: '${stats.averageTransitionDuration.inMicroseconds}µs',
            color: Colors.green,
          ),
          const SizedBox(height: 16),
          Text(
            'Events',
            style: TextStyle(
              color: Colors.grey[400],
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ...stats.eventCounts.entries.map((e) => _CountBar(
                label: e.key,
                count: e.value,
                total: stats.totalTransitions,
                color: Colors.purple,
              )),
          const SizedBox(height: 16),
          Text(
            'States Entered',
            style: TextStyle(
              color: Colors.grey[400],
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ...stats.stateCounts.entries.map((e) => _CountBar(
                label: e.key,
                count: e.value,
                total: stats.totalTransitions,
                color: Colors.teal,
              )),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(color: Colors.grey[400], fontSize: 12),
              ),
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CountBar extends StatelessWidget {
  final String label;
  final int count;
  final int total;
  final Color color;

  const _CountBar({
    required this.label,
    required this.count,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = total > 0 ? count / total : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              Text(
                '$count',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: percentage,
              backgroundColor: Colors.grey[800],
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// EVENT SENDER VIEW
// =============================================================================

class _EventSenderView<TEvent extends XEvent> extends StatelessWidget {
  final Map<String, TEvent Function()> eventBuilders;
  final void Function(TEvent) onSend;

  const _EventSenderView({
    required this.eventBuilders,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.send, color: Colors.grey[500], size: 16),
              const SizedBox(width: 8),
              Text(
                'Send Event',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: eventBuilders.entries.map((entry) {
              return ElevatedButton(
                onPressed: () => onSend(entry.value()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple.withValues(alpha: 0.2),
                  foregroundColor: Colors.purple,
                  side: const BorderSide(color: Colors.purple),
                ),
                child: Text(entry.key),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// OVERLAY INSPECTOR
// =============================================================================

/// A floating inspector button that opens a draggable inspector panel.
///
/// Add this to your widget tree during development:
/// ```dart
/// Stack(
///   children: [
///     MyApp(),
///     if (kDebugMode)
///       InspectorOverlay(
///         actor: authActor,
///         machine: authMachine,
///       ),
///   ],
/// )
/// ```
class InspectorOverlay<TContext, TEvent extends XEvent> extends StatefulWidget {
  final StateMachineActor<TContext, TEvent> actor;
  final StateMachine<TContext, TEvent> machine;
  final Map<String, TEvent Function()>? eventBuilders;
  final String Function(TContext)? contextFormatter;

  const InspectorOverlay({
    super.key,
    required this.actor,
    required this.machine,
    this.eventBuilders,
    this.contextFormatter,
  });

  @override
  State<InspectorOverlay<TContext, TEvent>> createState() =>
      _InspectorOverlayState<TContext, TEvent>();
}

class _InspectorOverlayState<TContext, TEvent extends XEvent>
    extends State<InspectorOverlay<TContext, TEvent>> {
  bool _isExpanded = false;
  Offset _position = const Offset(16, 100);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Expanded panel
        if (_isExpanded)
          Positioned(
            left: 16,
            right: 16,
            top: 100,
            bottom: 100,
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(12),
              child: StateMachineInspectorPanel<TContext, TEvent>(
                actor: widget.actor,
                machine: widget.machine,
                eventBuilders: widget.eventBuilders,
                contextFormatter: widget.contextFormatter,
              ),
            ),
          ),
        // FAB
        Positioned(
          left: _position.dx,
          top: _position.dy,
          child: GestureDetector(
            onPanUpdate: (details) {
              setState(() {
                _position += details.delta;
              });
            },
            child: FloatingActionButton.small(
              onPressed: () => setState(() => _isExpanded = !_isExpanded),
              backgroundColor:
                  _isExpanded ? Colors.red[700] : Colors.green[700],
              child: Icon(_isExpanded ? Icons.close : Icons.bug_report),
            ),
          ),
        ),
      ],
    );
  }
}

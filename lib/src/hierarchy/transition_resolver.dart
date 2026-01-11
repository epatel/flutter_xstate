import 'package:meta/meta.dart';

import '../core/state_config.dart';
import '../core/state_snapshot.dart';
import '../core/state_value.dart';
import '../core/transition.dart';
import '../events/x_event.dart';
import 'state_node.dart';

/// Result of resolving a transition.
@immutable
class ResolvedTransition<TContext, TEvent extends XEvent> {
  /// States to exit, in order (innermost to outermost).
  final List<StateConfig<TContext, TEvent>> exitStates;

  /// The transition being taken.
  final Transition<TContext, TEvent> transition;

  /// States to enter, in order (outermost to innermost).
  final List<StateConfig<TContext, TEvent>> entryStates;

  /// The final target state value.
  final StateValue targetValue;

  /// Updated history values.
  final Map<String, StateValue> historyUpdates;

  const ResolvedTransition({
    required this.exitStates,
    required this.transition,
    required this.entryStates,
    required this.targetValue,
    this.historyUpdates = const {},
  });
}

/// Resolves transitions in hierarchical state machines.
///
/// Handles:
/// - LCA calculation for proper entry/exit ordering
/// - History state resolution
/// - Nested target resolution
class TransitionResolver<TContext, TEvent extends XEvent> {
  final StateConfig<TContext, TEvent> root;

  const TransitionResolver(this.root);

  /// Resolve a transition and compute entry/exit states.
  ResolvedTransition<TContext, TEvent>? resolve(
    StateSnapshot<TContext> currentSnapshot,
    StateConfig<TContext, TEvent> sourceConfig,
    Transition<TContext, TEvent> transition,
    TEvent event,
  ) {
    // Build path to current state
    final sourcePath = StateHierarchy.buildPath(currentSnapshot.value, root);

    // Determine target
    final targetId = transition.target ?? sourceConfig.id;

    // Find target config
    final targetConfig = _findStateConfigById(targetId);
    if (targetConfig == null) {
      throw StateError('Target state "$targetId" not found');
    }

    // Resolve target value (handles history states)
    final targetValue = _resolveTargetValue(
      targetId,
      targetConfig,
      currentSnapshot.historyValue,
    );

    // Build path to target state
    final targetPath = StateHierarchy.buildPath(targetValue, root);

    // Calculate exit and entry states
    final exitStates = StateHierarchy.getExitStates(
      sourcePath,
      targetPath,
      internal: transition.internal,
    );

    final entryStates = StateHierarchy.getEntryStates(
      sourcePath,
      targetPath,
      internal: transition.internal,
    );

    // Record history for exited compound states
    final historyUpdates = _recordExitHistory(
      exitStates,
      currentSnapshot.value,
    );

    return ResolvedTransition(
      exitStates: exitStates,
      transition: transition,
      entryStates: entryStates,
      targetValue: targetValue,
      historyUpdates: historyUpdates,
    );
  }

  /// Execute a resolved transition and return the updated context.
  TContext executeTransition(
    ResolvedTransition<TContext, TEvent> resolved,
    TContext context,
    TEvent event,
  ) {
    var currentContext = context;

    // Execute exit actions (innermost to outermost)
    for (final config in resolved.exitStates) {
      currentContext = config.executeExit(currentContext, event);
    }

    // Execute transition actions
    currentContext = resolved.transition.executeActions(currentContext, event);

    // Execute entry actions (outermost to innermost)
    for (final config in resolved.entryStates) {
      currentContext = config.executeEntry(currentContext, event);
    }

    return currentContext;
  }

  /// Resolve the target state value, handling history states.
  StateValue _resolveTargetValue(
    String targetId,
    StateConfig<TContext, TEvent> targetConfig,
    Map<String, StateValue> historyValue,
  ) {
    // Check if target is a history state
    if (targetConfig.isHistory) {
      return _resolveHistoryTarget(targetConfig, historyValue);
    }

    // Check if target is nested (contains dot)
    if (targetId.contains('.')) {
      return _resolveNestedTarget(targetId);
    }

    // Build full state value from root
    return _buildFullStateValue(targetId, targetConfig);
  }

  /// Resolve a history state target.
  StateValue _resolveHistoryTarget(
    StateConfig<TContext, TEvent> historyConfig,
    Map<String, StateValue> historyValue,
  ) {
    // Find parent of history state
    final parent = _findParentConfig(historyConfig.id);
    if (parent == null) {
      throw StateError(
        'History state "${historyConfig.id}" must be a child of a compound state',
      );
    }

    final parentPath = parent.id;
    final recorded = historyValue[parentPath];

    if (recorded != null) {
      // Restore from history
      if (historyConfig.deepHistory) {
        // Deep history: restore entire subtree
        return _wrapInParent(recorded, parent);
      } else {
        // Shallow history: restore only immediate child, then initial
        final childId = _getStateId(recorded);
        final childConfig = parent.states[childId];
        if (childConfig != null) {
          return _buildFullStateValue(childId, childConfig, parent: parent);
        }
      }
    }

    // No history or history config has default
    final defaultTarget = historyConfig.historyDefault ?? parent.initial;
    if (defaultTarget != null) {
      final defaultConfig = parent.states[defaultTarget];
      if (defaultConfig != null) {
        return _buildFullStateValue(
          defaultTarget,
          defaultConfig,
          parent: parent,
        );
      }
    }

    throw StateError(
      'History state "${historyConfig.id}" has no recorded history and no default',
    );
  }

  /// Resolve a nested target like 'parent.child.grandchild'.
  StateValue _resolveNestedTarget(String targetId) {
    final parts = targetId.split('.');
    StateConfig<TContext, TEvent>? current = root;

    for (final part in parts) {
      if (current == null) break;

      if (current.id == part) {
        continue;
      }

      current = current.states[part];
    }

    if (current == null) {
      throw StateError('Target state "$targetId" not found');
    }

    return _buildFullStateValue(current.id, current);
  }

  /// Build a full state value from the root to the target.
  StateValue _buildFullStateValue(
    String targetId,
    StateConfig<TContext, TEvent> targetConfig, {
    StateConfig<TContext, TEvent>? parent,
  }) {
    // Get the initial value for the target (handles compound states)
    final targetValue = _resolveInitialValue(targetConfig);

    // If we have a specific parent, wrap in that
    if (parent != null) {
      return CompoundStateValue(parent.id, targetValue);
    }

    // Otherwise, we need to find the path from root to target and build it
    final path = _findPathToState(targetId);
    if (path.isEmpty) {
      return targetValue;
    }

    // Build compound value from root
    StateValue current = targetValue;
    for (int i = path.length - 2; i >= 0; i--) {
      current = CompoundStateValue(path[i].id, current);
    }

    return current;
  }

  /// Find the path from root to a state.
  List<StateConfig<TContext, TEvent>> _findPathToState(String stateId) {
    final path = <StateConfig<TContext, TEvent>>[];
    _findPath(root, stateId, path);
    return path;
  }

  bool _findPath(
    StateConfig<TContext, TEvent> config,
    String targetId,
    List<StateConfig<TContext, TEvent>> path,
  ) {
    path.add(config);

    if (config.id == targetId) {
      return true;
    }

    for (final child in config.states.values) {
      if (_findPath(child, targetId, path)) {
        return true;
      }
    }

    path.removeLast();
    return false;
  }

  /// Resolve initial value for a state config.
  StateValue _resolveInitialValue(StateConfig<TContext, TEvent> config) {
    switch (config.type) {
      case StateType.atomic:
      case StateType.final_:
      case StateType.history:
        return AtomicStateValue(config.id);

      case StateType.compound:
        if (config.initial == null) {
          throw StateError(
            'Compound state "${config.id}" must have an initial child state',
          );
        }
        final childConfig = config.states[config.initial];
        if (childConfig == null) {
          throw StateError(
            'Initial state "${config.initial}" not found in "${config.id}"',
          );
        }
        return CompoundStateValue(config.id, _resolveInitialValue(childConfig));

      case StateType.parallel:
        final regions = <String, StateValue>{};
        for (final entry in config.states.entries) {
          regions[entry.key] = _resolveInitialValue(entry.value);
        }
        return ParallelStateValue(config.id, regions);
    }
  }

  /// Wrap a state value in a parent compound state.
  StateValue _wrapInParent(
    StateValue value,
    StateConfig<TContext, TEvent> parent,
  ) {
    return CompoundStateValue(parent.id, value);
  }

  /// Record history for exited compound states.
  Map<String, StateValue> _recordExitHistory(
    List<StateConfig<TContext, TEvent>> exitStates,
    StateValue currentValue,
  ) {
    final updates = <String, StateValue>{};

    // For each compound state we're exiting, record its current child
    for (final config in exitStates) {
      if (config.isCompound) {
        // Find the child state value
        final childValue = _findChildValue(currentValue, config.id);
        if (childValue != null) {
          updates[config.id] = childValue;
        }
      }
    }

    return updates;
  }

  /// Find the child value of a compound state within a state value.
  StateValue? _findChildValue(StateValue value, String parentId) {
    switch (value) {
      case AtomicStateValue():
        return null;

      case CompoundStateValue(:final id, :final child):
        if (id == parentId) {
          return child;
        }
        return _findChildValue(child, parentId);

      case ParallelStateValue(:final regions):
        for (final region in regions.values) {
          final found = _findChildValue(region, parentId);
          if (found != null) return found;
        }
        return null;
    }
  }

  /// Find a state config by ID.
  /// Supports dot-notation paths like "parent.child.grandchild".
  StateConfig<TContext, TEvent>? _findStateConfigById(String id) {
    // Handle dot-notation paths (e.g., "checkout.processing")
    if (id.contains('.')) {
      final parts = id.split('.');
      StateConfig<TContext, TEvent>? current = root;

      for (final part in parts) {
        if (current == null) return null;

        // Search in current's children
        StateConfig<TContext, TEvent>? found;
        for (final child in current.states.values) {
          if (child.id == part) {
            found = child;
            break;
          }
        }

        // Try searching the entire subtree for the part
        found ??= _searchStateConfig(current, part);

        current = found;
      }

      return current;
    }

    // Simple ID without dots - search recursively
    return _searchStateConfig(root, id);
  }

  StateConfig<TContext, TEvent>? _searchStateConfig(
    StateConfig<TContext, TEvent> config,
    String id,
  ) {
    if (config.id == id) return config;

    for (final child in config.states.values) {
      final found = _searchStateConfig(child, id);
      if (found != null) return found;
    }

    return null;
  }

  /// Find the parent config of a state.
  StateConfig<TContext, TEvent>? _findParentConfig(String childId) {
    return _searchForParent(root, childId);
  }

  StateConfig<TContext, TEvent>? _searchForParent(
    StateConfig<TContext, TEvent> config,
    String childId,
  ) {
    if (config.states.containsKey(childId)) {
      return config;
    }

    for (final child in config.states.values) {
      final found = _searchForParent(child, childId);
      if (found != null) return found;
    }

    return null;
  }

  /// Get the state ID from a state value.
  String _getStateId(StateValue value) {
    return switch (value) {
      AtomicStateValue(:final id) => id,
      CompoundStateValue(:final id) => id,
      ParallelStateValue(:final id) => id,
    };
  }
}

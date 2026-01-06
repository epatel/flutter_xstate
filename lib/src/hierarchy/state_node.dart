import 'package:meta/meta.dart';

import '../core/state_config.dart';
import '../core/state_value.dart';
import '../events/x_event.dart';

/// Represents a path through the state hierarchy.
///
/// Used for calculating transitions between nested states,
/// determining entry/exit order, and finding the LCA.
@immutable
class StatePath<TContext, TEvent extends XEvent> {
  /// The sequence of state configs from root to leaf.
  final List<StateConfig<TContext, TEvent>> configs;

  const StatePath(this.configs);

  /// Create an empty path.
  const StatePath.empty() : configs = const [];

  /// The depth of this path (number of states).
  int get depth => configs.length;

  /// Whether this path is empty.
  bool get isEmpty => configs.isEmpty;

  /// Whether this path is not empty.
  bool get isNotEmpty => configs.isNotEmpty;

  /// The leaf (innermost) state config.
  StateConfig<TContext, TEvent>? get leaf =>
      configs.isNotEmpty ? configs.last : null;

  /// The root (outermost) state config.
  StateConfig<TContext, TEvent>? get root =>
      configs.isNotEmpty ? configs.first : null;

  /// Get the state ID at the given depth.
  String? idAt(int depth) =>
      depth < configs.length ? configs[depth].id : null;

  /// Get the config at the given depth.
  StateConfig<TContext, TEvent>? configAt(int depth) =>
      depth < configs.length ? configs[depth] : null;

  /// Whether this path contains the given state ID.
  bool contains(String stateId) =>
      configs.any((config) => config.id == stateId);

  /// Get the index of a state ID in this path, or -1 if not found.
  int indexOf(String stateId) =>
      configs.indexWhere((config) => config.id == stateId);

  /// Get a subpath from the start to the given depth (exclusive).
  StatePath<TContext, TEvent> subpath(int endDepth) {
    if (endDepth >= configs.length) return this;
    return StatePath(configs.sublist(0, endDepth));
  }

  /// Get all state IDs in this path.
  List<String> get stateIds => configs.map((c) => c.id).toList();

  @override
  String toString() => 'StatePath(${stateIds.join(' → ')})';
}

/// Utility functions for working with state hierarchies.
class StateHierarchy {
  /// Build a path from root to the given state value.
  static StatePath<TContext, TEvent> buildPath<TContext, TEvent extends XEvent>(
    StateValue value,
    StateConfig<TContext, TEvent> rootConfig,
  ) {
    final configs = <StateConfig<TContext, TEvent>>[];
    _collectConfigs(value, rootConfig, configs);
    return StatePath(configs);
  }

  static void _collectConfigs<TContext, TEvent extends XEvent>(
    StateValue value,
    StateConfig<TContext, TEvent> config,
    List<StateConfig<TContext, TEvent>> result,
  ) {
    result.add(config);

    switch (value) {
      case AtomicStateValue():
        // Leaf node, done
        break;

      case CompoundStateValue(:final child):
        final childId = _getStateId(child);
        final childConfig = config.states[childId];
        if (childConfig != null) {
          _collectConfigs(child, childConfig, result);
        }

      case ParallelStateValue():
        // For parallel states, we add the parallel config but don't recurse
        // since multiple regions are active simultaneously
        // The regions are handled separately
        break;
    }
  }

  /// Find the Lowest Common Ancestor (LCA) of two state paths.
  ///
  /// Returns the depth at which the paths diverge.
  /// Both paths share ancestors from 0 to (lcaDepth - 1).
  static int findLCADepth<TContext, TEvent extends XEvent>(
    StatePath<TContext, TEvent> source,
    StatePath<TContext, TEvent> target,
  ) {
    int lcaDepth = 0;
    final minDepth =
        source.depth < target.depth ? source.depth : target.depth;

    for (int i = 0; i < minDepth; i++) {
      if (source.idAt(i) == target.idAt(i)) {
        lcaDepth = i + 1;
      } else {
        break;
      }
    }

    return lcaDepth;
  }

  /// Get states to exit when transitioning from source to target.
  ///
  /// Returns configs in exit order (innermost to outermost).
  static List<StateConfig<TContext, TEvent>>
      getExitStates<TContext, TEvent extends XEvent>(
    StatePath<TContext, TEvent> source,
    StatePath<TContext, TEvent> target, {
    bool internal = false,
  }) {
    if (internal) return [];

    final lcaDepth = findLCADepth(source, target);

    // Exit from innermost to LCA (exclusive)
    final toExit = <StateConfig<TContext, TEvent>>[];
    for (int i = source.depth - 1; i >= lcaDepth; i--) {
      final config = source.configAt(i);
      if (config != null) {
        toExit.add(config);
      }
    }

    return toExit;
  }

  /// Get states to enter when transitioning from source to target.
  ///
  /// Returns configs in entry order (outermost to innermost).
  static List<StateConfig<TContext, TEvent>>
      getEntryStates<TContext, TEvent extends XEvent>(
    StatePath<TContext, TEvent> source,
    StatePath<TContext, TEvent> target, {
    bool internal = false,
  }) {
    if (internal) return [];

    final lcaDepth = findLCADepth(source, target);

    // Enter from LCA to innermost
    final toEnter = <StateConfig<TContext, TEvent>>[];
    for (int i = lcaDepth; i < target.depth; i++) {
      final config = target.configAt(i);
      if (config != null) {
        toEnter.add(config);
      }
    }

    return toEnter;
  }

  /// Check if one state is an ancestor of another.
  static bool isAncestor<TContext, TEvent extends XEvent>(
    StatePath<TContext, TEvent> potentialAncestor,
    StatePath<TContext, TEvent> potentialDescendant,
  ) {
    if (potentialAncestor.depth >= potentialDescendant.depth) {
      return false;
    }

    for (int i = 0; i < potentialAncestor.depth; i++) {
      if (potentialAncestor.idAt(i) != potentialDescendant.idAt(i)) {
        return false;
      }
    }

    return true;
  }

  /// Get the state ID from a state value.
  static String _getStateId(StateValue value) {
    return switch (value) {
      AtomicStateValue(:final id) => id,
      CompoundStateValue(:final id) => id,
      ParallelStateValue(:final id) => id,
    };
  }
}

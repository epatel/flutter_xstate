import 'package:meta/meta.dart';

import '../core/state_value.dart';

/// Manages history values for state machines with history states.
///
/// History states remember the last active child state and restore
/// it when the parent state is re-entered via the history state.
@immutable
class HistoryManager {
  /// Current history values.
  /// Maps state path (like "app.dashboard") to the last active child value.
  final Map<String, StateValue> _history;

  const HistoryManager([this._history = const {}]);

  /// Create an empty history manager.
  const HistoryManager.empty() : _history = const {};

  /// Get the history for a state path.
  StateValue? getHistory(String statePath) => _history[statePath];

  /// Check if history exists for a state path.
  bool hasHistory(String statePath) => _history.containsKey(statePath);

  /// Record history when exiting a state.
  ///
  /// For shallow history, only the immediate child is recorded.
  /// For deep history, the entire subtree is recorded.
  HistoryManager recordHistory(
    String parentPath,
    StateValue childValue, {
    bool deep = false,
  }) {
    final newHistory = Map<String, StateValue>.from(_history);
    newHistory[parentPath] = childValue;
    return HistoryManager(newHistory);
  }

  /// Clear history for a state path.
  HistoryManager clearHistory(String statePath) {
    if (!_history.containsKey(statePath)) return this;
    final newHistory = Map<String, StateValue>.from(_history);
    newHistory.remove(statePath);
    return HistoryManager(newHistory);
  }

  /// Convert to a map for storage in StateSnapshot.
  Map<String, StateValue> toMap() => Map.unmodifiable(_history);

  /// Create from a map (e.g., from StateSnapshot.historyValue).
  factory HistoryManager.fromMap(Map<String, StateValue> map) {
    return HistoryManager(Map<String, StateValue>.from(map));
  }

  @override
  String toString() => 'HistoryManager($_history)';
}

/// Extension to help with history state resolution.
extension HistoryResolution on StateValue {
  /// Get the full path string for this state value.
  String get fullPath {
    return switch (this) {
      AtomicStateValue(:final id) => id,
      CompoundStateValue(:final id, :final child) => '$id.${child.fullPath}',
      ParallelStateValue(:final id) => id,
    };
  }

  /// Get just the leaf state ID.
  String get leafId {
    return switch (this) {
      AtomicStateValue(:final id) => id,
      CompoundStateValue(:final child) => child.leafId,
      ParallelStateValue(:final id) => id,
    };
  }
}

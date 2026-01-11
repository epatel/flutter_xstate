import 'package:meta/meta.dart';

/// Represents the current state(s) of a state machine.
///
/// This is a sealed class hierarchy supporting:
/// - [AtomicStateValue] - a single, leaf state
/// - [CompoundStateValue] - a parent state with an active child
/// - [ParallelStateValue] - multiple active regions
@immutable
sealed class StateValue {
  const StateValue();

  /// Check if this state value matches the given state ID.
  ///
  /// For compound states, also checks if any ancestor matches.
  /// Use dot notation for nested states: 'parent.child'.
  bool matches(String stateId);

  /// Get the list of all active state IDs.
  List<String> get activeStates;
}

/// Represents a single atomic (leaf) state.
///
/// Example:
/// ```dart
/// final value = AtomicStateValue('idle');
/// print(value.matches('idle')); // true
/// ```
@immutable
class AtomicStateValue extends StateValue {
  /// The unique identifier of this state.
  final String id;

  const AtomicStateValue(this.id);

  @override
  bool matches(String stateId) => id == stateId;

  @override
  List<String> get activeStates => [id];

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AtomicStateValue &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'StateValue($id)';
}

/// Represents a compound state with an active child state.
///
/// Used for hierarchical/nested states where a parent state
/// contains child states.
///
/// Example:
/// ```dart
/// final value = CompoundStateValue(
///   'traffic',
///   AtomicStateValue('green'),
/// );
/// print(value.matches('traffic')); // true
/// print(value.matches('traffic.green')); // true
/// ```
@immutable
class CompoundStateValue extends StateValue {
  /// The identifier of this parent state.
  final String id;

  /// The active child state value.
  final StateValue child;

  const CompoundStateValue(this.id, this.child);

  @override
  bool matches(String stateId) {
    // Direct match
    if (id == stateId) return true;

    // Check for dot-notation path match
    if (stateId.startsWith('$id.')) {
      final childPath = stateId.substring(id.length + 1);
      return child.matches(childPath);
    }

    // Check if child matches directly
    return child.matches(stateId);
  }

  @override
  List<String> get activeStates {
    final childStates = child.activeStates;
    return [id, ...childStates.map((s) => '$id.$s')];
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CompoundStateValue &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          child == other.child;

  @override
  int get hashCode => Object.hash(id, child);

  @override
  String toString() => 'StateValue($id.$child)';
}

/// Represents parallel states with multiple active regions.
///
/// Used when multiple state regions are active simultaneously.
///
/// Example:
/// ```dart
/// final value = ParallelStateValue('player', {
///   'audio': AtomicStateValue('playing'),
///   'video': AtomicStateValue('visible'),
/// });
/// print(value.matches('player.audio.playing')); // true
/// print(value.matches('player.video.visible')); // true
/// ```
@immutable
class ParallelStateValue extends StateValue {
  /// The identifier of this parallel state.
  final String id;

  /// Map of region ID to active state value in that region.
  final Map<String, StateValue> regions;

  const ParallelStateValue(this.id, this.regions);

  @override
  bool matches(String stateId) {
    // Direct match
    if (id == stateId) return true;

    // Check for region match with dot notation
    if (stateId.startsWith('$id.')) {
      final rest = stateId.substring(id.length + 1);
      final dotIndex = rest.indexOf('.');
      final regionId = dotIndex >= 0 ? rest.substring(0, dotIndex) : rest;
      final childPath = dotIndex >= 0 ? rest.substring(dotIndex + 1) : null;

      final region = regions[regionId];
      if (region == null) return false;

      if (childPath == null) {
        // Just matching the region ID
        return region.matches(regionId) || region.activeStates.isNotEmpty;
      }

      return region.matches(childPath);
    }

    // Check if any region matches
    return regions.values.any((region) => region.matches(stateId));
  }

  @override
  List<String> get activeStates {
    final result = <String>[id];
    for (final entry in regions.entries) {
      final regionId = entry.key;
      final regionValue = entry.value;
      for (final state in regionValue.activeStates) {
        result.add('$id.$regionId.$state');
      }
    }
    return result;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ParallelStateValue) return false;
    if (id != other.id) return false;
    if (regions.length != other.regions.length) return false;
    for (final key in regions.keys) {
      if (regions[key] != other.regions[key]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(id, Object.hashAll(regions.entries));

  @override
  String toString() {
    final regionStrs = regions.entries
        .map((e) => '${e.key}: ${e.value}')
        .join(', ');
    return 'StateValue($id, {$regionStrs})';
  }
}

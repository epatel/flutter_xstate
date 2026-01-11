import 'dart:convert';

import '../core/state_snapshot.dart';
import '../core/state_value.dart';
import '../events/x_event.dart';

/// Interface for serializing/deserializing state machine context.
///
/// Implement this interface to enable persistence for your context type.
///
/// Example:
/// ```dart
/// class UserContext implements JsonSerializable<UserContext> {
///   final String name;
///   final int age;
///
///   UserContext({required this.name, required this.age});
///
///   @override
///   Map<String, dynamic> toJson() => {'name': name, 'age': age};
///
///   @override
///   UserContext fromJson(Map<String, dynamic> json) =>
///     UserContext(name: json['name'], age: json['age']);
/// }
/// ```
abstract class JsonSerializable<T> {
  /// Convert to JSON map.
  Map<String, dynamic> toJson();

  /// Create from JSON map.
  T fromJson(Map<String, dynamic> json);
}

/// Serialized state snapshot.
class SerializedSnapshot {
  /// The serialized state value.
  final Map<String, dynamic> value;

  /// The serialized context.
  final Map<String, dynamic> context;

  /// The event type that caused this state.
  final String? eventType;

  /// Timestamp when snapshot was taken.
  final DateTime timestamp;

  /// Machine ID.
  final String? machineId;

  /// Version for migration support.
  final int version;

  const SerializedSnapshot({
    required this.value,
    required this.context,
    this.eventType,
    required this.timestamp,
    this.machineId,
    this.version = 1,
  });

  /// Convert to JSON map.
  Map<String, dynamic> toJson() => {
    'value': value,
    'context': context,
    'eventType': eventType,
    'timestamp': timestamp.toIso8601String(),
    'machineId': machineId,
    'version': version,
  };

  /// Create from JSON map.
  factory SerializedSnapshot.fromJson(Map<String, dynamic> json) {
    return SerializedSnapshot(
      value: json['value'] as Map<String, dynamic>,
      context: json['context'] as Map<String, dynamic>,
      eventType: json['eventType'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
      machineId: json['machineId'] as String?,
      version: json['version'] as int? ?? 1,
    );
  }

  /// Convert to JSON string.
  String toJsonString() => jsonEncode(toJson());

  /// Create from JSON string.
  factory SerializedSnapshot.fromJsonString(String json) {
    return SerializedSnapshot.fromJson(
      jsonDecode(json) as Map<String, dynamic>,
    );
  }
}

/// Serializer for state values.
class StateValueSerializer {
  /// Serialize a state value to JSON.
  static Map<String, dynamic> serialize(StateValue value) {
    if (value is AtomicStateValue) {
      return {'type': 'atomic', 'id': value.id};
    } else if (value is CompoundStateValue) {
      return {
        'type': 'compound',
        'id': value.id,
        'child': serialize(value.child),
      };
    } else if (value is ParallelStateValue) {
      return {
        'type': 'parallel',
        'id': value.id,
        'regions': value.regions.map(
          (key, value) => MapEntry(key, serialize(value)),
        ),
      };
    }
    throw ArgumentError('Unknown state value type: ${value.runtimeType}');
  }

  /// Deserialize a state value from JSON.
  static StateValue deserialize(Map<String, dynamic> json) {
    final type = json['type'] as String;

    switch (type) {
      case 'atomic':
        return AtomicStateValue(json['id'] as String);
      case 'compound':
        return CompoundStateValue(
          json['id'] as String,
          deserialize(json['child'] as Map<String, dynamic>),
        );
      case 'parallel':
        final regionsJson = json['regions'] as Map<String, dynamic>;
        return ParallelStateValue(
          json['id'] as String,
          regionsJson.map(
            (key, value) =>
                MapEntry(key, deserialize(value as Map<String, dynamic>)),
          ),
        );
      default:
        throw ArgumentError('Unknown state value type: $type');
    }
  }
}

/// Persistence adapter interface.
///
/// Implement this to persist state to different storage backends.
abstract class StatePersistenceAdapter {
  /// Save a serialized snapshot.
  Future<void> save(String key, SerializedSnapshot snapshot);

  /// Load a serialized snapshot.
  Future<SerializedSnapshot?> load(String key);

  /// Delete a saved snapshot.
  Future<void> delete(String key);

  /// Check if a snapshot exists.
  Future<bool> exists(String key);

  /// Clear all saved snapshots.
  Future<void> clear();
}

/// In-memory persistence adapter for testing.
class InMemoryPersistenceAdapter implements StatePersistenceAdapter {
  final Map<String, SerializedSnapshot> _storage = {};

  @override
  Future<void> save(String key, SerializedSnapshot snapshot) async {
    _storage[key] = snapshot;
  }

  @override
  Future<SerializedSnapshot?> load(String key) async {
    return _storage[key];
  }

  @override
  Future<void> delete(String key) async {
    _storage.remove(key);
  }

  @override
  Future<bool> exists(String key) async {
    return _storage.containsKey(key);
  }

  @override
  Future<void> clear() async {
    _storage.clear();
  }

  /// Get all stored snapshots (for testing).
  Map<String, SerializedSnapshot> get storage => Map.unmodifiable(_storage);
}

/// State machine persistence manager.
///
/// Handles saving and loading state machine snapshots with automatic
/// serialization/deserialization.
///
/// Example:
/// ```dart
/// final persistence = StateMachinePersistence<UserContext, UserEvent>(
///   adapter: InMemoryPersistenceAdapter(),
///   contextSerializer: (ctx) => ctx.toJson(),
///   contextDeserializer: (json) => UserContext.fromJson(json),
/// );
///
/// // Save state
/// await persistence.save('user-machine', actor.snapshot);
///
/// // Load state
/// final snapshot = await persistence.load('user-machine');
/// if (snapshot != null) {
///   final actor = machine.createActor(initialSnapshot: snapshot);
/// }
/// ```
class StateMachinePersistence<TContext, TEvent extends XEvent> {
  /// The persistence adapter.
  final StatePersistenceAdapter adapter;

  /// Function to serialize context to JSON.
  final Map<String, dynamic> Function(TContext context) contextSerializer;

  /// Function to deserialize context from JSON.
  final TContext Function(Map<String, dynamic> json) contextDeserializer;

  /// Optional machine ID for namespacing.
  final String? machineId;

  /// Version number for migration support.
  final int version;

  /// Optional migration function for version upgrades.
  final SerializedSnapshot Function(
    SerializedSnapshot snapshot,
    int fromVersion,
  )?
  migrator;

  StateMachinePersistence({
    required this.adapter,
    required this.contextSerializer,
    required this.contextDeserializer,
    this.machineId,
    this.version = 1,
    this.migrator,
  });

  /// Save a snapshot.
  Future<void> save(String key, StateSnapshot<TContext> snapshot) async {
    final serialized = SerializedSnapshot(
      value: StateValueSerializer.serialize(snapshot.value),
      context: contextSerializer(snapshot.context),
      eventType: snapshot.event?.type,
      timestamp: DateTime.now(),
      machineId: machineId,
      version: version,
    );

    await adapter.save(key, serialized);
  }

  /// Load a snapshot.
  Future<StateSnapshot<TContext>?> load(String key) async {
    var serialized = await adapter.load(key);

    if (serialized == null) {
      return null;
    }

    // Handle version migration
    if (serialized.version < version && migrator != null) {
      serialized = migrator!(serialized, serialized.version);
      // Re-save with new version
      await adapter.save(key, serialized);
    }

    final stateValue = StateValueSerializer.deserialize(serialized.value);
    final context = contextDeserializer(serialized.context);

    return StateSnapshot<TContext>(
      value: stateValue,
      context: context,
      event: const InitEvent(), // We lose the original event type
    );
  }

  /// Delete a saved snapshot.
  Future<void> delete(String key) => adapter.delete(key);

  /// Check if a snapshot exists.
  Future<bool> exists(String key) => adapter.exists(key);

  /// Clear all snapshots.
  Future<void> clear() => adapter.clear();
}

/// Auto-save configuration.
class AutoSaveConfig {
  /// Whether auto-save is enabled.
  final bool enabled;

  /// Debounce duration for auto-save.
  final Duration debounce;

  /// Key to save under.
  final String key;

  /// Whether to save on every state change.
  final bool onEveryChange;

  /// Optional filter for when to save.
  final bool Function<TContext>(StateSnapshot<TContext> snapshot)? saveWhen;

  const AutoSaveConfig({
    this.enabled = true,
    this.debounce = const Duration(milliseconds: 500),
    required this.key,
    this.onEveryChange = true,
    this.saveWhen,
  });
}

/// Extension for easy snapshot serialization.
extension SnapshotSerializationExtension<TContext> on StateSnapshot<TContext> {
  /// Serialize this snapshot using the given context serializer.
  SerializedSnapshot serialize(
    Map<String, dynamic> Function(TContext context) contextSerializer, {
    String? machineId,
    int version = 1,
  }) {
    return SerializedSnapshot(
      value: StateValueSerializer.serialize(value),
      context: contextSerializer(context),
      eventType: event?.type,
      timestamp: DateTime.now(),
      machineId: machineId,
      version: version,
    );
  }
}

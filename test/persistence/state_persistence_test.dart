import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_xstate/flutter_xstate.dart';

// Test context
class UserContext {
  final String name;
  final int age;
  final bool isVerified;

  const UserContext({
    this.name = '',
    this.age = 0,
    this.isVerified = false,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'age': age,
        'isVerified': isVerified,
      };

  factory UserContext.fromJson(Map<String, dynamic> json) => UserContext(
        name: json['name'] as String? ?? '',
        age: json['age'] as int? ?? 0,
        isVerified: json['isVerified'] as bool? ?? false,
      );

  UserContext copyWith({String? name, int? age, bool? isVerified}) =>
      UserContext(
        name: name ?? this.name,
        age: age ?? this.age,
        isVerified: isVerified ?? this.isVerified,
      );
}

// Test events
sealed class UserEvent extends XEvent {}

class UpdateNameEvent extends UserEvent {
  final String name;
  UpdateNameEvent(this.name);
  @override
  String get type => 'UPDATE_NAME';
}

void main() {
  group('SerializedSnapshot', () {
    test('creates from values', () {
      final snapshot = SerializedSnapshot(
        value: {'type': 'atomic', 'id': 'active'},
        context: {'name': 'John', 'age': 30},
        eventType: 'UPDATE',
        timestamp: DateTime(2024, 1, 1),
        machineId: 'user',
        version: 1,
      );

      expect(snapshot.value['id'], equals('active'));
      expect(snapshot.context['name'], equals('John'));
      expect(snapshot.eventType, equals('UPDATE'));
      expect(snapshot.machineId, equals('user'));
      expect(snapshot.version, equals(1));
    });

    test('converts to and from JSON', () {
      final original = SerializedSnapshot(
        value: {'type': 'atomic', 'id': 'active'},
        context: {'name': 'John', 'age': 30},
        eventType: 'UPDATE',
        timestamp: DateTime(2024, 1, 1),
        machineId: 'user',
        version: 1,
      );

      final json = original.toJson();
      final restored = SerializedSnapshot.fromJson(json);

      expect(restored.value, equals(original.value));
      expect(restored.context, equals(original.context));
      expect(restored.eventType, equals(original.eventType));
      expect(restored.machineId, equals(original.machineId));
      expect(restored.version, equals(original.version));
    });

    test('converts to and from JSON string', () {
      final original = SerializedSnapshot(
        value: {'type': 'atomic', 'id': 'active'},
        context: {'name': 'John'},
        timestamp: DateTime(2024, 1, 1),
      );

      final jsonString = original.toJsonString();
      expect(jsonString, isA<String>());

      final restored = SerializedSnapshot.fromJsonString(jsonString);
      expect(restored.value, equals(original.value));
    });
  });

  group('StateValueSerializer', () {
    test('serializes atomic state value', () {
      final value = const AtomicStateValue('active');
      final json = StateValueSerializer.serialize(value);

      expect(json['type'], equals('atomic'));
      expect(json['id'], equals('active'));
    });

    test('deserializes atomic state value', () {
      final json = {'type': 'atomic', 'id': 'active'};
      final value = StateValueSerializer.deserialize(json);

      expect(value, isA<AtomicStateValue>());
      expect((value as AtomicStateValue).id, equals('active'));
    });

    test('serializes compound state value', () {
      final value = CompoundStateValue(
        'parent',
        const AtomicStateValue('child'),
      );
      final json = StateValueSerializer.serialize(value);

      expect(json['type'], equals('compound'));
      expect(json['id'], equals('parent'));
      expect(json['child']['id'], equals('child'));
    });

    test('deserializes compound state value', () {
      final json = {
        'type': 'compound',
        'id': 'parent',
        'child': {'type': 'atomic', 'id': 'child'},
      };
      final value = StateValueSerializer.deserialize(json);

      expect(value, isA<CompoundStateValue>());
      final compound = value as CompoundStateValue;
      expect(compound.id, equals('parent'));
      expect((compound.child as AtomicStateValue).id, equals('child'));
    });

    test('serializes parallel state value', () {
      final value = ParallelStateValue(
        'parallel',
        {
          'region1': const AtomicStateValue('state1'),
          'region2': const AtomicStateValue('state2'),
        },
      );
      final json = StateValueSerializer.serialize(value);

      expect(json['type'], equals('parallel'));
      expect(json['id'], equals('parallel'));
      expect(json['regions']['region1']['id'], equals('state1'));
      expect(json['regions']['region2']['id'], equals('state2'));
    });

    test('deserializes parallel state value', () {
      final json = {
        'type': 'parallel',
        'id': 'parallel',
        'regions': {
          'region1': {'type': 'atomic', 'id': 'state1'},
          'region2': {'type': 'atomic', 'id': 'state2'},
        },
      };
      final value = StateValueSerializer.deserialize(json);

      expect(value, isA<ParallelStateValue>());
      final parallel = value as ParallelStateValue;
      expect(parallel.id, equals('parallel'));
      expect(parallel.regions.length, equals(2));
    });
  });

  group('InMemoryPersistenceAdapter', () {
    test('saves and loads snapshot', () async {
      final adapter = InMemoryPersistenceAdapter();
      final snapshot = SerializedSnapshot(
        value: {'type': 'atomic', 'id': 'active'},
        context: {'name': 'John'},
        timestamp: DateTime.now(),
      );

      await adapter.save('key1', snapshot);
      final loaded = await adapter.load('key1');

      expect(loaded, isNotNull);
      expect(loaded!.context['name'], equals('John'));
    });

    test('returns null for missing key', () async {
      final adapter = InMemoryPersistenceAdapter();
      final loaded = await adapter.load('nonexistent');
      expect(loaded, isNull);
    });

    test('checks existence', () async {
      final adapter = InMemoryPersistenceAdapter();
      expect(await adapter.exists('key1'), isFalse);

      await adapter.save(
        'key1',
        SerializedSnapshot(
          value: {},
          context: {},
          timestamp: DateTime.now(),
        ),
      );
      expect(await adapter.exists('key1'), isTrue);
    });

    test('deletes snapshot', () async {
      final adapter = InMemoryPersistenceAdapter();
      await adapter.save(
        'key1',
        SerializedSnapshot(
          value: {},
          context: {},
          timestamp: DateTime.now(),
        ),
      );

      await adapter.delete('key1');
      expect(await adapter.exists('key1'), isFalse);
    });

    test('clears all snapshots', () async {
      final adapter = InMemoryPersistenceAdapter();
      await adapter.save(
        'key1',
        SerializedSnapshot(value: {}, context: {}, timestamp: DateTime.now()),
      );
      await adapter.save(
        'key2',
        SerializedSnapshot(value: {}, context: {}, timestamp: DateTime.now()),
      );

      await adapter.clear();
      expect(await adapter.exists('key1'), isFalse);
      expect(await adapter.exists('key2'), isFalse);
    });
  });

  group('StateMachinePersistence', () {
    late StateMachine<UserContext, UserEvent> machine;
    late StateMachinePersistence<UserContext, UserEvent> persistence;
    late InMemoryPersistenceAdapter adapter;

    setUp(() {
      machine = StateMachine.create<UserContext, UserEvent>(
        (m) => m
          ..context(const UserContext())
          ..initial('idle')
          ..state(
            'idle',
            (s) => s..on<UpdateNameEvent>('active', actions: [
              (ctx, event) =>
                  ctx.copyWith(name: (event as UpdateNameEvent).name),
            ]),
          )
          ..state('active', (s) {}),
        id: 'user',
      );

      adapter = InMemoryPersistenceAdapter();
      persistence = StateMachinePersistence<UserContext, UserEvent>(
        adapter: adapter,
        contextSerializer: (ctx) => ctx.toJson(),
        contextDeserializer: UserContext.fromJson,
        machineId: 'user',
      );
    });

    test('saves snapshot', () async {
      final actor = machine.createActor();
      actor.start();
      actor.send(UpdateNameEvent('John'));

      await persistence.save('user-state', actor.snapshot);

      expect(await adapter.exists('user-state'), isTrue);

      actor.dispose();
    });

    test('loads snapshot', () async {
      final actor = machine.createActor();
      actor.start();
      actor.send(UpdateNameEvent('John'));

      await persistence.save('user-state', actor.snapshot);
      final loaded = await persistence.load('user-state');

      expect(loaded, isNotNull);
      expect(loaded!.context.name, equals('John'));
      expect(loaded.value.matches('active'), isTrue);

      actor.dispose();
    });

    test('restores actor from loaded snapshot', () async {
      // Create and save state
      final actor1 = machine.createActor();
      actor1.start();
      actor1.send(UpdateNameEvent('John'));
      await persistence.save('user-state', actor1.snapshot);
      actor1.dispose();

      // Load and restore
      final loaded = await persistence.load('user-state');
      final actor2 = machine.createActor(initialSnapshot: loaded);
      actor2.start();

      expect(actor2.snapshot.context.name, equals('John'));
      expect(actor2.matches('active'), isTrue);

      actor2.dispose();
    });

    test('handles version migration', () async {
      // Save with version 1
      final v1Persistence = StateMachinePersistence<UserContext, UserEvent>(
        adapter: adapter,
        contextSerializer: (ctx) => ctx.toJson(),
        contextDeserializer: UserContext.fromJson,
        version: 1,
      );

      final actor = machine.createActor();
      actor.start();
      await v1Persistence.save('user-state', actor.snapshot);

      // Load with version 2 and migrator
      final v2Persistence = StateMachinePersistence<UserContext, UserEvent>(
        adapter: adapter,
        contextSerializer: (ctx) => ctx.toJson(),
        contextDeserializer: UserContext.fromJson,
        version: 2,
        migrator: (snapshot, fromVersion) {
          // Migrate context
          final newContext = Map<String, dynamic>.from(snapshot.context);
          newContext['migrated'] = true;
          return SerializedSnapshot(
            value: snapshot.value,
            context: newContext,
            timestamp: snapshot.timestamp,
            version: 2,
          );
        },
      );

      final loaded = await v2Persistence.load('user-state');
      expect(loaded, isNotNull);

      actor.dispose();
    });
  });

  group('SnapshotSerializationExtension', () {
    test('serializes snapshot', () {
      final snapshot = StateSnapshot<UserContext>(
        value: const AtomicStateValue('active'),
        context: const UserContext(name: 'John', age: 30),
        event: const InitEvent(),
      );

      final serialized = snapshot.serialize(
        (ctx) => ctx.toJson(),
        machineId: 'user',
        version: 1,
      );

      expect(serialized.value['id'], equals('active'));
      expect(serialized.context['name'], equals('John'));
      expect(serialized.machineId, equals('user'));
      expect(serialized.version, equals(1));
    });
  });
}

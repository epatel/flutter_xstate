// ignore_for_file: avoid_print
import 'package:flutter/material.dart';
import 'package:flutter_xstate/flutter_xstate.dart';

// 1. Define your context (data)
class CounterContext {
  final int count;
  const CounterContext({this.count = 0});
  CounterContext copyWith({int? count}) =>
      CounterContext(count: count ?? this.count);
}

// 2. Define your events
sealed class CounterEvent extends XEvent {}

class IncrementEvent extends CounterEvent {
  @override
  String get type => 'INCREMENT';
}

class DecrementEvent extends CounterEvent {
  @override
  String get type => 'DECREMENT';
}

class ResetEvent extends CounterEvent {
  @override
  String get type => 'RESET';
}

// 3. Create the machine
final counterMachine = StateMachine.create<CounterContext, CounterEvent>(
  (m) => m
    ..context(const CounterContext())
    ..initial('active')
    ..state(
      'active',
      (s) => s
        ..on<IncrementEvent>(
          'active',
          actions: [(ctx, _) => ctx.copyWith(count: ctx.count + 1)],
        )
        ..on<DecrementEvent>(
          'active',
          actions: [(ctx, _) => ctx.copyWith(count: ctx.count - 1)],
        )
        ..on<ResetEvent>('idle', actions: [(ctx, _) => ctx.copyWith(count: 0)]),
    )
    ..state('idle', (s) => s..on<IncrementEvent>('active')),
  id: 'counter',
);

// 4. Use in Flutter
void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'flutter_xstate Example',
      home: StateMachineProvider<CounterContext, CounterEvent>(
        machine: counterMachine,
        autoStart: true,
        child: const CounterPage(),
      ),
    );
  }
}

class CounterPage extends StatelessWidget {
  const CounterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Counter Example')),
      body: Center(
        child: StateMachineBuilder<CounterContext, CounterEvent>(
          builder: (context, state, send) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'State: ${state.value}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                Text(
                  '${state.context.count}',
                  style: Theme.of(context).textTheme.displayLarge,
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FloatingActionButton(
                      heroTag: 'decrement',
                      onPressed: () => send(DecrementEvent()),
                      child: const Icon(Icons.remove),
                    ),
                    const SizedBox(width: 16),
                    FloatingActionButton(
                      heroTag: 'increment',
                      onPressed: () => send(IncrementEvent()),
                      child: const Icon(Icons.add),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => send(ResetEvent()),
                  child: const Text('Reset'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

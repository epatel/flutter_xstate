/// Step 2: Counter - Context and Actions
///
/// Run with: flutter run -d chrome

import 'package:flutter/material.dart';
import 'package:flutter_xstate/flutter_xstate.dart';

// ============================================================================
// CONTEXT
// ============================================================================

class CounterContext {
  final int count;
  final List<String> history;

  const CounterContext({this.count = 0, this.history = const []});

  CounterContext copyWith({int? count, List<String>? history}) => CounterContext(
        count: count ?? this.count,
        history: history ?? this.history,
      );
}

// ============================================================================
// EVENTS
// ============================================================================

sealed class CounterEvent extends XEvent {}

class IncrementEvent extends CounterEvent {
  final int amount;
  IncrementEvent([this.amount = 1]);

  @override
  String get type => 'INCREMENT';
}

class DecrementEvent extends CounterEvent {
  final int amount;
  DecrementEvent([this.amount = 1]);

  @override
  String get type => 'DECREMENT';
}

class ResetEvent extends CounterEvent {
  @override
  String get type => 'RESET';
}

// ============================================================================
// STATE MACHINE
// ============================================================================

final counterMachine = StateMachine.create<CounterContext, CounterEvent>(
  (m) => m
    ..context(const CounterContext())
    ..initial('active')
    ..state(
      'active',
      (s) => s
        ..on<IncrementEvent>('active', actions: [
          (ctx, event) {
            final e = event as IncrementEvent;
            final newCount = ctx.count + e.amount;
            return ctx.copyWith(
              count: newCount,
              history: [...ctx.history, '+${e.amount}'],
            );
          },
        ])
        ..on<DecrementEvent>('active', actions: [
          (ctx, event) {
            final e = event as DecrementEvent;
            final newCount = ctx.count - e.amount;
            return ctx.copyWith(
              count: newCount,
              history: [...ctx.history, '-${e.amount}'],
            );
          },
        ])
        ..on<ResetEvent>('idle'),
    )
    ..state(
      'idle',
      (s) => s
        ..entry([
          (ctx, event) => ctx.copyWith(count: 0, history: []),
        ])
        ..on<IncrementEvent>('active', actions: [
          (ctx, event) {
            final e = event as IncrementEvent;
            return ctx.copyWith(count: e.amount, history: ['+${e.amount}']);
          },
        ]),
    ),
  id: 'counter',
);

// ============================================================================
// APP
// ============================================================================

void main() {
  runApp(const CounterApp());
}

class CounterApp extends StatelessWidget {
  const CounterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Step 2: Counter',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: StateMachineProvider<CounterContext, CounterEvent>(
        machine: counterMachine,
        autoStart: true,
        child: const CounterScreen(),
      ),
    );
  }
}

class CounterScreen extends StatelessWidget {
  const CounterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Step 2: Counter'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: StateMachineBuilder<CounterContext, CounterEvent>(
          builder: (context, state, send) {
            final ctx = state.context;
            final isIdle = state.value.matches('idle');

            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // State indicator
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isIdle ? Colors.grey : Colors.green,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isIdle ? 'IDLE' : 'ACTIVE',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 40),

                // Counter display
                Text(
                  '${ctx.count}',
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 40),

                // Increment/Decrement buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _CounterButton(
                      icon: Icons.remove,
                      label: '-1',
                      onPressed: isIdle ? null : () => send(DecrementEvent()),
                    ),
                    const SizedBox(width: 16),
                    _CounterButton(
                      icon: Icons.add,
                      label: '+1',
                      onPressed: () => send(IncrementEvent()),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Increment by 5 buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _CounterButton(
                      icon: Icons.remove,
                      label: '-5',
                      onPressed: isIdle ? null : () => send(DecrementEvent(5)),
                    ),
                    const SizedBox(width: 16),
                    _CounterButton(
                      icon: Icons.add,
                      label: '+5',
                      onPressed: () => send(IncrementEvent(5)),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Reset button
                ElevatedButton.icon(
                  onPressed: isIdle ? null : () => send(ResetEvent()),
                  icon: const Icon(Icons.refresh),
                  label: const Text('RESET'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[400],
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 40),

                // History
                Text(
                  'History',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  constraints: const BoxConstraints(maxWidth: 300),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    ctx.history.isEmpty ? '(empty)' : ctx.history.join(', '),
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CounterButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  const _CounterButton({
    required this.icon,
    required this.label,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 18)),
        ],
      ),
    );
  }
}

/// Step 1: Traffic Light - Your First State Machine
///
/// Run with: flutter run -d chrome

import 'package:flutter/material.dart';
import 'package:flutter_xstate/flutter_xstate.dart';

// ============================================================================
// EVENTS
// ============================================================================

sealed class TrafficLightEvent extends XEvent {}

class TimerEvent extends TrafficLightEvent {
  @override
  String get type => 'TIMER';
}

// ============================================================================
// CONTEXT
// ============================================================================

class TrafficLightContext {
  const TrafficLightContext();
}

// ============================================================================
// STATE MACHINE
// ============================================================================

final trafficLightMachine =
    StateMachine.create<TrafficLightContext, TrafficLightEvent>(
  (m) => m
    ..context(const TrafficLightContext())
    ..initial('red')
    ..state('red', (s) => s..on<TimerEvent>('green'))
    ..state('green', (s) => s..on<TimerEvent>('yellow'))
    ..state('yellow', (s) => s..on<TimerEvent>('red')),
  id: 'trafficLight',
);

// ============================================================================
// APP
// ============================================================================

void main() {
  runApp(const TrafficLightApp());
}

class TrafficLightApp extends StatelessWidget {
  const TrafficLightApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Step 1: Traffic Light',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.grey),
        useMaterial3: true,
      ),
      home: StateMachineProvider<TrafficLightContext, TrafficLightEvent>(
        machine: trafficLightMachine,
        autoStart: true,
        child: const TrafficLightScreen(),
      ),
    );
  }
}

class TrafficLightScreen extends StatelessWidget {
  const TrafficLightScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: const Text('Step 1: Traffic Light'),
        backgroundColor: Colors.grey[850],
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: StateMachineBuilder<TrafficLightContext, TrafficLightEvent>(
          builder: (context, state, send) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Traffic Light
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey[600]!, width: 4),
                  ),
                  child: Column(
                    children: [
                      _Light(
                        color: Colors.red,
                        isActive: state.value.matches('red'),
                      ),
                      const SizedBox(height: 16),
                      _Light(
                        color: Colors.yellow,
                        isActive: state.value.matches('yellow'),
                      ),
                      const SizedBox(height: 16),
                      _Light(
                        color: Colors.green,
                        isActive: state.value.matches('green'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),

                // State display
                Text(
                  'Current State: ${_getStateName(state)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 40),

                // Timer button
                ElevatedButton.icon(
                  onPressed: () => send(TimerEvent()),
                  icon: const Icon(Icons.timer),
                  label: const Text('TIMER'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Instructions
                Text(
                  'Click TIMER to cycle through states',
                  style: TextStyle(color: Colors.grey[400]),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  static String _getStateName(StateSnapshot<TrafficLightContext> state) {
    if (state.value.matches('red')) return 'RED';
    if (state.value.matches('yellow')) return 'YELLOW';
    if (state.value.matches('green')) return 'GREEN';
    return 'Unknown';
  }
}

class _Light extends StatelessWidget {
  final Color color;
  final bool isActive;

  const _Light({required this.color, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isActive ? color : color.withValues(alpha: 0.2),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.6),
                  blurRadius: 30,
                  spreadRadius: 10,
                ),
              ]
            : null,
      ),
    );
  }
}

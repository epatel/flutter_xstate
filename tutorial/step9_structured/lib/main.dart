/// Step 9: Structured Project Organization
///
/// This tutorial demonstrates how to organize a state machine project
/// into a clean, maintainable file structure:
///
/// ```
/// lib/
///   main.dart              # App entry point
///   machine/
///     cart_machine.dart    # Machine definition
///     models/              # Context and data models
///     events/              # Event classes
///     states/              # State builder functions
///       checkout/          # Compound state children
///     actions/             # Reusable action functions
///     guards/              # Reusable guard functions
///   widgets/               # UI components
/// ```
///
/// Key patterns demonstrated:
/// - State configurations as callback functions
/// - Actions and guards as static methods
/// - Compound states in subfolders
/// - Clean separation of concerns
///
/// Run with: flutter run -d chrome

import 'package:flutter/material.dart';
import 'package:flutter_xstate/flutter_xstate.dart';

import 'machine/cart_machine.dart';
import 'machine/events/cart_events.dart';
import 'machine/models/cart_context.dart';
import 'widgets/inspector_demo_screen.dart';

void main() {
  runApp(const StructuredDemoApp());
}

class StructuredDemoApp extends StatelessWidget {
  const StructuredDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Step 9: Structured Project',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: StateMachineProvider<CartContext, CartEvent>(
        machine: cartMachine,
        autoStart: true,
        child: Builder(
          builder: (context) {
            final actor = StateMachineProvider.of<CartContext, CartEvent>(
              context,
            );
            return InspectorDemoScreen(actor: actor);
          },
        ),
      ),
    );
  }
}

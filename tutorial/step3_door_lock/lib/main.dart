/// Step 3: Door Lock - Guards and Conditional Transitions
///
/// Run with: flutter run -d chrome

import 'package:flutter/material.dart';
import 'package:flutter_xstate/flutter_xstate.dart';

// ============================================================================
// CONTEXT
// ============================================================================

class DoorContext {
  final int failedAttempts;
  final int maxAttempts;
  final String correctPin;

  const DoorContext({
    this.failedAttempts = 0,
    this.maxAttempts = 3,
    this.correctPin = '1234',
  });

  DoorContext copyWith({int? failedAttempts}) => DoorContext(
        failedAttempts: failedAttempts ?? this.failedAttempts,
        maxAttempts: maxAttempts,
        correctPin: correctPin,
      );
}

// ============================================================================
// EVENTS
// ============================================================================

sealed class DoorEvent extends XEvent {}

class UnlockEvent extends DoorEvent {
  final String pin;
  UnlockEvent(this.pin);

  @override
  String get type => 'UNLOCK';
}

class LockEvent extends DoorEvent {
  @override
  String get type => 'LOCK';
}

class AdminOverrideEvent extends DoorEvent {
  @override
  String get type => 'ADMIN_OVERRIDE';
}

class ResetEvent extends DoorEvent {
  @override
  String get type => 'RESET';
}

// ============================================================================
// GUARD FUNCTIONS
// ============================================================================

bool isPinCorrect(DoorContext ctx, DoorEvent event) {
  if (event is UnlockEvent) {
    return event.pin == ctx.correctPin;
  }
  return false;
}

bool isPinIncorrect(DoorContext ctx, DoorEvent event) => !isPinCorrect(ctx, event);

bool isMaxAttemptsReached(DoorContext ctx, DoorEvent event) =>
    ctx.failedAttempts >= ctx.maxAttempts - 1;

bool isPinIncorrectAndMaxAttempts(DoorContext ctx, DoorEvent event) =>
    isPinIncorrect(ctx, event) && isMaxAttemptsReached(ctx, event);

// ============================================================================
// STATE MACHINE
// ============================================================================

final doorMachine = StateMachine.create<DoorContext, DoorEvent>(
  (m) => m
    ..context(const DoorContext())
    ..initial('locked')
    ..state(
      'locked',
      (s) => s
        // Correct PIN -> unlocked
        ..on<UnlockEvent>('unlocked', guard: isPinCorrect, actions: [
          (ctx, _) => ctx.copyWith(failedAttempts: 0),
        ])
        // Wrong PIN + max attempts -> lockout
        ..on<UnlockEvent>(
          'lockout',
          guard: isPinIncorrectAndMaxAttempts,
          actions: [
            (ctx, _) => ctx.copyWith(failedAttempts: ctx.failedAttempts + 1),
          ],
        )
        // Wrong PIN -> stay locked
        ..on<UnlockEvent>('locked', guard: isPinIncorrect, actions: [
          (ctx, _) => ctx.copyWith(failedAttempts: ctx.failedAttempts + 1),
        ])
        // Admin always works
        ..on<AdminOverrideEvent>('unlocked', actions: [
          (ctx, _) => ctx.copyWith(failedAttempts: 0),
        ]),
    )
    ..state(
      'unlocked',
      (s) => s..on<LockEvent>('locked'),
    )
    ..state(
      'lockout',
      (s) => s
        ..on<AdminOverrideEvent>('locked', actions: [
          (ctx, _) => ctx.copyWith(failedAttempts: 0),
        ])
        ..on<ResetEvent>('locked', actions: [
          (ctx, _) => ctx.copyWith(failedAttempts: 0),
        ]),
    ),
  id: 'doorLock',
);

// ============================================================================
// APP
// ============================================================================

void main() {
  runApp(const DoorLockApp());
}

class DoorLockApp extends StatelessWidget {
  const DoorLockApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Step 3: Door Lock',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: StateMachineProvider<DoorContext, DoorEvent>(
        machine: doorMachine,
        autoStart: true,
        child: const DoorLockScreen(),
      ),
    );
  }
}

class DoorLockScreen extends StatefulWidget {
  const DoorLockScreen({super.key});

  @override
  State<DoorLockScreen> createState() => _DoorLockScreenState();
}

class _DoorLockScreenState extends State<DoorLockScreen> {
  String _enteredPin = '';

  void _addDigit(String digit) {
    if (_enteredPin.length < 4) {
      setState(() => _enteredPin += digit);
    }
  }

  void _clearPin() {
    setState(() => _enteredPin = '');
  }

  void _submitPin(SendEvent<DoorEvent> send) {
    send(UnlockEvent(_enteredPin));
    _clearPin();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: const Text('Step 3: Door Lock'),
        backgroundColor: Colors.grey[850],
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: StateMachineBuilder<DoorContext, DoorEvent>(
          builder: (context, state, send) {
            final isLocked = state.value.matches('locked');
            final isUnlocked = state.value.matches('unlocked');
            final isLockout = state.value.matches('lockout');
            final ctx = state.context;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Door status icon
                  _DoorIcon(
                    isLocked: isLocked,
                    isUnlocked: isUnlocked,
                    isLockout: isLockout,
                  ),
                  const SizedBox(height: 24),

                  // State label
                  Text(
                    isUnlocked
                        ? 'UNLOCKED'
                        : isLockout
                            ? 'LOCKOUT'
                            : 'LOCKED',
                    style: TextStyle(
                      color: isUnlocked
                          ? Colors.green
                          : isLockout
                              ? Colors.red
                              : Colors.orange,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Attempts counter
                  if (isLocked)
                    Text(
                      'Failed attempts: ${ctx.failedAttempts}/${ctx.maxAttempts}',
                      style: TextStyle(color: Colors.grey[400]),
                    ),
                  const SizedBox(height: 32),

                  // PIN display
                  if (isLocked) ...[
                    _PinDisplay(pin: _enteredPin),
                    const SizedBox(height: 24),

                    // Keypad
                    _Keypad(
                      onDigit: _addDigit,
                      onClear: _clearPin,
                      onSubmit: () => _submitPin(send),
                      canSubmit: _enteredPin.length == 4,
                    ),
                    const SizedBox(height: 16),

                    Text(
                      'Hint: PIN is 1234',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],

                  // Unlocked actions
                  if (isUnlocked) ...[
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => send(LockEvent()),
                      icon: const Icon(Icons.lock),
                      label: const Text('LOCK DOOR'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                      ),
                    ),
                  ],

                  // Lockout actions
                  if (isLockout) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Too many failed attempts!',
                      style: TextStyle(color: Colors.red[300]),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => send(AdminOverrideEvent()),
                      icon: const Icon(Icons.admin_panel_settings),
                      label: const Text('ADMIN OVERRIDE'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: () => send(ResetEvent()),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reset System'),
                      style: TextButton.styleFrom(foregroundColor: Colors.grey),
                    ),
                  ],

                  // Admin override (always available when locked)
                  if (isLocked) ...[
                    const SizedBox(height: 32),
                    TextButton.icon(
                      onPressed: () => send(AdminOverrideEvent()),
                      icon: const Icon(Icons.admin_panel_settings),
                      label: const Text('Admin Override'),
                      style: TextButton.styleFrom(foregroundColor: Colors.grey),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DoorIcon extends StatelessWidget {
  final bool isLocked;
  final bool isUnlocked;
  final bool isLockout;

  const _DoorIcon({
    required this.isLocked,
    required this.isUnlocked,
    required this.isLockout,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isUnlocked
            ? Colors.green.withValues(alpha: 0.2)
            : isLockout
                ? Colors.red.withValues(alpha: 0.2)
                : Colors.orange.withValues(alpha: 0.2),
        border: Border.all(
          color: isUnlocked
              ? Colors.green
              : isLockout
                  ? Colors.red
                  : Colors.orange,
          width: 3,
        ),
      ),
      child: Icon(
        isUnlocked
            ? Icons.lock_open
            : isLockout
                ? Icons.block
                : Icons.lock,
        size: 60,
        color: isUnlocked
            ? Colors.green
            : isLockout
                ? Colors.red
                : Colors.orange,
      ),
    );
  }
}

class _PinDisplay extends StatelessWidget {
  final String pin;

  const _PinDisplay({required this.pin});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) {
        final isFilled = index < pin.length;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isFilled ? Colors.white : Colors.transparent,
            border: Border.all(color: Colors.white, width: 2),
          ),
        );
      }),
    );
  }
}

class _Keypad extends StatelessWidget {
  final void Function(String) onDigit;
  final VoidCallback onClear;
  final VoidCallback onSubmit;
  final bool canSubmit;

  const _Keypad({
    required this.onDigit,
    required this.onClear,
    required this.onSubmit,
    required this.canSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      child: Column(
        children: [
          for (var row in [
            ['1', '2', '3'],
            ['4', '5', '6'],
            ['7', '8', '9'],
            ['C', '0', 'OK'],
          ])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: row.map((key) {
                  if (key == 'C') {
                    return _KeypadButton(
                      label: key,
                      onPressed: onClear,
                      color: Colors.red[700],
                    );
                  } else if (key == 'OK') {
                    return _KeypadButton(
                      label: key,
                      onPressed: canSubmit ? onSubmit : null,
                      color: Colors.green[700],
                    );
                  } else {
                    return _KeypadButton(
                      label: key,
                      onPressed: () => onDigit(key),
                    );
                  }
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

class _KeypadButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color? color;

  const _KeypadButton({
    required this.label,
    this.onPressed,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: SizedBox(
        width: 64,
        height: 64,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: color ?? Colors.grey[700],
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(
            label,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}

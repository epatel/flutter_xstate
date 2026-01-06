/// Step 5: Todo App - Flutter Widget Integration
///
/// Demonstrates:
/// - StateMachineProvider
/// - StateMachineBuilder
/// - StateMachineSelector
///
/// Run with: flutter run -d chrome

import 'package:flutter/material.dart';
import 'package:flutter_xstate/flutter_xstate.dart';

// ============================================================================
// CONTEXT
// ============================================================================

class TodoItem {
  final String id;
  final String text;
  final bool completed;

  const TodoItem({
    required this.id,
    required this.text,
    this.completed = false,
  });

  TodoItem copyWith({String? text, bool? completed}) => TodoItem(
        id: id,
        text: text ?? this.text,
        completed: completed ?? this.completed,
      );
}

class TodoContext {
  final List<TodoItem> items;
  final String? editingId;

  const TodoContext({
    this.items = const [],
    this.editingId,
  });

  TodoContext copyWith({
    List<TodoItem>? items,
    String? editingId,
    bool clearEditing = false,
  }) =>
      TodoContext(
        items: items ?? this.items,
        editingId: clearEditing ? null : (editingId ?? this.editingId),
      );

  int get totalCount => items.length;
  int get completedCount => items.where((i) => i.completed).length;
  int get pendingCount => items.where((i) => !i.completed).length;
}

// ============================================================================
// EVENTS
// ============================================================================

sealed class TodoEvent extends XEvent {}

class AddTodoEvent extends TodoEvent {
  final String text;
  AddTodoEvent(this.text);

  @override
  String get type => 'ADD_TODO';
}

class RemoveTodoEvent extends TodoEvent {
  final String id;
  RemoveTodoEvent(this.id);

  @override
  String get type => 'REMOVE_TODO';
}

class ToggleTodoEvent extends TodoEvent {
  final String id;
  ToggleTodoEvent(this.id);

  @override
  String get type => 'TOGGLE_TODO';
}

class StartEditEvent extends TodoEvent {
  final String id;
  StartEditEvent(this.id);

  @override
  String get type => 'START_EDIT';
}

class SaveEditEvent extends TodoEvent {
  final String text;
  SaveEditEvent(this.text);

  @override
  String get type => 'SAVE_EDIT';
}

class CancelEditEvent extends TodoEvent {
  @override
  String get type => 'CANCEL_EDIT';
}

class ClearCompletedEvent extends TodoEvent {
  @override
  String get type => 'CLEAR_COMPLETED';
}

// ============================================================================
// STATE MACHINE
// ============================================================================

final todoMachine = StateMachine.create<TodoContext, TodoEvent>(
  (m) => m
    ..context(const TodoContext())
    ..initial('idle')
    ..state(
      'idle',
      (s) => s
        ..on<AddTodoEvent>('idle', actions: [
          (ctx, event) {
            final e = event as AddTodoEvent;
            final newItem = TodoItem(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              text: e.text,
            );
            return ctx.copyWith(items: [...ctx.items, newItem]);
          },
        ])
        ..on<RemoveTodoEvent>('idle', actions: [
          (ctx, event) {
            final e = event as RemoveTodoEvent;
            return ctx.copyWith(
              items: ctx.items.where((i) => i.id != e.id).toList(),
            );
          },
        ])
        ..on<ToggleTodoEvent>('idle', actions: [
          (ctx, event) {
            final e = event as ToggleTodoEvent;
            return ctx.copyWith(
              items: ctx.items.map((i) {
                if (i.id == e.id) {
                  return i.copyWith(completed: !i.completed);
                }
                return i;
              }).toList(),
            );
          },
        ])
        ..on<StartEditEvent>('editing', actions: [
          (ctx, event) {
            final e = event as StartEditEvent;
            return ctx.copyWith(editingId: e.id);
          },
        ])
        ..on<ClearCompletedEvent>('idle', actions: [
          (ctx, _) => ctx.copyWith(
                items: ctx.items.where((i) => !i.completed).toList(),
              ),
        ]),
    )
    ..state(
      'editing',
      (s) => s
        ..on<SaveEditEvent>('idle', actions: [
          (ctx, event) {
            final e = event as SaveEditEvent;
            return ctx.copyWith(
              items: ctx.items.map((i) {
                if (i.id == ctx.editingId) {
                  return i.copyWith(text: e.text);
                }
                return i;
              }).toList(),
              clearEditing: true,
            );
          },
        ])
        ..on<CancelEditEvent>('idle', actions: [
          (ctx, _) => ctx.copyWith(clearEditing: true),
        ]),
    ),
  id: 'todo',
);

// ============================================================================
// APP
// ============================================================================

void main() {
  runApp(const TodoApp());
}

class TodoApp extends StatelessWidget {
  const TodoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Step 5: Todo App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: StateMachineProvider<TodoContext, TodoEvent>(
        machine: todoMachine,
        autoStart: true,
        child: const TodoScreen(),
      ),
    );
  }
}

class TodoScreen extends StatelessWidget {
  const TodoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Step 5: Todo App'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: const [
          _TodoStats(),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              const _AddTodoInput(),
              const Divider(height: 1),
              const Expanded(child: _TodoList()),
              const _TodoFooter(),
            ],
          ),
          // Editing overlay
          const _EditingOverlay(),
        ],
      ),
    );
  }
}

// ============================================================================
// SELECTOR: Only rebuilds when count changes
// ============================================================================

class _TodoStats extends StatelessWidget {
  const _TodoStats();

  @override
  Widget build(BuildContext context) {
    return StateMachineSelector<TodoContext, TodoEvent, String>(
      selector: (ctx) => '${ctx.completedCount}/${ctx.totalCount}',
      builder: (context, stats, send) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                stats,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ============================================================================
// ADD TODO INPUT
// ============================================================================

class _AddTodoInput extends StatefulWidget {
  const _AddTodoInput();

  @override
  State<_AddTodoInput> createState() => _AddTodoInputState();
}

class _AddTodoInputState extends State<_AddTodoInput> {
  final _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return StateMachineBuilder<TodoContext, TodoEvent>(
      builder: (context, state, send) {
        void addTodo() {
          if (_controller.text.trim().isNotEmpty) {
            send(AddTodoEvent(_controller.text.trim()));
            _controller.clear();
          }
        }

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: const InputDecoration(
                    hintText: 'Add a new todo...',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => addTodo(),
                ),
              ),
              const SizedBox(width: 12),
              IconButton.filled(
                onPressed: addTodo,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

// ============================================================================
// TODO LIST
// ============================================================================

class _TodoList extends StatelessWidget {
  const _TodoList();

  @override
  Widget build(BuildContext context) {
    return StateMachineBuilder<TodoContext, TodoEvent>(
      builder: (context, state, send) {
        final items = state.context.items;

        if (items.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'No todos yet!',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return ListTile(
              leading: Checkbox(
                value: item.completed,
                onChanged: (_) => send(ToggleTodoEvent(item.id)),
              ),
              title: Text(
                item.text,
                style: TextStyle(
                  decoration: item.completed ? TextDecoration.lineThrough : null,
                  color: item.completed ? Colors.grey : null,
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => send(StartEditEvent(item.id)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () => send(RemoveTodoEvent(item.id)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ============================================================================
// FOOTER: Clear completed button
// ============================================================================

class _TodoFooter extends StatelessWidget {
  const _TodoFooter();

  @override
  Widget build(BuildContext context) {
    return StateMachineSelector<TodoContext, TodoEvent, int>(
      selector: (ctx) => ctx.completedCount,
      builder: (context, completedCount, send) {
        if (completedCount == 0) {
          return const SizedBox.shrink();
        }

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: Colors.grey[300]!),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$completedCount completed',
                style: TextStyle(color: Colors.grey[600]),
              ),
              TextButton.icon(
                onPressed: () => send(ClearCompletedEvent()),
                icon: const Icon(Icons.delete_sweep),
                label: const Text('Clear completed'),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ============================================================================
// EDITING OVERLAY
// ============================================================================

class _EditingOverlay extends StatefulWidget {
  const _EditingOverlay();

  @override
  State<_EditingOverlay> createState() => _EditingOverlayState();
}

class _EditingOverlayState extends State<_EditingOverlay> {
  final _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return StateMachineBuilder<TodoContext, TodoEvent>(
      buildWhen: (previous, current) =>
          previous.value.matches('editing') != current.value.matches('editing'),
      builder: (context, state, send) {
        if (!state.value.matches('editing')) {
          return const SizedBox.shrink();
        }

        final editingId = state.context.editingId;
        final item = state.context.items.firstWhere(
          (i) => i.id == editingId,
          orElse: () => const TodoItem(id: '', text: ''),
        );

        // Initialize controller with current text
        if (_controller.text.isEmpty) {
          _controller.text = item.text;
        }

        return Container(
          color: Colors.black54,
          child: Center(
            child: Card(
              margin: const EdgeInsets.all(32),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Edit Todo',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Todo text',
                      ),
                      autofocus: true,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () {
                            _controller.clear();
                            send(CancelEditEvent());
                          },
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: () {
                            send(SaveEditEvent(_controller.text.trim()));
                            _controller.clear();
                          },
                          child: const Text('Save'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/material.dart';
import '../cubits/todos_cubit.dart';
import '../models/todo.dart';

/// Interactive tile widget representing a single [Todo] item.
class TodoItemTile extends StatefulWidget {
  /// Creates a [TodoItemTile].
  const TodoItemTile({required this.todo, super.key});

  /// The todo item displayed by this tile.
  final Todo todo;

  @override
  State<TodoItemTile> createState() => _TodoItemTileState();
}

class _TodoItemTileState extends State<TodoItemTile> {
  late final TextEditingController _textController;
  late final FocusNode _focusNode;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.todo.description);
    _focusNode = FocusNode();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus && _isEditing) {
        _saveEdit();
      }
    });
  }

  @override
  void didUpdateWidget(TodoItemTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.todo.description != widget.todo.description) {
      _textController.text = widget.todo.description;
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _saveEdit() {
    setState(() => _isEditing = false);
    final text = _textController.text.trim();
    if (text.isNotEmpty) {
      context.read<TodosCubit>().edit(
            id: widget.todo.id,
            description: text,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<TodosCubit>();

    return ListTile(
      leading: Checkbox(
        value: widget.todo.completed,
        onChanged: (_) => cubit.toggle(widget.todo.id),
      ),
      title: _isEditing
          ? TextField(
              controller: _textController,
              focusNode: _focusNode,
              autofocus: true,
              onSubmitted: (_) => _saveEdit(),
            )
          : GestureDetector(
              onTap: () {
                setState(() => _isEditing = true);
                _focusNode.requestFocus();
              },
              child: Text(
                widget.todo.description,
                style: TextStyle(
                  decoration:
                      widget.todo.completed ? TextDecoration.lineThrough : null,
                  color: widget.todo.completed ? Colors.grey : null,
                ),
              ),
            ),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        onPressed: () => cubit.remove(widget.todo.id),
      ),
    );
  }
}

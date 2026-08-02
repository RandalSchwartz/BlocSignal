import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/material.dart';
import 'package:signals_flutter/signals_flutter.dart';

/// Item Model.
@immutable
class Item {
  const Item({
    required this.id,
    required this.value,
    this.isSelected = false,
  });

  final String id;
  final String value;
  final bool isSelected;

  Item copyWith({
    String? id,
    String? value,
    bool? isSelected,
  }) {
    return Item(
      id: id ?? this.id,
      value: value ?? this.value,
      isSelected: isSelected ?? this.isSelected,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Item &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          value == other.value &&
          isSelected == other.isSelected;

  @override
  int get hashCode => id.hashCode ^ value.hashCode ^ isSelected.hashCode;
}

/// State.
@immutable
class ComplexListState {
  const ComplexListState({
    this.items = const [],
  });

  final List<Item> items;

  ComplexListState copyWith({
    List<Item>? items,
  }) {
    return ComplexListState(
      items: items ?? this.items,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ComplexListState &&
          runtimeType == other.runtimeType &&
          _listEquals(items, other.items);

  @override
  int get hashCode => items.length.hashCode;

  static bool _listEquals(List<Item> a, List<Item> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Events.
sealed class ComplexListEvent {
  const ComplexListEvent();
}

final class ItemToggled extends ComplexListEvent {
  const ItemToggled(this.id);
  final String id;
}

final class ItemDeleted extends ComplexListEvent {
  const ItemDeleted(this.id);
  final String id;
}

final class SelectAllToggled extends ComplexListEvent {
  const SelectAllToggled();
}

final class BatchDeleted extends ComplexListEvent {
  const BatchDeleted();
}

final class ItemAdded extends ComplexListEvent {
  const ItemAdded(this.value);
  final String value;
}

/// [ComplexListBlocSignal] handles list actions and computes selection counts.
class ComplexListBlocSignal
    extends BlocSignal<ComplexListEvent, ComplexListState> {
  ComplexListBlocSignal({List<Item> initialItems = const []})
      : super(initialState: ComplexListState(items: initialItems)) {
    on<ItemToggled>(_onToggled);
    on<ItemDeleted>(_onDeleted);
    on<SelectAllToggled>(_onSelectAllToggled);
    on<BatchDeleted>(_onBatchDeleted);
    on<ItemAdded>(_onItemAdded);

    selectedCount = computed(() {
      return stateValue.items.where((i) => i.isSelected).length;
    });

    isAllSelected = computed(() {
      final items = stateValue.items;
      return items.isNotEmpty && items.every((i) => i.isSelected);
    });
  }

  late final ReadonlySignal<int> selectedCount;
  late final ReadonlySignal<bool> isAllSelected;

  void _onToggled(ItemToggled event, void Function(ComplexListState) emit) {
    final updated = stateValue.items.map((item) {
      return item.id == event.id
          ? item.copyWith(isSelected: !item.isSelected)
          : item;
    }).toList();
    emit(stateValue.copyWith(items: updated));
  }

  void _onDeleted(ItemDeleted event, void Function(ComplexListState) emit) {
    final updated = stateValue.items.where((i) => i.id != event.id).toList();
    emit(stateValue.copyWith(items: updated));
  }

  void _onSelectAllToggled(
      SelectAllToggled event, void Function(ComplexListState) emit) {
    final allSel = isAllSelected.value;
    final updated =
        stateValue.items.map((i) => i.copyWith(isSelected: !allSel)).toList();
    emit(stateValue.copyWith(items: updated));
  }

  void _onBatchDeleted(
      BatchDeleted event, void Function(ComplexListState) emit) {
    final remaining = stateValue.items.where((i) => !i.isSelected).toList();
    emit(stateValue.copyWith(items: remaining));
  }

  void _onItemAdded(ItemAdded event, void Function(ComplexListState) emit) {
    final newItem = Item(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      value: event.value,
    );
    emit(stateValue.copyWith(items: [...stateValue.items, newItem]));
  }
}

void main() {
  runApp(const ComplexListApp());
}

class ComplexListApp extends StatelessWidget {
  const ComplexListApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Complex List',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: BlocSignalProvider<ComplexListBlocSignal>(
        create: (_) => ComplexListBlocSignal(
          initialItems: const [
            Item(id: '1', value: 'Item Alpha'),
            Item(id: '2', value: 'Item Beta'),
            Item(id: '3', value: 'Item Gamma'),
            Item(id: '4', value: 'Item Delta'),
          ],
        ),
        child: const ComplexListPage(),
      ),
    );
  }
}

class ComplexListPage extends StatelessWidget {
  const ComplexListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<ComplexListBlocSignal>();
    return Scaffold(
      appBar: AppBar(
        title: BlocSignalBuilder<ComplexListBlocSignal, ComplexListState>(
          builder: (context, state) =>
              Text('Selected: ${bloc.selectedCount.value}'),
        ),
        actions: [
          BlocSignalBuilder<ComplexListBlocSignal, ComplexListState>(
            builder: (context, state) {
              return IconButton(
                icon: Icon(
                  bloc.isAllSelected.value
                      ? Icons.deselect
                      : Icons.select_all,
                ),
                onPressed: () => bloc.add(const SelectAllToggled()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: () => bloc.add(const BatchDeleted()),
          ),
        ],
      ),
      body:
          BlocSignalSelector<ComplexListBlocSignal, ComplexListState, List<Item>>(
        selector: (state) => state.items,
        builder: (context, items) {
          if (items.isEmpty) {
            return const Center(child: Text('No items remaining.'));
          }
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return ListTile(
                leading: Checkbox(
                  value: item.isSelected,
                  onChanged: (_) => bloc.add(ItemToggled(item.id)),
                ),
                title: Text(item.value),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                  onPressed: () => bloc.add(ItemDeleted(item.id)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

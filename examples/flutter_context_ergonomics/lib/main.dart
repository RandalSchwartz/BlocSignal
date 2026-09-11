import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/material.dart';
import 'package:signals_flutter/signals_flutter.dart';

void main() {
  runApp(const ContextErgonomicsApp());
}

// =============================================================================
// 1. Domain Models & State Containers
// =============================================================================

/// An individual item in the shopping cart.
@immutable
class CartItem {
  /// Creates a [CartItem].
  const CartItem({
    required this.id,
    required this.name,
    required this.price,
  });

  /// Unique identifier for the item.
  final String id;

  /// Display name of the item.
  final String name;

  /// Price in dollars.
  final double price;
}

/// Immutable state representing the shopping cart.
@immutable
class CartState {
  /// Creates a [CartState].
  const CartState({this.items = const []});

  /// Items currently in the cart.
  final List<CartItem> items;

  /// Total count of items in the cart.
  int get totalCount => items.length;

  /// Calculated subtotal price of all items in the cart.
  double get subtotal => items.fold(0, (acc, item) => acc + item.price);
}

/// Manages cart state with synchronous signal emissions.
class CartCubit extends CubitSignal<CartState> {
  /// Creates a [CartCubit] with an empty cart.
  CartCubit() : super(initialState: const CartState());

  /// Zero-closure provider factory constructor.
  ///
  /// Ignores the [BuildContext] parameter to enable direct constructor tearoffs
  /// in `BlocSignalProvider(create: CartCubit.create, ...)`.
  CartCubit.create(BuildContext _) : this();

  /// Adds a new [item] to the cart.
  void addItem(CartItem item) {
    emit(CartState(items: [...stateValue.items, item]));
  }

  /// Removes the last added item from the cart, if any.
  void removeLastItem() {
    if (stateValue.items.isEmpty) return;
    emit(
      CartState(
        items: stateValue.items.sublist(0, stateValue.items.length - 1),
      ),
    );
  }

  /// Clears all items from the cart.
  void clear() {
    emit(const CartState());
  }
}

/// Immutable state representing the logged-in user.
@immutable
class UserState {
  /// Creates a [UserState].
  const UserState({
    required this.name,
    this.isVip = false,
  });

  /// User display name.
  final String name;

  /// Whether the user qualifies for VIP member discounts.
  final bool isVip;

  /// Creates a copy of [UserState] with modified properties.
  UserState copyWith({String? name, bool? isVip}) {
    return UserState(
      name: name ?? this.name,
      isVip: isVip ?? this.isVip,
    );
  }
}

/// Manages user profile and VIP status.
class UserCubit extends CubitSignal<UserState> {
  /// Creates a [UserCubit] with default user Alice.
  UserCubit() : super(initialState: const UserState(name: 'Alice Johnson'));

  /// Zero-closure provider factory constructor.
  UserCubit.create(BuildContext _) : this();

  /// Toggles between standard member and VIP discount status.
  void toggleVip() {
    emit(stateValue.copyWith(isVip: !stateValue.isVip));
  }
}

// =============================================================================
// 2. Application Root & Providers
// =============================================================================

/// Root widget configuring providers using zero-closure constructor tearoffs.
class ContextErgonomicsApp extends StatelessWidget {
  /// Creates the root [ContextErgonomicsApp].
  const ContextErgonomicsApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Notice: Zero lambda closures needed in create callbacks:
    return MultiBlocSignalProvider(
      providers: const [
        BlocSignalProvider<CartCubit>(create: CartCubit.create),
        BlocSignalProvider<UserCubit>(create: UserCubit.create),
      ],
      child: MaterialApp(
        title: 'BlocSignal Context Ergonomics',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.deepPurple,
          ),
          useMaterial3: true,
        ),
        home: const ErgonomicsHomePage(),
      ),
    );
  }
}

/// Main dashboard showcasing modern contextual ergonomics.
class ErgonomicsHomePage extends StatelessWidget {
  /// Creates an [ErgonomicsHomePage].
  const ErgonomicsHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Context Ergonomics Showcase'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.touch_app), text: 'context.value'),
              Tab(icon: Icon(Icons.hub), text: 'context.state'),
              Tab(icon: Icon(Icons.compare_arrows), text: 'Architecture'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            ContextValueTab(),
            ContextStateTab(),
            ArchitectureComparisonTab(),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// 3. Tab 1: context.value & Scoped Micro-Rebuilds
// =============================================================================

/// Tracks widget rebuild count for visual inspection.
class RebuildBadge extends StatelessWidget {
  /// Creates a [RebuildBadge].
  const RebuildBadge({
    required this.label,
    required this.buildCount,
    super.key,
  });

  /// Human-readable label for this rebuild scope.
  final String label;

  /// Current rebuild count.
  final int buildCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.deepPurple.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.deepPurple.shade200),
      ),
      child: Text(
        '$label: build #$buildCount',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.deepPurple.shade800,
        ),
      ),
    );
  }
}

/// Demonstrates 1-line state reads via `context.value` and scoped `Builder`.
class ContextValueTab extends StatefulWidget {
  /// Creates a [ContextValueTab].
  const ContextValueTab({super.key});

  @override
  State<ContextValueTab> createState() => _ContextValueTabState();
}

class _ContextValueTabState extends State<ContextValueTab> {
  int _parentBuildCount = 0;
  int _scopedBuildCount = 0;

  static const _sampleProducts = [
    CartItem(id: '1', name: 'Mechanical Keyboard', price: 149),
    CartItem(id: '2', name: 'Wireless Mouse', price: 79),
    CartItem(id: '3', name: '4K Monitor', price: 399),
  ];

  @override
  Widget build(BuildContext context) {
    _parentBuildCount++;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Parent rebuild counter card
        Card(
          elevation: 0,
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Parent Widget Scope',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    RebuildBadge(
                      label: 'Parent Scope',
                      buildCount: _parentBuildCount,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Notice that the parent widget does NOT rebuild when cart '
                  'items are added because the state read is scoped inside the '
                  'inner Builder below.',
                  style: TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Scoped Builder Card with context.value
        Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Scoped Cart Reader',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    // Inner scoped rebuild badge:
                    Builder(
                      builder: (ctx) {
                        _scopedBuildCount++;
                        // Subscribes ONLY this Builder element to Cart updates:
                        final _ = ctx.value<CartCubit, CartState>();
                        return RebuildBadge(
                          label: 'Scoped Builder',
                          buildCount: _scopedBuildCount,
                        );
                      },
                    ),
                  ],
                ),
                const Divider(height: 24),

                // Scoped cart statistics:
                Builder(
                  builder: (ctx) {
                    // Single-line read and element subscription:
                    final cart = ctx.value<CartCubit, CartState>();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const CircleAvatar(
                            child: Icon(Icons.shopping_bag),
                          ),
                          title: Text('Items in Cart: ${cart.totalCount}'),
                          subtitle: Text(
                            'Subtotal: \$${cart.subtotal.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          trailing: Chip(
                            label: Text(
                              cart.totalCount == 0
                                  ? 'Empty'
                                  : '${cart.totalCount} item(s)',
                            ),
                          ),
                        ),
                        if (cart.items.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: cart.items.map((item) {
                              return Chip(
                                avatar: const Icon(Icons.check, size: 16),
                                label: Text(
                                  '${item.name} (\$${item.price.toInt()})',
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),

                // Action controls:
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ..._sampleProducts.map((product) {
                      return FilledButton.tonalIcon(
                        icon: const Icon(Icons.add_shopping_cart, size: 18),
                        label: Text('Add ${product.name}'),
                        onPressed: () {
                          // context.read reads container without subscribing:
                          context.read<CartCubit>().addItem(product);
                        },
                      );
                    }),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.remove_circle_outline, size: 18),
                      label: const Text('Remove Last'),
                      onPressed: () {
                        context.read<CartCubit>().removeLastItem();
                      },
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Clear Cart'),
                      onPressed: () {
                        context.read<CartCubit>().clear();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Side-by-side code snippet callout:
        Card(
          elevation: 0,
          color: Colors.grey.shade100,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade300),
          ),
          child: const Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Code Contrast: The Builder Pyramid vs context.value',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                SizedBox(height: 8),
                Text(
                  r'''
// Classic flutter_bloc: Heavy builder pyramid
BlocBuilder<CartCubit, CartState>(
  builder: (context, state) => Text("Count: ${state.totalCount}"),
);

// Modern BlocSignal: 1-line read with element rebuild
final count = context.value<CartCubit, CartState>().totalCount;
Text("Count: $count");''',
                  style: TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// 4. Tab 2: context.state & Cross-Container Reactive Composition
// =============================================================================

/// Demonstrates cross-container signal composition with `context.state`
/// and `SignalBuilder`.
class ContextStateTab extends StatelessWidget {
  /// Creates a [ContextStateTab].
  const ContextStateTab({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. Look up reactive signals WITHOUT subscribing this widget element:
    final cartSignal = context.state<CartCubit, CartState>();
    final userSignal = context.state<UserCubit, UserState>();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // User profile card
        Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Builder(
                      builder: (ctx) {
                        // Subscribe this row only to UserState changes:
                        final user = ctx.value<UserCubit, UserState>();
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              user.isVip
                                  ? '🌟 VIP Member (20% Discount)'
                                  : 'Standard Customer',
                              style: TextStyle(
                                color: user.isVip
                                    ? Colors.amber.shade800
                                    : Colors.grey.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
                FilledButton.tonal(
                  onPressed: () {
                    context.read<UserCubit>().toggleVip();
                  },
                  child: const Text('Toggle VIP'),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Reactive Multi-Container Summary Card
        Card(
          elevation: 2,
          color: Colors.deepPurple.shade50,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.auto_awesome, color: Colors.deepPurple),
                    SizedBox(width: 8),
                    Text(
                      'Reactive Checkout Calculation (SignalBuilder)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.deepPurple,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Reactive evaluation inside SignalBuilder combining signals:
                SignalBuilder(
                  builder: (context) {
                    final cart = cartSignal.value;
                    final user = userSignal.value;

                    final subtotal = cart.subtotal;
                    final discount = user.isVip ? (subtotal * 0.20) : 0.0;
                    final total = subtotal - discount;

                    return Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Subtotal:'),
                            Text('\$${subtotal.toStringAsFixed(2)}'),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'VIP Discount (20%):',
                              style: TextStyle(
                                color: user.isVip
                                    ? Colors.green.shade700
                                    : Colors.grey,
                              ),
                            ),
                            Text(
                              user.isVip
                                  ? '-\$${discount.toStringAsFixed(2)}'
                                  : r'$0.00',
                              style: TextStyle(
                                color: user.isVip
                                    ? Colors.green.shade700
                                    : Colors.grey,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Final Total:',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '\$${total.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.deepPurple,
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Quick add buttons for testing reactive total:
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text(r'Add $50 Item'),
              onPressed: () {
                context.read<CartCubit>().addItem(
                      CartItem(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        name: 'Special Accessory',
                        price: 50,
                      ),
                    );
              },
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.clear),
              label: const Text('Reset Cart'),
              onPressed: () {
                context.read<CartCubit>().clear();
              },
            ),
          ],
        ),

        const SizedBox(height: 20),

        // Architectural insight card
        Card(
          elevation: 0,
          color: Colors.grey.shade100,
          child: const Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Why context.state is Crucial for Signal Graphs',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                SizedBox(height: 8),
                Text(
                  '1. In classic flutter_bloc, combining 2 cubits required '
                  'MultiBlocBuilder or nested BlocBuilders.\n'
                  '2. In BlocSignal, context.state<B, S>() extracts the '
                  'ReadonlySignal<S> without triggering widget rebuilds.\n'
                  '3. Passing these signals into SignalBuilder forms a '
                  'push-pull reactive graph.\n'
                  '4. Crucially, context.state still registers an '
                  'InheritedWidget dependency with listen: true so if an '
                  'ancestor swaps container instances, signal references '
                  'rebind automatically without zombie memory leaks.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// 5. Tab 3: Architecture & Method Comparison Matrix
// =============================================================================

/// Matrix comparing all BuildContext state reading methods.
class ArchitectureComparisonTab extends StatelessWidget {
  /// Creates an [ArchitectureComparisonTab].
  const ArchitectureComparisonTab({super.key});

  @override
  Widget build(BuildContext context) {
    const comparisonRows = [
      _MethodComparison(
        method: 'context.read<B>()',
        purpose: 'Event dispatch & method invocation',
        rebuildsOnState: false,
        rebindsOnSwap: false,
        description:
            'Looks up container once without subscribing. Ideal for onPressed.',
      ),
      _MethodComparison(
        method: 'context.watch<B>()',
        purpose: 'Container instance observation',
        rebuildsOnState: false,
        rebindsOnSwap: true,
        description:
            'Rebuilds ONLY if an ancestor replaces the container instance. '
            'Does NOT rebuild on state emissions.',
      ),
      _MethodComparison(
        method: 'context.value<B, S>()',
        purpose: 'Single-line state subscription',
        rebuildsOnState: true,
        rebindsOnSwap: true,
        description: 'Subscribes BuildContext element to state emissions via '
            'context.select. Perfect for widget build().',
      ),
      _MethodComparison(
        method: 'context.state<B, S>()',
        purpose: 'Signal graph composition',
        rebuildsOnState: false,
        rebindsOnSwap: true,
        description:
            'Returns ReadonlySignal<S>. Safe for computed() and SignalBuilder '
            'without polluting widget rebuild loops.',
      ),
      _MethodComparison(
        method: 'context.select<B, R>(selector)',
        purpose: 'Fine-grained property slicing',
        rebuildsOnState: true,
        rebindsOnSwap: true,
        description:
            'Rebuilds element only when selector(bloc) returns an unequal '
            'value.',
      ),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'BuildContext Extensions in BlocSignal',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'BlocSignal decouples container lifecycle swapping from state '
          'emissions. Choose the precise method matching your intent:',
          style: TextStyle(fontSize: 13, color: Colors.black87),
        ),
        const SizedBox(height: 16),
        ...comparisonRows.map((row) {
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        row.method,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Colors.deepPurple,
                        ),
                      ),
                      Wrap(
                        spacing: 4,
                        children: [
                          Chip(
                            padding: EdgeInsets.zero,
                            labelPadding: const EdgeInsets.symmetric(
                              horizontal: 6,
                            ),
                            visualDensity: VisualDensity.compact,
                            label: Text(
                              row.rebuildsOnState
                                  ? 'Rebuilds on State'
                                  : 'No State Rebuild',
                              style: TextStyle(
                                fontSize: 10,
                                color: row.rebuildsOnState
                                    ? Colors.green.shade800
                                    : Colors.grey.shade700,
                              ),
                            ),
                            backgroundColor: row.rebuildsOnState
                                ? Colors.green.shade50
                                : Colors.grey.shade100,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    row.purpose,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    row.description,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _MethodComparison {
  const _MethodComparison({
    required this.method,
    required this.purpose,
    required this.rebuildsOnState,
    required this.rebindsOnSwap,
    required this.description,
  });

  final String method;
  final String purpose;
  final bool rebuildsOnState;
  final bool rebindsOnSwap;
  final String description;
}

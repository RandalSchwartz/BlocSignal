import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../docs_callout.dart';
import '../docs_code_block.dart';
import '../docs_toc.dart';

/// Documentation recipe covering targeted domain mixins and reactive signal composition.
class const DocsRecipeDomainMixinsPage({super.key}) extends StatelessComponent {
  static const List<TocHeading> headings = [
    TocHeading(
      title: 'The Core Problem: The Cubit God-Object',
      anchor: 'the-core-problem',
    ),
    TocHeading(
      title: 'Mental Model: Projections vs. Mutable State',
      anchor: 'mental-model',
    ),
    TocHeading(
      title: 'The Pattern: mixin on CubitSignal<T>',
      anchor: 'targeted-mixins',
    ),
    TocHeading(
      title: 'Cascading Reactive Dependency Graphs',
      anchor: 'reactive-cascade',
    ),
    TocHeading(
      title: 'Write Once, Test Once: Isolated Verification',
      anchor: 'write-once-test-once',
    ),
    TocHeading(
      title: 'Case Study: Fast Immutable Collections Shopping Cart',
      anchor: 'case-study-fic',
    ),
  ];

  @override
  Component build(BuildContext context) {
    return article(classes: 'docs-article', [
      header(classes: 'docs-article-header', [
        div(classes: 'docs-badge', [
          Component.text('🛠️ Architecture Recipes'),
        ]),
        h1([Component.text('Domain Mixins & Reactive Composition')]),
        p(classes: 'docs-lead', [
          Component.text(
            'Decompose complex enterprise domain logic (such as tiered discounts, tax rules, and shipping thresholds) into modular, reusable Dart mixins with declarative computed signals.',
          ),
        ]),
      ]),

      // 1. The Core Problem
      section(id: 'the-core-problem', classes: 'docs-section', [
        h2([Component.text('The Core Problem: The Cubit God-Object')]),
        p([
          Component.text(
            'In real-world applications, domain rules quickly multiply. Consider an e-commerce checkout flow: you start with adding and removing items from a cart. Soon, product requirements add promotional coupon codes, tiered volume discounts, regional sales tax, and free freight thresholds.',
          ),
        ]),
        p([
          Component.text(
            'In traditional state management patterns, developers face an unpleasant dilemma:',
          ),
        ]),
        ul([
          li([
            strong([Component.text('Fat State Dilemma: ')]),
            Component.text(
              'Storing derived fields (subtotal, tax, shipping, grand total) directly in the state record forces the Cubit to manually recalculate every single derived number whenever any item is touched, introducing repetitive boilerplate and synchronization bugs.',
            ),
          ]),
          li([
            strong([Component.text('God-Cubit Dilemma: ')]),
            Component.text(
              'Placing all calculation methods and state handlers directly inside one monolithic Cubit class bloats it to hundreds of lines, intertwining persistence, time-travel history, UI events, and pricing math into a single rigid structure.',
            ),
          ]),
        ]),
      ]),

      // 2. Mental Model: Projections vs. Mutable State
      section(id: 'mental-model', classes: 'docs-section', [
        h2([Component.text('Mental Model: Projections vs. Mutable State')]),
        p([
          Component.text(
            'Developers migrating from classic BLoC or Riverpod often hesitate when seeing properties on a Cubit: ',
          ),
          em([
            Component.text(
              '"Isn\'t exposing properties like subtotal directly on the Cubit a code smell?"',
            ),
          ]),
        ]),
        p([
          Component.text('If '),
          code([Component.text('subtotal')]),
          Component.text(
            ' were an unmanaged mutable variable, that concern would be valid. However, in BlocSignal, derived properties are modeled with ',
          ),
          code([Component.text('computed(...)')]),
          Component.text(' and exposed as '),
          code([Component.text('ReadonlySignal<T>')]),
          Component.text('.'),
        ]),
        const DocsCallout(
          type: CalloutType.tip,
          title: 'Computed Signals are Projections, Not Rogue State',
          children: [
            p([
              Component.text(
                'A computed signal is a lazy, memoized, push-pull reactive projection of stateValue. It does not escape unidirectional data flow; rather, it derives pure values synchronously from stateValue and caches results until its upstream dependencies emit a new state.',
              ),
            ]),
          ],
        ),
        p([
          Component.text(
            'Because computed signals evaluate lazily and de-duplicate emissions, widgets and observers subscribing to them rebuild only when their derived slice of data actually changes.',
          ),
        ]),
      ]),

      // 3. The Pattern: mixin on CubitSignal<T>
      section(id: 'targeted-mixins', classes: 'docs-section', [
        h2([Component.text('The Pattern: mixin on CubitSignal<T>')]),
        p([
          Component.text(
            'To maintain separation of concerns, extract domain calculations into a Dart mixin targeted onto your state container using an ',
          ),
          code([Component.text('on CubitSignal<State>')]),
          Component.text(' clause:'),
        ]),
        const DocsCodeBlock(
          filename: 'cart_pricing_mixin.dart',
          language: 'dart',
          code: '''
import 'package:bloc_signals/bloc_signals.dart';
import 'package:signals_core/signals_core.dart';
import 'shopping_cart_state.dart';

/// Domain mixin encapsulating pricing and discount rules.
mixin CartPricingMixin on CubitSignal<ShoppingCartState> {
  /// Base subtotal derived lazily from current cart items.
  late final subtotal = computed(() {
    return stateValue.items.values.fold(
      0.0,
      (sum, item) => sum + item.lineTotal,
    );
  });

  /// Total physical units in cart across all items.
  late final totalItemCount = computed(() {
    return stateValue.items.values.fold(
      0,
      (sum, item) => sum + item.quantity,
    );
  });

  /// Whether the shopping cart is completely empty.
  late final isCartEmpty = computed(() => stateValue.items.isEmpty);
}''',
        ),
        p([
          Component.text(
            'Applying the mixin to your core Cubit is declarative and clean:',
          ),
        ]),
        const DocsCodeBlock(
          filename: 'shopping_cart_cubit.dart',
          language: 'dart',
          code: '''
class ShoppingCartCubit extends HydratedCubitSignal<ShoppingCartState>
    with ReplayCubitMixin<ShoppingCartState>, CartPricingMixin {
  ShoppingCartCubit()
    : super(
        initialState: (
          items: const IMap.empty(),
          promoCode: null,
          isCheckingOut: false,
        ),
      );

  void addItem(CartItem item) {
    emit((
      items: stateValue.items.add(item.id, item),
      promoCode: stateValue.promoCode,
      isCheckingOut: stateValue.isCheckingOut,
    ));
  }
}''',
        ),
      ]),

      // 4. Cascading Reactive Graphs
      section(id: 'reactive-cascade', classes: 'docs-section', [
        h2([Component.text('Cascading Reactive Dependency Graphs')]),
        p([
          Component.text(
            'One of the greatest advantages of reactive signals is how naturally they compose. Computed signals can depend on other computed signals to form a declarative dependency graph without streams or microtask queues:',
          ),
        ]),
        const DocsCodeBlock(
          filename: 'cascading_pricing.dart',
          language: 'dart',
          code: '''
mixin CartPricingMixin on CubitSignal<ShoppingCartState> {
  /// 1. Base subtotal
  late final subtotal = computed(() => stateValue.items.values.fold(
        0.0,
        (sum, item) => sum + item.lineTotal,
      ));

  /// 2. Promotional discount (depends on subtotal and promoCode)
  late final discountAmount = computed(() {
    final code = stateValue.promoCode;
    if (code == 'SAVE10') return subtotal.value * 0.10;
    if (code == 'HALF') return subtotal.value * 0.50;
    return 0.0;
  });

  /// 3. Dynamic shipping fee (free shipping above \$50)
  late final shippingFee = computed(() {
    if (subtotal.value == 0.0 || subtotal.value >= 50.0) return 0.0;
    return 5.99;
  });

  /// 4. Estimated sales tax (8.25% on taxable base)
  late final taxAmount = computed(() {
    final taxableBase = subtotal.value - discountAmount.value;
    return taxableBase > 0.0 ? taxableBase * 0.0825 : 0.0;
  });

  /// 5. Grand total composing all upstream signals
  late final grandTotal = computed(() {
    final total = subtotal.value - discountAmount.value + shippingFee.value + taxAmount.value;
    return total < 0.0 ? 0.0 : total;
  });
}''',
        ),
        p([
          Component.text(
            'When a customer applies a coupon code, only the promotional discount and downstream totals re-evaluate. The base subtotal and item count remain untouched in cache.',
          ),
        ]),
      ]),

      // 5. Write Once, Test Once: Isolated Verification
      section(id: 'write-once-test-once', classes: 'docs-section', [
        h2([Component.text('Write Once, Test Once: Isolated Verification')]),
        p([
          Component.text('Because the domain mixin is constrained only by '),
          code([Component.text('on CubitSignal<ShoppingCartState>')]),
          Component.text(
            ', you can test intricate pricing and business rules against a minimal test harness Cubit without requiring hydrated disk storage, mock databases, or UI widgets:',
          ),
        ]),
        const DocsCodeBlock(
          filename: 'cart_pricing_mixin_test.dart',
          language: 'dart',
          code: '''
/// Minimal test harness for pricing logic
class TestCartCubit extends CubitSignal<ShoppingCartState>
    with CartPricingMixin {
  TestCartCubit({ShoppingCartState? initialState})
    : super(
        initialState: initialState ??
            (
              items: const IMap.empty(),
              promoCode: null,
              isCheckingOut: false,
            ),
      );

  void updateState(ShoppingCartState nextState) => emit(nextState);
}

void main() {
  test('discounts and tiered shipping compose accurately', () {
    final cubit = TestCartCubit();

    cubit.updateState((
      items: IMap({'1': const CartItem(id: '1', price: 40.0, quantity: 1)}),
      promoCode: null,
      isCheckingOut: false,
    ));

    expect(cubit.subtotal.value, 40.0);
    expect(cubit.shippingFee.value, 5.99); // Under \$50 threshold

    // Apply promo code
    cubit.updateState((
      items: cubit.stateValue.items,
      promoCode: 'SAVE10',
      isCheckingOut: false,
    ));

    expect(cubit.discountAmount.value, 4.00); // 10% of \$40
  });
}''',
        ),
        const DocsCallout(
          type: CalloutType.important,
          title: 'High Test Ergonomics',
          children: [
            p([
              Component.text(
                'Testing domain rules against a lightweight test Cubit means your test suite runs in milliseconds with zero dependencies, yet proves correctness across any Cubit that incorporates the mixin.',
              ),
            ]),
          ],
        ),
      ]),

      // 6. Case Study: Fast Immutable Collections Shopping Cart
      section(id: 'case-study-fic', classes: 'docs-section', [
        h2([
          Component.text(
            'Case Study: Fast Immutable Collections Shopping Cart',
          ),
        ]),
        p([
          Component.text(
            'You can inspect a complete, production-ready implementation of this pattern in the ',
          ),
          code([Component.text('examples/fic_shopping_cart')]),
          Component.text(' reference app:'),
        ]),
        ul([
          li([
            strong([Component.text('Fast Immutable Collections (IMap): ')]),
            Component.text('Ensures true value equality and O(1) mutations.'),
          ]),
          li([
            strong([Component.text('HydratedMixin: ')]),
            Component.text('Persists cart items to disk across app restarts.'),
          ]),
          li([
            strong([Component.text('ReplayCubitMixin: ')]),
            Component.text('Provides instant undo and redo state history.'),
          ]),
          li([
            strong([Component.text('CartPricingMixin: ')]),
            Component.text(
              'Encapsulates subtotal, promo code parsing, discounts, and grand totals into modular signals.',
            ),
          ]),
        ]),
        p([
          Component.text(
            'Check out the full worked example and run it locally to see reactive domain mixins in action!',
          ),
        ]),
      ]),
    ]);
  }
}

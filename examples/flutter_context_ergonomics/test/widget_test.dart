import 'package:flutter/material.dart';
import 'package:flutter_context_ergonomics/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ContextErgonomicsApp Widget Tests', () {
    setUp(() {
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      binding.platformDispatcher.views.first.physicalSize = const Size(
        1200,
        1600,
      );
      binding.platformDispatcher.views.first.devicePixelRatio = 1.0;
    });

    tearDown(() {
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      binding.platformDispatcher.views.first.resetPhysicalSize();
      binding.platformDispatcher.views.first.resetDevicePixelRatio();
    });

    testWidgets(
      'renders initial empty cart and updates with context.value',
      (tester) async {
        await tester.pumpWidget(const ContextErgonomicsApp());
        await tester.pumpAndSettle();

        // Verify app title and initial state:
        expect(find.text('Context Ergonomics Showcase'), findsOneWidget);
        expect(find.text('Items in Cart: 0'), findsOneWidget);
        expect(find.text(r'Subtotal: $0.00'), findsOneWidget);
        expect(find.text('Empty'), findsOneWidget);

        // Add Mechanical Keyboard:
        final addKeyboardBtn = find.text('Add Mechanical Keyboard');
        expect(addKeyboardBtn, findsOneWidget);
        await tester.tap(addKeyboardBtn);
        await tester.pumpAndSettle();

        // Verify updated count and subtotal:
        expect(find.text('Items in Cart: 1'), findsOneWidget);
        expect(find.text(r'Subtotal: $149.00'), findsOneWidget);
        expect(find.text('1 item(s)'), findsOneWidget);
        expect(find.text(r'Mechanical Keyboard ($149)'), findsOneWidget);

        // Add Wireless Mouse:
        final addMouseBtn = find.text('Add Wireless Mouse');
        await tester.tap(addMouseBtn);
        await tester.pumpAndSettle();

        expect(find.text('Items in Cart: 2'), findsOneWidget);
        expect(find.text(r'Subtotal: $228.00'), findsOneWidget);

        // Remove last item:
        final removeBtn = find.text('Remove Last');
        await tester.tap(removeBtn);
        await tester.pumpAndSettle();

        expect(find.text('Items in Cart: 1'), findsOneWidget);
        expect(find.text(r'Subtotal: $149.00'), findsOneWidget);

        // Clear cart:
        final clearBtn = find.text('Clear Cart');
        await tester.tap(clearBtn);
        await tester.pumpAndSettle();

        expect(find.text('Items in Cart: 0'), findsOneWidget);
        expect(find.text(r'Subtotal: $0.00'), findsOneWidget);
      },
    );

    testWidgets(
      'evaluates reactive multi-cubit calculations via context.state '
      'and SignalBuilder',
      (tester) async {
        await tester.pumpWidget(const ContextErgonomicsApp());
        await tester.pumpAndSettle();

        // Switch to Tab 2: context.state:
        final tab2 = find.text('context.state');
        await tester.tap(tab2);
        await tester.pumpAndSettle();

        // Verify initial user status and totals:
        expect(find.text('Alice Johnson'), findsOneWidget);
        expect(find.text('Standard Customer'), findsOneWidget);
        expect(find.text('Subtotal:'), findsOneWidget);
        expect(find.text(r'$0.00'), findsNWidgets(3));

        // Add $50 item:
        final addFiftyBtn = find.text(r'Add $50 Item');
        await tester.tap(addFiftyBtn);
        await tester.pumpAndSettle();

        expect(find.text(r'$50.00'), findsWidgets);
        expect(find.text(r'$0.00'), findsOneWidget); // VIP discount is 0

        // Toggle VIP:
        final toggleVipBtn = find.text('Toggle VIP');
        await tester.tap(toggleVipBtn);
        await tester.pumpAndSettle();

        // Verify VIP status and 20% discount ($10):
        expect(find.text('🌟 VIP Member (20% Discount)'), findsOneWidget);
        expect(find.text(r'-$10.00'), findsOneWidget);
        expect(find.text(r'$40.00'), findsOneWidget);

        // Reset cart:
        final resetBtn = find.text('Reset Cart');
        await tester.tap(resetBtn);
        await tester.pumpAndSettle();

        expect(find.text(r'$0.00'), findsWidgets);
      },
    );

    testWidgets('renders architectural comparison matrix tab', (tester) async {
      await tester.pumpWidget(const ContextErgonomicsApp());
      await tester.pumpAndSettle();

      // Switch to Tab 3: Architecture:
      final tab3 = find.text('Architecture');
      await tester.tap(tab3);
      await tester.pumpAndSettle();

      expect(
        find.text('BuildContext Extensions in BlocSignal'),
        findsOneWidget,
      );
      expect(find.text('context.read<B>()'), findsOneWidget);
      expect(find.text('context.watch<B>()'), findsOneWidget);
      expect(find.text('context.value<B, S>()'), findsOneWidget);
      expect(find.text('context.state<B, S>()'), findsOneWidget);
      expect(find.text('context.select<B, R>(selector)'), findsOneWidget);
    });
  });
}

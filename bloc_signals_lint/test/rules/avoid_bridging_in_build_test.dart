import 'package:analyzer/error/error.dart';
import 'package:bloc_signals_lint/src/rules/avoid_bridging_in_build.dart';
import 'package:test/test.dart';

import '../src/lint_test_harness.dart';

void main() {
  tearDownAll(disposeLintTestHarness);

  group('(Issue #500) AvoidBridgingInBuild', () {
    test('rule metadata is properly configured', () {
      final rule = AvoidBridgingInBuild();
      expect(
        rule.diagnosticCode.lowerCaseName,
        equals('avoid_bridging_in_build'),
      );
      expect(rule.diagnosticCode.severity, equals(DiagnosticSeverity.INFO));
      expect(rule.diagnosticCode.problemMessage, contains('build()'));
      expect(rule.diagnosticCode.correctionMessage, isNotNull);
    });

    test('flags .toBlocSignal() inside Widget.build()', () async {
      const badCode = '''
import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';

class MyWidget extends StatelessWidget {
  final ValueNotifier<int> notifier = ValueNotifier<int>(0);

  @override
  Widget build(BuildContext context) {
    final bloc = notifier.toBlocSignal();
    return Container();
  }
}
''';
      final diagnostics = await runLintRule(AvoidBridgingInBuild(), badCode);
      expect(diagnostics, hasLength(1));
      expect(diagnostics.first.lexeme, equals('toBlocSignal'));
    });

    test('flags .toAsyncBlocSignal() inside Widget.build()', () async {
      const badCode = '''
import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';

class MyWidget extends StatelessWidget {
  final Stream<int> stream = Stream<int>.empty();

  @override
  Widget build(BuildContext context) {
    final bloc = stream.toAsyncBlocSignal();
    return Container();
  }
}
''';
      final diagnostics = await runLintRule(AvoidBridgingInBuild(), badCode);
      expect(diagnostics, hasLength(1));
      expect(diagnostics.first.lexeme, equals('toAsyncBlocSignal'));
    });

    test('flags .toValueListenable() inside State.build()', () async {
      const badCode = '''
import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';

class CounterCubit extends CubitSignal<int> {
  CounterCubit() : super(initialState: 0);
}

class MyState extends State<StatefulWidget> {
  final CounterCubit cubit = CounterCubit();

  @override
  Widget build(BuildContext context) {
    final listenable = cubit.toValueListenable();
    return Container();
  }
}
''';
      final diagnostics = await runLintRule(AvoidBridgingInBuild(), badCode);
      expect(diagnostics, hasLength(1));
      expect(diagnostics.first.lexeme, equals('toValueListenable'));
    });

    test(
      'flags ListenableBlocSignal and ListenableBlocSignal.fromValueListenable '
      'inside Widget.build()',
      () async {
        const badCode = '''
import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';

class MyWidget extends StatelessWidget {
  final ValueNotifier<int> notifier = ValueNotifier<int>(0);

  @override
  Widget build(BuildContext context) {
    final a = ListenableBlocSignal<int>(notifier, readState: () => 0);
    final b = ListenableBlocSignal<int>.fromValueListenable(notifier);
    return Container();
  }
}
''';
        final diagnostics = await runLintRule(AvoidBridgingInBuild(), badCode);
        expect(diagnostics, hasLength(2));
      },
    );

    test(
      'excludes nested FunctionExpression callbacks inside build()',
      () async {
        const goodCode = '''
import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';

class MyWidget extends StatelessWidget {
  final ValueNotifier<int> notifier = ValueNotifier<int>(0);

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () {
        final bloc = notifier.toBlocSignal();
        final wrapped = ListenableBlocSignal<int>.fromValueListenable(notifier);
      },
      child: Container(),
    );
  }
}
''';
        final diagnostics = await runLintRule(AvoidBridgingInBuild(), goodCode);
        expect(diagnostics, isEmpty);
      },
    );

    test('allows bridging in initState() and non-build methods', () async {
      const goodCode = '''
import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';

class MyState extends State<StatefulWidget> {
  final ValueNotifier<int> notifier = ValueNotifier<int>(0);
  late final BlocSignalBase<int> bloc;

  void initState() {
    bloc = notifier.toBlocSignal();
    final wrapped = ListenableBlocSignal<int>.fromValueListenable(notifier);
    final listenable = bloc.toValueListenable();
  }

  @override
  Widget build(BuildContext context) {
    return Container();
  }
}
''';
      final diagnostics = await runLintRule(AvoidBridgingInBuild(), goodCode);
      expect(diagnostics, isEmpty);
    });

    test('ignores build() on non-UI classes', () async {
      const goodCode = '''
import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';

class NotAWidget {
  final ValueNotifier<int> notifier = ValueNotifier<int>(0);

  void build() {
    final bloc = notifier.toBlocSignal();
    final wrapped = ListenableBlocSignal<int>.fromValueListenable(notifier);
  }
}
''';
      final diagnostics = await runLintRule(AvoidBridgingInBuild(), goodCode);
      expect(diagnostics, isEmpty);
    });

    test('flags Stream.toBlocSignal(), Future.toBlocSignal(), and '
        'Future.toAsyncBlocSignal() inside Jaspr StatelessComponent and '
        'HookWidget build()', () async {
      const badCode = '''
import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:bloc_signals_jaspr/bloc_signals_jaspr.dart' as jaspr;
import 'package:flutter_hooks/flutter_hooks.dart';

class MyHookWidget extends HookWidget {
  final Stream<int> stream = Stream<int>.empty();
  final Future<int> future = Future<int>.value(0);

  @override
  Widget build(BuildContext context) {
    final a = stream.toBlocSignal(initialState: 0);
    final b = future.toBlocSignal(initialState: 0);
    final c = future.toAsyncBlocSignal();
    return Container();
  }
}

class MyComponent extends jaspr.StatelessComponent {
  final Future<int> future = Future<int>.value(0);

  @override
  jaspr.Component build(jaspr.BuildContext context) {
    final d = future.toBlocSignal(initialState: 0);
    return jaspr.Component();
  }
}
''';
      final diagnostics = await runLintRule(AvoidBridgingInBuild(), badCode);
      expect(diagnostics, hasLength(4));
    });

    test('does not flag user-defined bridging methods or dynamic receivers in '
        'build()', () async {
      const goodCode = '''
import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';

class CustomBridge {
  int toBlocSignal() => 1;
  int toAsyncBlocSignal() => 2;
  int toValueListenable() => 3;
}

class MyWidget extends StatelessWidget {
  final CustomBridge custom = CustomBridge();
  final dynamic dyn = CustomBridge();

  @override
  Widget build(BuildContext context) {
    final a = custom.toBlocSignal();
    final b = custom.toAsyncBlocSignal();
    final c = custom.toValueListenable();
    final d = dyn.toBlocSignal();
    return Container();
  }
}
''';
      final diagnostics = await runLintRule(AvoidBridgingInBuild(), goodCode);
      expect(diagnostics, isEmpty);
    });
  });

  group(
    '(Issue #505) AvoidBridgingInBuild adapters, .toStream(), and State mixins',
    () {
      test('flags StreamBlocSignal, FutureBlocSignal, SignalBlocSignal, and '
          'ReadonlySignal.toBlocSignal() inside Widget.build()', () async {
        const badCode = '''
import 'package:bloc_signals/bloc_signals.dart';
import 'package:flutter/widgets.dart';

class MyWidget extends StatelessWidget {
  final Stream<int> stream = Stream<int>.empty();
  final Future<int> future = Future<int>.value(0);
  final Signal<int> count = signal(0);

  @override
  Widget build(BuildContext context) {
    final a = StreamBlocSignal<int>(stream, initialState: 0);
    final b = FutureBlocSignal<int>(future, initialState: 0);
    final c = SignalBlocSignal<int>(count);
    final d = count.toBlocSignal();
    return Container();
  }
}
''';
        final diagnostics = await runLintRule(AvoidBridgingInBuild(), badCode);
        expect(diagnostics, hasLength(4));
      });

      test('flags bloc_signals_bloc constructors and .toClassicBloc() / '
          '.toClassicCubit() / .toStream() inside Widget.build()', () async {
        const badCode = '''
import 'package:bloc_signals/bloc_signals.dart';
import 'package:bloc_signals_bloc/bloc_signals_bloc.dart';
import 'package:flutter/widgets.dart';

class CounterBloc extends BlocSignal<int, int> {
  CounterBloc() : super(initialState: 0);
}

class CounterCubit extends CubitSignal<int> {
  CounterCubit() : super(initialState: 0);
}

class MyWidget extends StatelessWidget {
  final ClassicBloc<int, int> classicBloc = ClassicBloc<int, int>(0);
  final ClassicCubit<int> classicCubit = ClassicCubit<int>(0);
  final CounterBloc modernBloc = CounterBloc();
  final CounterCubit modernCubit = CounterCubit();

  @override
  Widget build(BuildContext context) {
    final a = ClassicBlocSignal<int, int>(classicBloc);
    final b = ClassicCubitSignal<ClassicCubit<int>, int>(classicCubit);
    final c = BlocSignalToClassicBloc<int, int>(modernBloc);
    final d = BlocSignalToClassicCubit<CounterCubit, int>(modernCubit);
    final e = modernBloc.toClassicBloc();
    final f = modernCubit.toClassicCubit();
    final g = modernCubit.toStream();
    return Container();
  }
}
''';
        final diagnostics = await runLintRule(AvoidBridgingInBuild(), badCode);
        expect(diagnostics, hasLength(7));
      });

      test('flags RiverpodBlocSignal and RiverpodNotifierBlocSignal '
          'constructors including .fromRef() inside Widget.build()', () async {
        const badCode = '''
import 'package:bloc_signals_riverpod/bloc_signals_riverpod.dart';
import 'package:flutter/widgets.dart';

class MyNotifier {}

class MyWidget extends StatelessWidget {
  final ProviderContainer container = ProviderContainer();
  final ProviderListenable<int> listenable = ProviderListenable<int>();
  final Ref ref = Ref();
  final MyNotifier notifier = MyNotifier();

  @override
  Widget build(BuildContext context) {
    final a = RiverpodBlocSignal<int>(container, listenable);
    final b = RiverpodBlocSignal<int>.fromRef(ref, listenable);
    final c = RiverpodNotifierBlocSignal<MyNotifier, int>(
      notifier,
      container,
      listenable,
    );
    final d = RiverpodNotifierBlocSignal<MyNotifier, int>.fromRef(
      notifier,
      ref,
      listenable,
    );
    return Container();
  }
}
''';
        final diagnostics = await runLintRule(AvoidBridgingInBuild(), badCode);
        expect(diagnostics, hasLength(4));
      });

      test('flags bridging inside State mixin build() methods', () async {
        const badCode = '''
import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';

mixin MyStateMixin<T extends StatefulWidget> on State<T> {
  final ValueNotifier<int> notifier = ValueNotifier<int>(0);

  @override
  Widget build(BuildContext context) {
    final a = notifier.toBlocSignal();
    final b = ListenableBlocSignal<int>.fromValueListenable(notifier);
    return Container();
  }
}
''';
        final diagnostics = await runLintRule(AvoidBridgingInBuild(), badCode);
        expect(diagnostics, hasLength(2));
      });

      test('ignores non-UI mixins and non-official toStream() / '
          'StreamBlocSignal', () async {
        const goodCode = '''
import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';

class StreamBlocSignal {
  StreamBlocSignal();
}

class CustomStreamSource {
  Stream<int> toStream() => const Stream.empty();
}

mixin PlainMixin {
  final ValueNotifier<int> notifier = ValueNotifier<int>(0);

  Widget build(BuildContext context) {
    final a = notifier.toBlocSignal();
    return Container();
  }
}

class MyWidget extends StatelessWidget {
  final CustomStreamSource source = CustomStreamSource();

  @override
  Widget build(BuildContext context) {
    final a = source.toStream();
    final b = StreamBlocSignal();
    return Container();
  }
}
''';
        final diagnostics = await runLintRule(AvoidBridgingInBuild(), goodCode);
        expect(diagnostics, isEmpty);
      });

      test('ignores non-UI on-constraint mixins and shadowed user-defined '
          'State mixins', () async {
        const goodCode = '''
import 'package:bloc_signals_flutter/bloc_signals_flutter.dart' hide State;

class State {}

mixin ObjectMixin on Object {
  final ValueNotifier<int> notifier = ValueNotifier<int>(0);

  Widget build(BuildContext context) {
    final a = notifier.toBlocSignal();
    return Container();
  }
}

mixin FakeStateMixin on State {
  final ValueNotifier<int> notifier = ValueNotifier<int>(0);

  Widget build(BuildContext context) {
    final a = notifier.toBlocSignal();
    return Container();
  }
}
''';
        final diagnostics = await runLintRule(AvoidBridgingInBuild(), goodCode);
        expect(diagnostics, isEmpty);
      });

      test('flags bridging inside unresolved State mixin without Flutter/Jaspr '
          'imports', () async {
        const badCode = '''
import 'package:bloc_signals/bloc_signals.dart';

mixin UnresolvedStateMixin on State {
  final Stream<int> stream = Stream<int>.empty();

  Object build(Object context) {
    final a = stream.toBlocSignal(initialState: 0);
    return a;
  }
}
''';
        final diagnostics = await runLintRule(AvoidBridgingInBuild(), badCode);
        expect(diagnostics, hasLength(1));
        expect(diagnostics.first.lexeme, equals('toBlocSignal'));
      });
    },
  );
}

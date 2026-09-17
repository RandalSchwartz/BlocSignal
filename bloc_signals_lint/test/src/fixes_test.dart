import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';
import 'package:analyzer/source/source_range.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_dart.dart';
import 'package:bloc_signals_lint/src/fixes/add_super_on_event_fix.dart';
import 'package:bloc_signals_lint/src/fixes/avoid_raw_signal_effects_in_bloc_fix.dart';
import 'package:bloc_signals_lint/src/fixes/prefer_read_in_callbacks_fix.dart';
import 'package:bloc_signals_lint/src/fixes/replace_context_watch_with_read_fix.dart';
import 'package:bloc_signals_lint/src/fixes/replace_positional_replay_constructor_fix.dart';
import 'package:bloc_signals_lint/src/fixes/require_cubit_signal_mixin_init_fix.dart';
import 'package:bloc_signals_lint/src/fixes/require_emit_in_helper_name_fix.dart';
import 'package:bloc_signals_lint/src/fixes/use_provider_value_fix.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'package:test/test.dart';

void main() {
  group('IDE Quick Fix Metadata & Construction Assertions', () {
    test('AddSuperOnEventFix instantiates cleanly', () {
      final fix = AddSuperOnEventFix();
      expect(fix, isA<AddSuperOnEventFix>());
    });

    test('PreferReadInCallbacksFix instantiates cleanly', () {
      final fix = PreferReadInCallbacksFix();
      expect(fix, isA<PreferReadInCallbacksFix>());
    });

    test('RequireCubitSignalMixinInitFix instantiates cleanly', () {
      final fix = RequireCubitSignalMixinInitFix();
      expect(fix, isA<RequireCubitSignalMixinInitFix>());
    });

    test('ReplaceContextWatchWithReadFix instantiates cleanly', () {
      final fix = ReplaceContextWatchWithReadFix();
      expect(fix, isA<ReplaceContextWatchWithReadFix>());
    });

    test('AvoidRawSignalEffectsInBlocFix instantiates cleanly', () {
      final fix = AvoidRawSignalEffectsInBlocFix();
      expect(fix, isA<AvoidRawSignalEffectsInBlocFix>());
    });

    test('UseProviderValueFix instantiates cleanly', () {
      final fix = UseProviderValueFix();
      expect(fix, isA<UseProviderValueFix>());
    });

    test('ReplacePositionalReplayConstructorFix instantiates cleanly', () {
      final fix = ReplacePositionalReplayConstructorFix();
      expect(fix, isA<ReplacePositionalReplayConstructorFix>());
    });

    test('RequireEmitInHelperNameFix instantiates cleanly', () {
      final fix = RequireEmitInHelperNameFix();
      expect(fix, isA<RequireEmitInHelperNameFix>());
    });
  });

  group('IDE Quick Fix Functional ChangeBuilder Verification', () {
    test('AddSuperOnEventFix inserts super.onEvent(event); in onEvent body',
        () {
      const sourceCode = '''
class MyBloc extends BlocSignal<MyEvent, int> {
  MyBloc() : super(initialState: 0);

  @override
  void onEvent(MyEvent event) {
    doSomething();
  }
}
''';
      final parseResult = parseString(content: sourceCode);
      final onEventMethod = parseResult.unit.declarations
          .whereType<ClassDeclaration>()
          .first
          .members
          .whereType<MethodDeclaration>()
          .firstWhere((m) => m.name.lexeme == 'onEvent');

      final fix = AddSuperOnEventFix();
      final transformed = _runFix(
        fix: fix,
        source: sourceCode,
        unit: parseResult.unit,
        targetRange: onEventMethod.sourceRange,
      );

      expect(transformed, contains('super.onEvent(event);'));
      expect(transformed, contains('doSomething();'));
    });

    test('PreferReadInCallbacksFix replaces watch with read', () {
      const sourceCode = '''
Widget build(BuildContext context) {
  return ElevatedButton(
    onPressed: () => context.watch<CounterBloc>().add(Increment()),
    child: Text('Add'),
  );
}
''';
      final parseResult = parseString(content: sourceCode);
      var watchOffset = sourceCode.indexOf('.watch<');
      if (watchOffset != -1) watchOffset += 1;

      final fix = PreferReadInCallbacksFix();
      final transformed = _runFix(
        fix: fix,
        source: sourceCode,
        unit: parseResult.unit,
        targetRange: SourceRange(watchOffset, 5),
      );

      expect(transformed, contains('context.read<CounterBloc>()'));
      expect(transformed, isNot(contains('context.watch<CounterBloc>()')));
    });

    test('RequireCubitSignalMixinInitFix handles block constructor body', () {
      const sourceCode = '''
class MyService with CubitSignalMixin<int> {
  MyService() {
    doInit();
  }
}
''';
      final parseResult = parseString(content: sourceCode);
      final constructor = parseResult.unit.declarations
          .whereType<ClassDeclaration>()
          .first
          .members
          .whereType<ConstructorDeclaration>()
          .first;

      final fix = RequireCubitSignalMixinInitFix();
      final transformed = _runFix(
        fix: fix,
        source: sourceCode,
        unit: parseResult.unit,
        targetRange: constructor.sourceRange,
      );

      expect(
        transformed,
        contains('initCubitSignal(initialState: TODO_INITIAL_STATE);'),
      );
      expect(transformed, contains('doInit();'));
    });

    test('RequireCubitSignalMixinInitFix handles empty constructor body', () {
      const sourceCode = '''
class MyService with CubitSignalMixin<int> {
  MyService();
}
''';
      final parseResult = parseString(content: sourceCode);
      final constructor = parseResult.unit.declarations
          .whereType<ClassDeclaration>()
          .first
          .members
          .whereType<ConstructorDeclaration>()
          .first;

      final fix = RequireCubitSignalMixinInitFix();
      final transformed = _runFix(
        fix: fix,
        source: sourceCode,
        unit: parseResult.unit,
        targetRange: constructor.sourceRange,
      );

      expect(
        transformed,
        contains(
          '{\n    initCubitSignal(initialState: TODO_INITIAL_STATE);\n  }',
        ),
      );
    });

    test('ReplaceContextWatchWithReadFix replaces watch with read', () {
      const sourceCode = '''
Widget build(BuildContext context) {
  final bloc = context.watch<CounterBloc>();
  return Container();
}
''';
      final parseResult = parseString(content: sourceCode);
      var watchOffset = sourceCode.indexOf('.watch<');
      if (watchOffset != -1) watchOffset += 1;

      final fix = ReplaceContextWatchWithReadFix();
      final transformed = _runFix(
        fix: fix,
        source: sourceCode,
        unit: parseResult.unit,
        targetRange: SourceRange(watchOffset, 5),
      );

      expect(transformed, contains('context.read<CounterBloc>()'));
      expect(transformed, isNot(contains('context.watch<CounterBloc>()')));
    });

    test('AvoidRawSignalEffectsInBlocFix replaces effect with createEffect',
        () {
      const sourceCode = '''
class CounterBloc extends BlocSignal<CounterEvent, int> {
  CounterBloc() : super(initialState: 0) {
    effect(() {
      print(stateValue);
    });
  }
}
''';
      final parseResult = parseString(content: sourceCode);
      final effectOffset = sourceCode.indexOf('effect(');

      final fix = AvoidRawSignalEffectsInBlocFix();
      final transformed = _runFix(
        fix: fix,
        source: sourceCode,
        unit: parseResult.unit,
        targetRange: SourceRange(effectOffset, 6),
      );

      expect(transformed, contains('createEffect(() {'));
      expect(transformed, isNot(contains(' effect(() {')));
    });

    test('UseProviderValueFix replaces create: with value:', () {
      const sourceCode = '''
Widget build(BuildContext context) {
  return BlocSignalProvider(
    create: (_) => existingBloc,
    child: Container(),
  );
}
''';
      final parseResult = parseString(content: sourceCode);
      final createOffset = sourceCode.indexOf('create:');

      final fix = UseProviderValueFix();
      final transformed = _runFix(
        fix: fix,
        source: sourceCode,
        unit: parseResult.unit,
        targetRange: SourceRange(createOffset, 6),
      );

      expect(transformed, contains('value: (_) => existingBloc'));
      expect(transformed, isNot(contains('create: (_) => existingBloc')));
    });

    test('ReplacePositionalReplayConstructorFix rewrites constructor', () {
      const sourceCode = '''
class CounterCubit extends ReplayCubit<int> {
  CounterCubit(int initial, {int? limit})
      : super.positional(initial, limit: limit);
}
''';
      final parseResult = parseString(content: sourceCode);
      final positionalOffset = sourceCode.indexOf('super.positional');

      final fix = ReplacePositionalReplayConstructorFix();
      final transformed = _runFix(
        fix: fix,
        source: sourceCode,
        unit: parseResult.unit,
        targetRange: SourceRange(positionalOffset, 16),
      );

      expect(
        transformed,
        contains('super(initialState: initial, limit: limit);'),
      );
      expect(transformed, isNot(contains('super.positional')));
    });

    test('RequireEmitInHelperNameFix renames helper declaration and call sites',
        () {
      const sourceCode = '''
class CounterCubit extends CubitSignal<int> {
  CounterCubit() : super(initialState: 0);

  void update() {
    _prune();
    this._prune();
  }

  void _prune() {
    emit(stateValue + 1);
  }
}
''';
      final parseResult = parseString(content: sourceCode);
      final helperOffset = sourceCode.indexOf('void _prune()');

      final fix = RequireEmitInHelperNameFix();
      final transformed = _runFix(
        fix: fix,
        source: sourceCode,
        unit: parseResult.unit,
        targetRange: SourceRange(helperOffset, 13),
      );

      expect(transformed, contains('void _pruneAndEmit()'));
      expect(transformed, contains('_pruneAndEmit();'));
      expect(transformed, contains('this._pruneAndEmit();'));
      expect(transformed, isNot(contains('void _prune()')));
    });
  });
}

String _runFix({
  required DartFix fix,
  required String source,
  required CompilationUnit unit,
  required SourceRange targetRange,
}) {
  final registry = _TestRegistry();
  final context = _TestContext(registry);
  final reporter = _TestChangeReporter();
  final error = _TestAnalysisError(targetRange);

  fix.run(_TestResolver(), reporter, context, error, []);

  // Dispatch AST nodes to registered callbacks.
  unit.accept(_DispatchVisitor(registry));

  // Apply edits to source code in reverse offset order.
  final edits = reporter.edits..sort((a, b) => b.offset.compareTo(a.offset));

  var result = source;
  for (final edit in edits) {
    result = result.substring(0, edit.offset) +
        edit.replacement +
        result.substring(edit.offset + edit.length);
  }
  return result;
}

class _TestEdit {
  _TestEdit(this.offset, this.length, this.replacement);
  final int offset;
  final int length;
  final String replacement;
}

class _TestChangeReporter implements ChangeReporter {
  final List<_TestEdit> edits = [];

  @override
  ChangeBuilder createChangeBuilder({
    required String message,
    required int priority,
  }) {
    return _TestChangeBuilder(edits);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestChangeBuilder implements ChangeBuilder {
  _TestChangeBuilder(this.edits);
  final List<_TestEdit> edits;

  @override
  void addDartFileEdit(
    void Function(DartFileEditBuilder builder) buildFileEdit, {
    ImportPrefixGenerator? importPrefixGenerator,
    String? customPath,
  }) {
    final builder = _TestDartFileEditBuilder(edits);
    buildFileEdit(builder);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestDartFileEditBuilder implements DartFileEditBuilder {
  _TestDartFileEditBuilder(this.edits);
  final List<_TestEdit> edits;

  @override
  void addSimpleInsertion(int offset, String text) {
    edits.add(_TestEdit(offset, 0, text));
  }

  @override
  void addSimpleReplacement(SourceRange range, String text) {
    edits.add(_TestEdit(range.offset, range.length, text));
  }

  @override
  void addDeletion(SourceRange range) {
    edits.add(_TestEdit(range.offset, range.length, ''));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// analyzer 14+ recommends Diagnostic over AnalysisError for AST errors.
// ignore: deprecated_member_use
class _TestAnalysisError implements AnalysisError {
  _TestAnalysisError(this.sourceRange);

  final SourceRange sourceRange;

  @override
  int get offset => sourceRange.offset;

  @override
  int get length => sourceRange.length;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestResolver implements CustomLintResolver {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestContext implements CustomLintContext {
  _TestContext(this.registry);

  @override
  final LintRuleNodeRegistry registry;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestRegistry implements LintRuleNodeRegistry {
  final List<void Function(MethodDeclaration)> methodDeclarations = [];
  final List<void Function(MethodInvocation)> methodInvocations = [];
  final List<void Function(ConstructorDeclaration)> constructorDeclarations =
      [];
  final List<void Function(NamedExpression)> namedExpressions = [];
  final List<void Function(SuperConstructorInvocation)>
      superConstructorInvocations = [];
  final List<void Function(ClassDeclaration)> classDeclarations = [];

  @override
  void addMethodDeclaration(void Function(MethodDeclaration node) cb) =>
      methodDeclarations.add(cb);

  @override
  void addMethodInvocation(void Function(MethodInvocation node) cb) =>
      methodInvocations.add(cb);

  @override
  void addConstructorDeclaration(
    void Function(ConstructorDeclaration node) cb,
  ) =>
      constructorDeclarations.add(cb);

  @override
  void addNamedExpression(void Function(NamedExpression node) cb) =>
      namedExpressions.add(cb);

  @override
  void addSuperConstructorInvocation(
    void Function(SuperConstructorInvocation node) cb,
  ) =>
      superConstructorInvocations.add(cb);

  @override
  void addClassDeclaration(void Function(ClassDeclaration node) cb) =>
      classDeclarations.add(cb);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DispatchVisitor extends RecursiveAstVisitor<void> {
  _DispatchVisitor(this.registry);
  final _TestRegistry registry;

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    for (final cb in registry.methodDeclarations) {
      cb(node);
    }
    super.visitMethodDeclaration(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    for (final cb in registry.methodInvocations) {
      cb(node);
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitConstructorDeclaration(ConstructorDeclaration node) {
    for (final cb in registry.constructorDeclarations) {
      cb(node);
    }
    super.visitConstructorDeclaration(node);
  }

  @override
  void visitNamedExpression(NamedExpression node) {
    for (final cb in registry.namedExpressions) {
      cb(node);
    }
    super.visitNamedExpression(node);
  }

  @override
  void visitSuperConstructorInvocation(SuperConstructorInvocation node) {
    for (final cb in registry.superConstructorInvocations) {
      cb(node);
    }
    super.visitSuperConstructorInvocation(node);
  }

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    for (final cb in registry.classDeclarations) {
      cb(node);
    }
    super.visitClassDeclaration(node);
  }
}

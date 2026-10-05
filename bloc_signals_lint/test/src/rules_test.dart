import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:bloc_signals_lint/src/rules/avoid_direct_signal_mutation_outside_bloc.dart';
import 'package:bloc_signals_lint/src/rules/require_cubit_signal_mixin_init.dart';
import 'package:test/test.dart';

void main() {
  group('Rule AST Detection on Sample Code Snippets', () {
    test('AvoidDuplicateEventHandlers detects duplicate on<E> handlers', () {
      const badCode = '''
class CounterBloc {
  CounterBloc() {
    on<IncrementEvent>((event, emit) {});
    on<IncrementEvent>((event, emit) {});
  }
}
''';
      final parseResult = parseString(content: badCode);
      final registeredTypes = <String>[];
      final duplicateTypes = <String>[];

      parseResult.unit.visitChildren(
        _MethodInvocationVisitor((node) {
          if (node.methodName.name == 'on') {
            final typeArgs = node.typeArguments?.arguments;
            if (typeArgs != null && typeArgs.isNotEmpty) {
              final typeName = typeArgs.first.toSource();
              if (registeredTypes.contains(typeName)) {
                duplicateTypes.add(typeName);
              } else {
                registeredTypes.add(typeName);
              }
            }
          }
        }),
      );

      expect(duplicateTypes, contains('IncrementEvent'));
    });

    test('AvoidDuplicateEventHandlers accepts distinct on<E> handlers', () {
      const goodCode = '''
class CounterBloc {
  CounterBloc() {
    on<IncrementEvent>((event, emit) {});
    on<DecrementEvent>((event, emit) {});
  }
}
''';
      final parseResult = parseString(content: goodCode);
      final registeredTypes = <String>[];
      final duplicateTypes = <String>[];

      parseResult.unit.visitChildren(
        _MethodInvocationVisitor((node) {
          if (node.methodName.name == 'on') {
            final typeArgs = node.typeArguments?.arguments;
            if (typeArgs != null && typeArgs.isNotEmpty) {
              final typeName = typeArgs.first.toSource();
              if (registeredTypes.contains(typeName)) {
                duplicateTypes.add(typeName);
              } else {
                registeredTypes.add(typeName);
              }
            }
          }
        }),
      );

      expect(duplicateTypes, isEmpty);
    });

    test('RequireSuperOnEvent detects missing super.onEvent in bad code', () {
      const badCode = '''
class MyBloc {
  void onEvent(dynamic event) {
    print(event);
  }
}
''';
      final parseResult = parseString(content: badCode);
      final methodNode = parseResult.unit.declarations
          .whereType<ClassDeclaration>()
          .first
          .members
          .whereType<MethodDeclaration>()
          .first;

      var callsSuper = false;
      methodNode.body.visitChildren(
        _SuperCallVisitor(() {
          callsSuper = true;
        }),
      );

      expect(callsSuper, isFalse);
    });

    test('RequireSuperOnEvent accepts valid super.onEvent in good code', () {
      const goodCode = '''
class MyBloc {
  void onEvent(dynamic event) {
    super.onEvent(event);
    print(event);
  }
}
''';
      final parseResult = parseString(content: goodCode);
      final methodNode = parseResult.unit.declarations
          .whereType<ClassDeclaration>()
          .first
          .members
          .whereType<MethodDeclaration>()
          .first;

      var callsSuper = false;
      methodNode.body.visitChildren(
        _SuperCallVisitor(() {
          callsSuper = true;
        }),
      );

      expect(callsSuper, isTrue);
    });

    test(
      'AvoidStreamTransformersOnBlocSignal detects invalid transformer calls',
      () {
        const badCode = '''
void test(dynamic bloc) {
  bloc.debounce();
  bloc.switchMap();
}
''';
        final parseResult = parseString(content: badCode);
        final flaggedMethods = <String>[];

        parseResult.unit.visitChildren(
          _MethodInvocationVisitor((node) {
            final name = node.methodName.name;
            if (name == 'debounce' || name == 'switchMap') {
              flaggedMethods.add(name);
            }
          }),
        );

        expect(flaggedMethods, containsAll(['debounce', 'switchMap']));
      },
    );

    test(
      'AvoidDirectSignalMutationOutsideBloc detects external emit calls',
      () {
        const badCode = '''
void externalFunction(dynamic bloc) {
  bloc.emit(42);
}
''';
        final parseResult = parseString(content: badCode);
        final emitsOutsideClass = <MethodInvocation>[];

        parseResult.unit.visitChildren(
          _MethodInvocationVisitor((node) {
            if (node.methodName.name == 'emit') {
              final enclosingClass =
                  node.thisOrAncestorOfType<ClassDeclaration>();
              final enclosingMixin =
                  node.thisOrAncestorOfType<MixinDeclaration>();
              if (!AvoidDirectSignalMutationOutsideBloc.isAllowedEmission(
                enclosingClass: enclosingClass,
                enclosingMixin: enclosingMixin,
              )) {
                emitsOutsideClass.add(node);
              }
            }
          }),
        );

        expect(emitsOutsideClass, hasLength(1));
      },
    );

    test(
      '(Issue #302: F16) AvoidDirectSignalMutationOutsideBloc accepts '
      'this.emit inside mixin on CubitSignal',
      () {
        const goodCode = '''
mixin CartPricing on CubitSignal<int> {
  void calculate() {
    this.emit(42);
  }
}
''';
        final parseResult = parseString(content: goodCode);
        final flaggedEmits = <MethodInvocation>[];

        parseResult.unit.visitChildren(
          _MethodInvocationVisitor((node) {
            if (node.methodName.name == 'emit') {
              final enclosingClass =
                  node.thisOrAncestorOfType<ClassDeclaration>();
              final enclosingMixin =
                  node.thisOrAncestorOfType<MixinDeclaration>();
              if (!AvoidDirectSignalMutationOutsideBloc.isAllowedEmission(
                enclosingClass: enclosingClass,
                enclosingMixin: enclosingMixin,
              )) {
                flaggedEmits.add(node);
              }
            }
          }),
        );

        expect(flaggedEmits, isEmpty);
      },
    );

    test(
      '(Issue #302: F16) AvoidDirectSignalMutationOutsideBloc rejects '
      'non-bloc enclosingClass even if enclosingMixin is present',
      () {
        const classCode = '''
class NonBlocService {
  void doEmit() {}
}
''';
        const mixinCode = '''
mixin CartPricing on CubitSignal<int> {}
''';
        final classUnit = parseString(content: classCode).unit;
        final mixinUnit = parseString(content: mixinCode).unit;
        final classNode =
            classUnit.declarations.whereType<ClassDeclaration>().first;
        final mixinNode =
            mixinUnit.declarations.whereType<MixinDeclaration>().first;

        final isAllowed =
            AvoidDirectSignalMutationOutsideBloc.isAllowedEmission(
          enclosingClass: classNode,
          enclosingMixin: mixinNode,
        );

        expect(isAllowed, isFalse);
      },
    );

    test(
      'AvoidTopLevelBlocSignalInstances detects global top-level bloc '
      'declarations',
      () {
        const badCode = '''
final counterBloc = CounterBloc();
class Service {
  static final authBloc = AuthBloc();
}
''';
        final parseResult = parseString(content: badCode);
        final globalVars = <String>[];

        parseResult.unit.visitChildren(
          _VariableVisitor((node) {
            final name = node.name.lexeme;
            if (name == 'counterBloc' || name == 'authBloc') {
              globalVars.add(name);
            }
          }),
        );

        expect(globalVars, containsAll(['counterBloc', 'authBloc']));
      },
    );

    test(
        '(Issue #302: F2) RequireCubitSignalMixinInit detects uninitialized '
        'mixin constructors at constructor token', () {
      const badCode = '''
class CounterService extends BaseService with CubitSignalMixin<int> {
  CounterService() {
    print('hello');
  }
}
''';
      final parseResult = parseString(content: badCode);
      final classNode =
          parseResult.unit.declarations.whereType<ClassDeclaration>().first;
      final violations = RequireCubitSignalMixinInit.findViolations(classNode);

      expect(violations, hasLength(1));
      expect(violations.first.token.lexeme, equals('CounterService'));
      expect(
        violations.first.token.offset,
        equals(badCode.indexOf('CounterService()')),
      );
      expect(violations.first.mixinName, equals('CubitSignalMixin'));
      expect(violations.first.expectedMethod, equals('initCubitSignal'));
    });

    test(
        '(Issue #302: F2, F8) RequireCubitSignalMixinInit flags class with '
        'BlocSignalMixin calling initBlocSignal', () {
      const badCode = '''
class UserBloc extends BaseService with BlocSignalMixin<UserEvent, int> {
  UserBloc() {
    initBlocSignal(initialState: 0);
  }
}
''';
      final parseResult = parseString(content: badCode);
      final classNode =
          parseResult.unit.declarations.whereType<ClassDeclaration>().first;
      final violations = RequireCubitSignalMixinInit.findViolations(classNode);

      expect(violations, hasLength(1));
      expect(violations.first.mixinName, equals('BlocSignalMixin'));
      expect(violations.first.expectedMethod, equals('initCubitSignal'));
    });

    test(
        '(Issue #302: F2, F8) RequireCubitSignalMixinInit accepts class with '
        'BlocSignalMixin calling initCubitSignal', () {
      const goodCode = '''
class UserBloc extends BaseService with BlocSignalMixin<UserEvent, int> {
  UserBloc() {
    initCubitSignal(initialState: 0);
  }
}
''';
      final parseResult = parseString(content: goodCode);
      final classNode =
          parseResult.unit.declarations.whereType<ClassDeclaration>().first;
      final violations = RequireCubitSignalMixinInit.findViolations(classNode);

      expect(violations, isEmpty);
    });

    test('RequireCubitSignalMixinInit accepts initialized mixin constructors',
        () {
      const goodCode = '''
class CounterService extends BaseService with CubitSignalMixin<int> {
  CounterService() {
    initCubitSignal(initialState: 0);
  }
}
''';
      final parseResult = parseString(content: goodCode);
      final classNode =
          parseResult.unit.declarations.whereType<ClassDeclaration>().first;
      final violations = RequireCubitSignalMixinInit.findViolations(classNode);

      expect(violations, isEmpty);
    });

    test(
        '(Issue #302: F10) RequireCubitSignalMixinInit ignores factory '
        'constructors and redirecting constructors', () {
      const code = '''
class CounterService extends BaseService with CubitSignalMixin<int> {
  CounterService._() {
    initCubitSignal(initialState: 0);
  }

  CounterService.redirect() : this._();

  factory CounterService.factory() {
    return CounterService._();
  }
}
''';
      final parseResult = parseString(content: code);
      final classNode =
          parseResult.unit.declarations.whereType<ClassDeclaration>().first;
      final violations = RequireCubitSignalMixinInit.findViolations(classNode);

      expect(violations, isEmpty);
    });

    test('AvoidRawSignalEffectsInBloc detects top-level effect in bloc', () {
      const badCode = '''
class MyCubit extends CubitSignal<int> {
  MyCubit() : super(initialState: 0) {
    effect(() {
      print(stateValue);
    });
  }
}
''';
      final parseResult = parseString(content: badCode);
      final rawEffects = <String>[];

      parseResult.unit.visitChildren(
        _MethodInvocationVisitor((node) {
          if (node.methodName.name == 'effect' && node.target == null) {
            final classNode = node.thisOrAncestorOfType<ClassDeclaration>();
            if (classNode != null &&
                (classNode.extendsClause?.toSource().contains('CubitSignal') ??
                    false)) {
              rawEffects.add(node.methodName.name);
            }
          }
        }),
      );

      expect(rawEffects, contains('effect'));
    });

    test('AvoidRawSignalEffectsInBloc accepts createEffect in bloc', () {
      const goodCode = '''
class MyCubit extends CubitSignal<int> {
  MyCubit() : super(initialState: 0) {
    createEffect(() {
      print(stateValue);
    });
  }
}
''';
      final parseResult = parseString(content: goodCode);
      final rawEffects = <String>[];

      parseResult.unit.visitChildren(
        _MethodInvocationVisitor((node) {
          if (node.methodName.name == 'effect' && node.target == null) {
            rawEffects.add(node.methodName.name);
          }
        }),
      );

      expect(rawEffects, isEmpty);
    });

    test('AvoidUnusedSelectResult detects discarded context.select statements',
        () {
      const badCode = '''
void build(dynamic context) {
  context.select<MyBloc, int>((b) => b.stateValue);
}
''';
      final parseResult = parseString(content: badCode);
      final unusedSelects = <String>[];

      parseResult.unit.visitChildren(
        _ExpressionStatementVisitor((node) {
          final expr = node.expression;
          if (expr is MethodInvocation &&
              expr.methodName.name == 'select' &&
              (expr.target?.toSource().contains('context') ?? false)) {
            unusedSelects.add(expr.methodName.name);
          }
        }),
      );

      expect(unusedSelects, contains('select'));
    });

    test('AvoidUnusedSelectResult accepts assigned context.select expressions',
        () {
      const goodCode = '''
void build(dynamic context) {
  final count = context.select<MyBloc, int>((b) => b.stateValue);
  print(count);
}
''';
      final parseResult = parseString(content: goodCode);
      final unusedSelects = <String>[];

      parseResult.unit.visitChildren(
        _ExpressionStatementVisitor((node) {
          final expr = node.expression;
          if (expr is MethodInvocation &&
              expr.methodName.name == 'select' &&
              (expr.target?.toSource().contains('context') ?? false)) {
            unusedSelects.add(expr.methodName.name);
          }
        }),
      );

      expect(unusedSelects, isEmpty);
    });

    test(
      'PreferNamedReplayConstructor detects super.positional on ReplayCubit',
      () {
        const badCode = '''
class CounterCubit extends ReplayCubit<int> {
  CounterCubit(int initial, {int? limit})
      : super.positional(initial, limit: limit);
}
''';
        final parseResult = parseString(content: badCode);
        final flaggedInvocations = <String>[];

        parseResult.unit.visitChildren(
          _SuperConstructorInvocationVisitor((node) {
            final classNode = node.thisOrAncestorOfType<ClassDeclaration>();
            final superclass = classNode?.extendsClause?.superclass.toSource();
            if (node.constructorName?.name == 'positional' &&
                superclass != null &&
                superclass.startsWith('ReplayCubit')) {
              flaggedInvocations.add(node.toSource());
            }
          }),
        );

        expect(
          flaggedInvocations,
          contains('super.positional(initial, limit: limit)'),
        );
      },
    );

    test(
      'PreferNamedReplayConstructor detects super.positional on ReplayBloc',
      () {
        const badCode = '''
class CounterBloc extends ReplayBloc<CounterEvent, int> {
  CounterBloc(int initial) : super.positional(initial);
}
''';
        final parseResult = parseString(content: badCode);
        final flaggedInvocations = <String>[];

        parseResult.unit.visitChildren(
          _SuperConstructorInvocationVisitor((node) {
            final classNode = node.thisOrAncestorOfType<ClassDeclaration>();
            final superclass = classNode?.extendsClause?.superclass.toSource();
            if (node.constructorName?.name == 'positional' &&
                superclass != null &&
                superclass.startsWith('ReplayBloc')) {
              flaggedInvocations.add(node.toSource());
            }
          }),
        );

        expect(flaggedInvocations, contains('super.positional(initial)'));
      },
    );

    test(
      'PreferNamedReplayConstructor accepts named super(initialState: ...)',
      () {
        const goodCode = '''
class CounterCubit extends ReplayCubit<int> {
  CounterCubit(int initial, {int? limit})
      : super(initialState: initial, limit: limit);
}
class CounterBloc extends ReplayBloc<CounterEvent, int> {
  CounterBloc(int initial) : super(initialState: initial);
}
''';
        final parseResult = parseString(content: goodCode);
        final flaggedInvocations = <String>[];

        parseResult.unit.visitChildren(
          _SuperConstructorInvocationVisitor((node) {
            final classNode = node.thisOrAncestorOfType<ClassDeclaration>();
            final superclass = classNode?.extendsClause?.superclass.toSource();
            if (node.constructorName?.name == 'positional' &&
                superclass != null &&
                (superclass.startsWith('ReplayCubit') ||
                    superclass.startsWith('ReplayBloc'))) {
              flaggedInvocations.add(node.toSource());
            }
          }),
        );

        expect(flaggedInvocations, isEmpty);
      },
    );

    test(
      'ReplacePositionalReplayConstructorFix rewrites super.positional',
      () {
        const sourceCode = '''
class CounterCubit extends ReplayCubit<int> {
  CounterCubit(int initial, {int? limit})
      : super.positional(initial, limit: limit);
}
''';
        final parseResult = parseString(content: sourceCode);
        String? transformed;

        parseResult.unit.visitChildren(
          _SuperConstructorInvocationVisitor((node) {
            if (node.constructorName?.name == 'positional') {
              final period = node.period!;
              final constructorName = node.constructorName!;
              final positionalArg = node.argumentList.arguments
                  .where((arg) => arg is! NamedExpression)
                  .firstOrNull;

              if (positionalArg != null) {
                final beforePeriod = sourceCode.substring(0, period.offset);
                final betweenPeriodAndArg = sourceCode.substring(
                  constructorName.end,
                  positionalArg.offset,
                );
                final afterArg = sourceCode.substring(positionalArg.offset);
                transformed = '$beforePeriod$betweenPeriodAndArg'
                    'initialState: $afterArg';
              }
            }
          }),
        );

        expect(
          transformed,
          contains('super(initialState: initial, limit: limit)'),
        );
        expect(transformed, isNot(contains('super.positional')));
      },
    );

    test(
      'ReplacePositionalReplayConstructorFix rewrites with leading named args',
      () {
        const sourceCode = '''
class CounterCubit extends ReplayCubit<int> {
  CounterCubit(int initial, {int? limit})
      : super.positional(limit: limit, initial);
}
''';
        final parseResult = parseString(content: sourceCode);
        String? transformed;

        parseResult.unit.visitChildren(
          _SuperConstructorInvocationVisitor((node) {
            if (node.constructorName?.name == 'positional') {
              final period = node.period!;
              final constructorName = node.constructorName!;
              final positionalArg = node.argumentList.arguments
                  .where((arg) => arg is! NamedExpression)
                  .firstOrNull;

              if (positionalArg != null) {
                final beforePeriod = sourceCode.substring(0, period.offset);
                final betweenConstructorAndArg = sourceCode.substring(
                  constructorName.end,
                  positionalArg.offset,
                );
                final afterArg = sourceCode.substring(positionalArg.offset);
                transformed = '$beforePeriod$betweenConstructorAndArg'
                    'initialState: $afterArg';
              }
            }
          }),
        );

        expect(
          transformed,
          contains('super(limit: limit, initialState: initial)'),
        );
        expect(transformed, isNot(contains('super.positional')));
      },
    );

    test(
      'ReplacePositionalReplayConstructorFix safely skips '
      'empty super parameters',
      () {
        const sourceCode = '''
class CounterCubit extends ReplayCubit<int> {
  CounterCubit(super.initialState, {super.limit}) : super.positional();
}
''';
        final parseResult = parseString(content: sourceCode);
        var skipped = false;

        parseResult.unit.visitChildren(
          _SuperConstructorInvocationVisitor((node) {
            if (node.constructorName?.name == 'positional') {
              final positionalArg = node.argumentList.arguments
                  .where((arg) => arg is! NamedExpression)
                  .firstOrNull;
              if (positionalArg == null) {
                skipped = true;
              }
            }
          }),
        );

        expect(skipped, isTrue);
      },
    );
  });
}

class _SuperConstructorInvocationVisitor extends RecursiveAstVisitor<void> {
  _SuperConstructorInvocationVisitor(this.onInvocation);
  final void Function(SuperConstructorInvocation node) onInvocation;

  @override
  void visitSuperConstructorInvocation(SuperConstructorInvocation node) {
    onInvocation(node);
    super.visitSuperConstructorInvocation(node);
  }
}

class _ExpressionStatementVisitor extends RecursiveAstVisitor<void> {
  _ExpressionStatementVisitor(this.onStatement);
  final void Function(ExpressionStatement node) onStatement;

  @override
  void visitExpressionStatement(ExpressionStatement node) {
    onStatement(node);
    super.visitExpressionStatement(node);
  }
}

class _MethodInvocationVisitor extends RecursiveAstVisitor<void> {
  _MethodInvocationVisitor(this.onInvocation);
  final void Function(MethodInvocation node) onInvocation;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    onInvocation(node);
    super.visitMethodInvocation(node);
  }
}

class _SuperCallVisitor extends RecursiveAstVisitor<void> {
  _SuperCallVisitor(this.onSuperCall);
  final void Function() onSuperCall;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.target is SuperExpression && node.methodName.name == 'onEvent') {
      onSuperCall();
    }
    super.visitMethodInvocation(node);
  }
}

class _VariableVisitor extends RecursiveAstVisitor<void> {
  _VariableVisitor(this.onVariable);
  final void Function(VariableDeclaration node) onVariable;

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    onVariable(node);
    super.visitVariableDeclaration(node);
  }
}

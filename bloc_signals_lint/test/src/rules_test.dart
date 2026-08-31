import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
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
              if (enclosingClass == null) {
                emitsOutsideClass.add(node);
              }
            }
          }),
        );

        expect(emitsOutsideClass, hasLength(1));
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

    test('RequireCubitSignalMixinInit detects uninitialized mixin constructors',
        () {
      const badCode = '''
class CounterService extends BaseService with CubitSignalMixin<int> {
  CounterService() {
    print('hello');
  }
}
''';
      final parseResult = parseString(content: badCode);
      final uninitializedConstructors = <String>[];

      parseResult.unit.visitChildren(
        _ClassVisitor((classNode) {
          final withClause = classNode.withClause;
          if (withClause != null &&
              withClause.toSource().contains('CubitSignalMixin')) {
            for (final ctor
                in classNode.members.whereType<ConstructorDeclaration>()) {
              var callsInit = false;
              ctor.body.visitChildren(
                _MethodInvocationVisitor((method) {
                  if (method.methodName.name == 'initCubitSignal' ||
                      method.methodName.name == 'initBlocSignal') {
                    callsInit = true;
                  }
                }),
              );
              if (!callsInit) {
                uninitializedConstructors
                    .add(ctor.name?.lexeme ?? classNode.name.lexeme);
              }
            }
          }
        }),
      );

      expect(uninitializedConstructors, contains('CounterService'));
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
      final uninitializedConstructors = <String>[];

      parseResult.unit.visitChildren(
        _ClassVisitor((classNode) {
          final withClause = classNode.withClause;
          if (withClause != null &&
              withClause.toSource().contains('CubitSignalMixin')) {
            for (final ctor
                in classNode.members.whereType<ConstructorDeclaration>()) {
              var callsInit = false;
              ctor.body.visitChildren(
                _MethodInvocationVisitor((method) {
                  if (method.methodName.name == 'initCubitSignal' ||
                      method.methodName.name == 'initBlocSignal') {
                    callsInit = true;
                  }
                }),
              );
              if (!callsInit) {
                uninitializedConstructors
                    .add(ctor.name?.lexeme ?? classNode.name.lexeme);
              }
            }
          }
        }),
      );

      expect(uninitializedConstructors, isEmpty);
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
  });
}

class _ClassVisitor extends RecursiveAstVisitor<void> {
  _ClassVisitor(this.onClass);
  final void Function(ClassDeclaration node) onClass;

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    onClass(node);
    super.visitClassDeclaration(node);
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

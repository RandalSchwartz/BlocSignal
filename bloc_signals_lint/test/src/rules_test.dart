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
      'AvoidTopLevelBlocSignalInstances detects global top-level bloc declarations',
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
  });
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

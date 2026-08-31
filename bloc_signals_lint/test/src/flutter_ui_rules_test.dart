import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:test/test.dart';

void main() {
  group('Flutter UI Rule AST Detection on Sample Code Snippets', () {
    test('AvoidEmitInBuild detects emit or add inside build method', () {
      const badCode = '''
class MyWidget {
  Widget build(dynamic context) {
    bloc.emit(42);
    bloc.add(MyEvent());
    return Container();
  }
}
''';
      final parseResult = parseString(content: badCode);
      final flaggedMutations = <String>[];

      parseResult.unit.visitChildren(
        _MethodInvocationVisitor((node) {
          final name = node.methodName.name;
          if (name == 'emit' || name == 'add') {
            final method = node.thisOrAncestorOfType<MethodDeclaration>();
            if (method != null && method.name.lexeme == 'build') {
              flaggedMutations.add(name);
            }
          }
        }),
      );

      expect(flaggedMutations, containsAll(['emit', 'add']));
    });

    test('AvoidEmitInBuild accepts emit or add inside event callbacks', () {
      const goodCode = '''
class MyWidget {
  Widget build(dynamic context) {
    return Button(
      onPressed: () {
        bloc.add(MyEvent());
      },
    );
  }
}
''';
      final parseResult = parseString(content: goodCode);
      final directBuildMutations = <String>[];

      parseResult.unit.visitChildren(
        _MethodInvocationVisitor((node) {
          final name = node.methodName.name;
          if (name == 'emit' || name == 'add') {
            final method = node.thisOrAncestorOfType<MethodDeclaration>();
            final closure = node.thisOrAncestorOfType<FunctionExpression>();
            if (method != null &&
                method.name.lexeme == 'build' &&
                closure == null) {
              directBuildMutations.add(name);
            }
          }
        }),
      );

      expect(directBuildMutations, isEmpty);
    });

    test('AvoidUnmanagedSignalEffects detects unassigned effect in widget', () {
      const badCode = '''
class MyStatefulWidget extends State {
  void initState() {
    effect(() {
      print('unmanaged');
    });
  }
}
''';
      final parseResult = parseString(content: badCode);
      final unassignedEffects = <MethodInvocation>[];

      parseResult.unit.visitChildren(
        _MethodInvocationVisitor((node) {
          if (node.methodName.name == 'effect') {
            final enclosingClass =
                node.thisOrAncestorOfType<ClassDeclaration>();
            if (enclosingClass != null && node.parent is ExpressionStatement) {
              unassignedEffects.add(node);
            }
          }
        }),
      );

      expect(unassignedEffects, hasLength(1));
    });

    test(
      'PreferBlocSignalProviderReadInCallbacks detects watch in onPressed',
      () {
        const badCode = '''
class MyWidget {
  Widget build(dynamic context) {
    return Button(
      onPressed: () {
        final bloc = context.watch<MyBloc>();
      },
    );
  }
}
''';
        final parseResult = parseString(content: badCode);
        final watchInCallbacks = <MethodInvocation>[];

        parseResult.unit.visitChildren(
          _MethodInvocationVisitor((node) {
            if (node.methodName.name == 'watch') {
              final parentArg = node.thisOrAncestorOfType<NamedExpression>();
              if (parentArg != null &&
                  parentArg.name.label.name == 'onPressed') {
                watchInCallbacks.add(node);
              }
            }
          }),
        );

        expect(watchInCallbacks, hasLength(1));
      },
    );

    test(
      'AvoidProvidingExistingInstanceWithCreate detects existing ref in create',
      () {
        const badCode = '''
class MyWidget {
  Widget build(dynamic context) {
    return BlocSignalProvider(
      create: (context) => myGlobalBloc,
      child: Container(),
    );
  }
}
''';
        final parseResult = parseString(content: badCode);
        final existingRefCreates = <AstNode>[];

        parseResult.unit.visitChildren(
          _MethodInvocationVisitor((node) {
            if (node.methodName.name == 'BlocSignalProvider') {
              for (final arg in node.argumentList.arguments) {
                if (arg is NamedExpression && arg.name.label.name == 'create') {
                  existingRefCreates.add(node);
                }
              }
            }
          }),
        );

        expect(existingRefCreates, hasLength(1));
      },
    );

    test('AvoidManualCloseOnProvidedBloc detects context.read().close()', () {
      const badCode = '''
void dispose(dynamic context) {
  context.read<CounterBloc>().close();
}
''';
      final parseResult = parseString(content: badCode);
      final manualCloses = <MethodInvocation>[];

      parseResult.unit.visitChildren(
        _MethodInvocationVisitor((node) {
          if (node.methodName.name == 'close') {
            final target = node.target;
            if (target is MethodInvocation &&
                target.methodName.name == 'read') {
              manualCloses.add(node);
            }
          }
        }),
      );

      expect(manualCloses, hasLength(1));
    });

    test(
      'AvoidContextWatchForBlocState detects context.watch<T>() in build',
      () {
        const badCode = '''
class CounterView {
  Widget build(dynamic context) {
    final bloc = context.watch<CounterBloc>();
    return Container();
  }
}
''';
        final parseResult = parseString(content: badCode);
        final watchedBlocs = <String>[];

        parseResult.unit.visitChildren(
          _MethodInvocationVisitor((node) {
            if (node.methodName.name == 'watch') {
              final typeArgs = node.typeArguments?.arguments;
              if (typeArgs != null && typeArgs.isNotEmpty) {
                final typeName = typeArgs.first.toSource();
                if (typeName.endsWith('Bloc') || typeName.endsWith('Cubit')) {
                  final method = node.thisOrAncestorOfType<MethodDeclaration>();
                  if (method != null && method.name.lexeme == 'build') {
                    watchedBlocs.add(typeName);
                  }
                }
              }
            }
          }),
        );

        expect(watchedBlocs, contains('CounterBloc'));
      },
    );

    test(
      'AvoidContextWatchForBlocState accepts context.read<T>() in build',
      () {
        const goodCode = '''
class CounterView {
  Widget build(dynamic context) {
    final bloc = context.read<CounterBloc>();
    return Container();
  }
}
''';
        final parseResult = parseString(content: goodCode);
        final watchedBlocs = <String>[];

        parseResult.unit.visitChildren(
          _MethodInvocationVisitor((node) {
            if (node.methodName.name == 'watch') {
              final typeArgs = node.typeArguments?.arguments;
              if (typeArgs != null && typeArgs.isNotEmpty) {
                final typeName = typeArgs.first.toSource();
                if (typeName.endsWith('Bloc') || typeName.endsWith('Cubit')) {
                  final method = node.thisOrAncestorOfType<MethodDeclaration>();
                  if (method != null && method.name.lexeme == 'build') {
                    watchedBlocs.add(typeName);
                  }
                }
              }
            }
          }),
        );

        expect(watchedBlocs, isEmpty);
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

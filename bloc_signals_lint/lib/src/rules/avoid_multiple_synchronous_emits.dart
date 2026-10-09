// Ignore deprecated_member_use due to custom_lint_builder parameter signature.
// ignore_for_file: deprecated_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// A lint rule that flags multiple synchronous `emit()` calls occurring along
/// the same linear control-flow path without an intervening `await`.
///
/// In BlocSignal, state updates propagate synchronously in frame 0. Multiple
/// synchronous emissions leak transient intermediate states.
class AvoidMultipleSynchronousEmits extends DartLintRule {
  /// Creates an [AvoidMultipleSynchronousEmits] lint rule.
  const AvoidMultipleSynchronousEmits() : super(code: _code);

  static const _code = LintCode(
    name: 'avoid_multiple_synchronous_emits',
    problemMessage:
        'Multiple synchronous `emit()` calls detected along the same '
        'execution path.',
    correctionMessage:
        'Consolidate into a single atomic state transition to prevent '
        'intermediate state leakage.',
  );

  static const _blocSignalBaseChecker = TypeChecker.fromName(
    'BlocSignalBase',
    packageName: 'bloc_signals',
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry
      ..addClassDeclaration((node) {
        final classElement = node.declaredFragment?.element;
        final extendsClause = node.extendsClause?.superclass.toSource();
        final withClause = node.withClause?.toSource();

        final isBlocContainer = (classElement != null &&
                _blocSignalBaseChecker.isSuperOf(classElement)) ||
            (extendsClause != null &&
                (extendsClause.contains('BlocSignal') ||
                    extendsClause.contains('CubitSignal') ||
                    extendsClause.contains('ReplayCubit') ||
                    extendsClause.contains('ReplayBloc'))) ||
            (withClause != null &&
                (withClause.contains('CubitSignalMixin') ||
                    withClause.contains('BlocSignalMixin')));

        if (!isBlocContainer) return;

        _reportViolations(findViolations(node), reporter);
      })
      ..addMixinDeclaration((node) {
        if (!_isBlocContainerMixin(node)) return;
        _reportViolations(findMixinViolations(node), reporter);
      });
  }

  void _reportViolations(List<AstNode> violations, ErrorReporter reporter) {
    for (final violation in violations) {
      if (violation is MethodInvocation) {
        reporter.atNode(violation.methodName, code);
      }
    }
  }

  static bool _isBlocContainerMixin(MixinDeclaration node) {
    final onClause = node.onClause;
    if (onClause == null) return false;
    for (final constraint in onClause.superclassConstraints) {
      final type = constraint.type;
      if (type != null && _blocSignalBaseChecker.isAssignableFromType(type)) {
        return true;
      }
      final source = constraint.toSource();
      if (source.contains('BlocSignal') ||
          source.contains('CubitSignal') ||
          source.contains('ReplayCubit') ||
          source.contains('ReplayBloc')) {
        return true;
      }
    }
    return false;
  }

  /// Identifies all AST nodes in [classNode] representing a secondary or
  /// subsequent synchronous state emission along the same linear path.
  static List<AstNode> findViolations(ClassDeclaration classNode) =>
      _findMemberViolations(classNode.members);

  /// Identifies all AST nodes in [mixinNode] representing a secondary or
  /// subsequent synchronous state emission along the same linear path.
  static List<AstNode> findMixinViolations(MixinDeclaration mixinNode) =>
      _findMemberViolations(mixinNode.members);

  static List<AstNode> _findMemberViolations(NodeList<ClassMember> members) {
    final emittingMethods = _findSynchronousEmittingMethods(members);
    final violations = <AstNode>[];
    final reported = <AstNode>{};

    void recordViolation(AstNode node) {
      if (reported.add(node)) {
        violations.add(node);
      }
    }

    for (final member in members) {
      if (member is MethodDeclaration) {
        _analyzeFunctionBody(
          member.body,
          emittingMethods,
          recordViolation,
        );
      } else if (member is ConstructorDeclaration) {
        _analyzeFunctionBody(
          member.body,
          emittingMethods,
          recordViolation,
        );
      }
    }

    // Also analyze any nested closures independently
    final visitor = _ClosureVisitor((closure) {
      _analyzeFunctionBody(
        closure.body,
        emittingMethods,
        recordViolation,
      );
    });
    for (final member in members) {
      member.accept(visitor);
    }

    return violations;
  }

  static Set<String> _findSynchronousEmittingMethods(
    NodeList<ClassMember> members,
  ) {
    final emittingMethods = <String>{};

    var changed = true;
    while (changed) {
      changed = false;
      for (final method in members.whereType<MethodDeclaration>()) {
        final name = method.name.lexeme;
        if (!emittingMethods.contains(name)) {
          if (_doesBodyEmitSynchronously(method.body, emittingMethods)) {
            emittingMethods.add(name);
            changed = true;
          }
        }
      }
    }

    return emittingMethods;
  }

  static bool _doesBodyEmitSynchronously(
    FunctionBody body,
    Set<String> emittingMethods,
  ) {
    if (body is ExpressionFunctionBody) {
      return _expressionEmitsSynchronously(body.expression, emittingMethods);
    }
    if (body is! BlockFunctionBody) return false;

    for (final stmt in body.block.statements) {
      var awaited = false;
      var emitted = false;
      stmt.accept(
        _LinearAstVisitor(
          onAwait: () => awaited = true,
          onEmit: (node) {
            if (!awaited && _isEmitOrHelper(node, emittingMethods)) {
              emitted = true;
            }
          },
          stopOnAwait: true,
        ),
      );
      if (emitted) return true;
      if (awaited) return false;
    }
    return false;
  }

  static bool _expressionEmitsSynchronously(
    Expression expr,
    Set<String> emittingMethods,
  ) {
    var awaited = false;
    var emits = false;
    expr.accept(
      _LinearAstVisitor(
        onAwait: () => awaited = true,
        onEmit: (node) {
          if (!awaited && _isEmitOrHelper(node, emittingMethods)) {
            emits = true;
          }
        },
        stopOnAwait: true,
      ),
    );
    return emits;
  }

  static bool _isEmitOrHelper(
    MethodInvocation node,
    Set<String> emittingMethods,
  ) {
    final name = node.methodName.name;
    final target = node.realTarget;
    final isThisOrImplicit = target == null || target is ThisExpression;
    if (!isThisOrImplicit) return false;

    if (name == 'emit') return true;
    if (emittingMethods.contains(name)) return true;
    return false;
  }

  static void _analyzeFunctionBody(
    FunctionBody body,
    Set<String> emittingMethods,
    void Function(AstNode node) onViolation,
  ) {
    if (body is BlockFunctionBody) {
      _analyzeStatements(
        body.block.statements,
        [_PathState()],
        emittingMethods,
        onViolation,
      );
    } else if (body is ExpressionFunctionBody) {
      _evaluateExpression(
        body.expression,
        [_PathState()],
        emittingMethods,
        onViolation,
      );
    }
  }

  static List<_PathState> _analyzeStatements(
    List<Statement> statements,
    List<_PathState> incomingPaths,
    Set<String> emittingMethods,
    void Function(AstNode node) onViolation,
  ) {
    var currentPaths = incomingPaths;

    for (final stmt in statements) {
      final active = currentPaths.where((p) => !p.isTerminated).toList();
      if (active.isEmpty) break;

      final terminated = currentPaths.where((p) => p.isTerminated).toList();
      final afterStmt = _analyzeStatement(
        stmt,
        active,
        emittingMethods,
        onViolation,
      );
      currentPaths = [...terminated, ...afterStmt];
    }

    return currentPaths;
  }

  static List<_PathState> _analyzeStatement(
    Statement stmt,
    List<_PathState> incomingPaths,
    Set<String> emittingMethods,
    void Function(AstNode node) onViolation,
  ) {
    if (stmt is Block) {
      return _analyzeStatements(
        stmt.statements,
        incomingPaths,
        emittingMethods,
        onViolation,
      );
    }

    if (stmt is IfStatement) {
      // Evaluate condition expression
      _evaluateExpression(
        stmt.expression,
        incomingPaths,
        emittingMethods,
        onViolation,
      );

      final active = incomingPaths.where((p) => !p.isTerminated).toList();
      if (active.isEmpty) return incomingPaths;

      final thenInput = active.map((p) => p.clone()).toList();
      final afterThen = _analyzeStatement(
        stmt.thenStatement,
        thenInput,
        emittingMethods,
        onViolation,
      );

      final elseStatement = stmt.elseStatement;
      List<_PathState> afterElse;
      if (elseStatement != null) {
        final elseInput = active.map((p) => p.clone()).toList();
        afterElse = _analyzeStatement(
          elseStatement,
          elseInput,
          emittingMethods,
          onViolation,
        );
      } else {
        // Condition was false, so execution continues along current state
        afterElse = active.map((p) => p.clone()).toList();
      }

      return [...afterThen, ...afterElse];
    }

    if (stmt is TryStatement) {
      final active = incomingPaths.where((p) => !p.isTerminated).toList();
      final afterTry = _analyzeStatement(
        stmt.body,
        active.map((p) => p.clone()).toList(),
        emittingMethods,
        onViolation,
      );

      final catchPaths = <_PathState>[];
      for (final catchClause in stmt.catchClauses) {
        final afterCatch = _analyzeStatement(
          catchClause.body,
          active.map((p) => p.clone()).toList(),
          emittingMethods,
          onViolation,
        );
        catchPaths.addAll(afterCatch);
      }

      var merged = [...afterTry, ...catchPaths];
      final finallyBlock = stmt.finallyBlock;
      if (finallyBlock != null) {
        merged = _analyzeStatement(
          finallyBlock,
          merged,
          emittingMethods,
          onViolation,
        );
      }
      return merged;
    }

    if (stmt is SwitchStatement) {
      _evaluateExpression(
        stmt.expression,
        incomingPaths,
        emittingMethods,
        onViolation,
      );

      final active = incomingPaths.where((p) => !p.isTerminated).toList();
      if (active.isEmpty) return incomingPaths;

      final labeledMembers = <String, SwitchMember>{};
      for (final member in stmt.members) {
        for (final label in member.labels) {
          labeledMembers[label.label.name] = member;
        }
      }

      final casePaths = <_PathState>[];
      var hasDefault = false;

      for (final member in stmt.members) {
        if (member is SwitchDefault) {
          hasDefault = true;
        }
        final memberInput = active.map((p) => p.clone()).toList();
        var afterMember = _analyzeStatements(
          member.statements,
          memberInput,
          emittingMethods,
          onViolation,
        );

        var remainingHops = stmt.members.length;
        while (remainingHops > 0 &&
            afterMember.any(
              (p) =>
                  p.isContinued && labeledMembers.containsKey(p.continueLabel),
            )) {
          remainingHops--;
          final nextAfterMember = <_PathState>[];
          for (final path in afterMember) {
            final label = path.continueLabel;
            if (path.isContinued &&
                label != null &&
                labeledMembers.containsKey(label)) {
              final targetMember = labeledMembers[label]!;
              path
                ..isContinued = false
                ..isTerminated = false
                ..continueLabel = null;
              nextAfterMember.addAll(
                _analyzeStatements(
                  targetMember.statements,
                  [path],
                  emittingMethods,
                  onViolation,
                ),
              );
            } else {
              nextAfterMember.add(path);
            }
          }
          afterMember = nextAfterMember;
        }

        for (final path in afterMember) {
          if (path.isBroken) {
            path
              ..isBroken = false
              ..isTerminated = false;
          }
        }
        casePaths.addAll(afterMember);
      }

      if (!hasDefault) {
        casePaths.addAll(active.map((p) => p.clone()));
      }

      return casePaths;
    }

    if (stmt is BreakStatement) {
      for (final path in incomingPaths) {
        path
          ..isTerminated = true
          ..isBroken = true;
      }
      return incomingPaths;
    }

    if (stmt is ContinueStatement) {
      final labelName = stmt.label?.name;
      for (final path in incomingPaths) {
        path
          ..isTerminated = true
          ..isContinued = true
          ..continueLabel = labelName;
      }
      return incomingPaths;
    }

    if (stmt is ForStatement || stmt is WhileStatement || stmt is DoStatement) {
      final Statement body;
      if (stmt is ForStatement) {
        body = stmt.body;
      } else if (stmt is WhileStatement) {
        body = stmt.body;
      } else {
        body = (stmt as DoStatement).body;
      }

      // Simulate iteration 1
      final afterIter1 = _analyzeStatement(
        body,
        incomingPaths.map((p) => p.clone()).toList(),
        emittingMethods,
        onViolation,
      );

      for (final path in afterIter1) {
        if (path.isContinued) {
          path
            ..isContinued = false
            ..isTerminated = false
            ..continueLabel = null;
        }
      }

      // Simulate iteration 2 to catch loops repeating synchronous emits.
      // Only paths that neither terminated (for example return) nor broke
      // (break) will execute a second iteration.
      final activeIter1 =
          afterIter1.where((p) => !p.isTerminated && !p.isBroken).toList();
      if (activeIter1.isNotEmpty) {
        _analyzeStatement(
          body,
          activeIter1.map((p) => p.clone()).toList(),
          emittingMethods,
          onViolation,
        );
      }

      for (final path in afterIter1) {
        if (path.isBroken) {
          path
            ..isBroken = false
            ..isTerminated = false;
        }
      }

      return afterIter1;
    }

    if (stmt is ReturnStatement) {
      final expr = stmt.expression;
      if (expr != null) {
        _evaluateExpression(expr, incomingPaths, emittingMethods, onViolation);
      }
      for (final path in incomingPaths) {
        path.isTerminated = true;
      }
      return incomingPaths;
    }

    if (stmt is ExpressionStatement) {
      final expr = stmt.expression;
      if (expr is ThrowExpression || expr is RethrowExpression) {
        _evaluateExpression(
          expr,
          incomingPaths,
          emittingMethods,
          onViolation,
        );
        for (final path in incomingPaths) {
          path.isTerminated = true;
        }
        return incomingPaths;
      }
      _evaluateExpression(
        expr,
        incomingPaths,
        emittingMethods,
        onViolation,
      );
      return incomingPaths;
    }

    if (stmt is VariableDeclarationStatement) {
      for (final variable in stmt.variables.variables) {
        final init = variable.initializer;
        if (init != null) {
          _evaluateExpression(
            init,
            incomingPaths,
            emittingMethods,
            onViolation,
          );
        }
      }
      return incomingPaths;
    }

    return incomingPaths;
  }

  static void _evaluateExpression(
    Expression expr,
    List<_PathState> paths,
    Set<String> emittingMethods,
    void Function(AstNode node) onViolation,
  ) {
    expr.accept(
      _LinearAstVisitor(
        onAwait: () {
          for (final path in paths.where((p) => !p.isTerminated)) {
            path.hasEmitted = false;
          }
        },
        onEmit: (node) {
          if (_isEmitOrHelper(node, emittingMethods)) {
            for (final path in paths.where((p) => !p.isTerminated)) {
              if (path.hasEmitted) {
                onViolation(node);
              } else {
                path.hasEmitted = true;
              }
            }
          }
        },
        onConditional: (condExpr) {
          _evaluateExpression(
            condExpr.condition,
            paths,
            emittingMethods,
            onViolation,
          );
          final active = paths.where((p) => !p.isTerminated).toList();
          if (active.isNotEmpty) {
            final thenInput = active.map((p) => p.clone()).toList();
            _evaluateExpression(
              condExpr.thenExpression,
              thenInput,
              emittingMethods,
              onViolation,
            );
            final elseInput = active.map((p) => p.clone()).toList();
            _evaluateExpression(
              condExpr.elseExpression,
              elseInput,
              emittingMethods,
              onViolation,
            );
            paths
              ..clear()
              ..addAll([...thenInput, ...elseInput]);
          }
        },
      ),
    );
  }
}

class _PathState {
  _PathState({
    this.hasEmitted = false,
    this.isTerminated = false,
    this.isBroken = false,
    this.isContinued = false,
    this.continueLabel,
  });

  bool hasEmitted;
  bool isTerminated;
  bool isBroken;
  bool isContinued;
  String? continueLabel;

  _PathState clone() => _PathState(
        hasEmitted: hasEmitted,
        isTerminated: isTerminated,
        isBroken: isBroken,
        isContinued: isContinued,
        continueLabel: continueLabel,
      );
}

class _ClosureVisitor extends RecursiveAstVisitor<void> {
  _ClosureVisitor(this.onClosure);

  final void Function(FunctionExpression closure) onClosure;

  @override
  void visitFunctionExpression(FunctionExpression node) {
    onClosure(node);
    super.visitFunctionExpression(node);
  }
}

class _LinearAstVisitor extends RecursiveAstVisitor<void> {
  _LinearAstVisitor({
    required this.onAwait,
    required this.onEmit,
    this.onConditional,
    this.stopOnAwait = false,
  });

  final void Function() onAwait;
  final void Function(MethodInvocation node) onEmit;
  final void Function(ConditionalExpression node)? onConditional;
  final bool stopOnAwait;

  @override
  void visitFunctionExpression(FunctionExpression node) {
    // Never descend into nested closures during linear synchronous path
    // traversal.
    return;
  }

  @override
  void visitConditionalExpression(ConditionalExpression node) {
    if (onConditional != null) {
      onConditional!(node);
    } else {
      super.visitConditionalExpression(node);
    }
  }

  @override
  void visitAwaitExpression(AwaitExpression node) {
    node.expression.accept(this);
    onAwait();
    if (stopOnAwait) return;
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    node.target?.accept(this);
    node.argumentList.accept(this);
    onEmit(node);
  }
}

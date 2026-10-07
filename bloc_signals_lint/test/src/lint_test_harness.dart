// Ignore deprecated_member_use due to custom_lint_builder / analyzer signatures
// across analyzer 6.8.0 through 14.x.
// ignore_for_file: deprecated_member_use

import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';
import 'package:analyzer/error/listener.dart';
import 'package:analyzer/source/source_range.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'package:test/test.dart';

/// A diagnostic recorded when executing a [DartLintRule] via [runLintRule].
class ReportedLint {
  /// Creates a [ReportedLint] record.
  const ReportedLint({
    required this.code,
    required this.lexeme,
    required this.offset,
    required this.length,
    this.arguments,
  });

  /// The diagnostic [ErrorCode] reported by the rule.
  final ErrorCode code;

  /// The source text or token lexeme of the reported node/token.
  final String lexeme;

  /// The character offset of the reported node/token.
  final int offset;

  /// The character length of the reported node/token.
  final int length;

  /// Optional formatting arguments passed to the reporter.
  final List<Object>? arguments;
}

const String _defaultPreamble =
    "import 'package:bloc_signals/bloc_signals.dart'; "
    "import 'package:flutter/widgets.dart'; ";

Directory? _tempWorkspaceDir;
AnalysisContextCollection? _contextCollection;
var _fileCounter = 0;
var _tearDownRegistered = false;

/// Disposes of the temporary workspace directory and resets the shared
/// [AnalysisContextCollection] created by [runLintRule].
void disposeLintTestHarness() {
  final dir = _tempWorkspaceDir;
  if (dir != null && dir.existsSync()) {
    dir.deleteSync(recursive: true);
  }
  _tempWorkspaceDir = null;
  _contextCollection = null;
  _tearDownRegistered = false;
}

String _joinPath(List<String> segments) =>
    segments.join(Platform.pathSeparator);

AnalysisContextCollection _getOrCreateCollection() {
  if (_contextCollection != null) return _contextCollection!;

  final tempDir = _tempWorkspaceDir ??=
      Directory.systemTemp.createTempSync('bloc_signals_lint_test_');
  if (!_tearDownRegistered) {
    _tearDownRegistered = true;
    try {
      tearDownAll(disposeLintTestHarness);
    } on Object catch (_) {
      // Called inside a running test body; test suites should call
      // tearDownAll(disposeLintTestHarness) in main().
    }
  }
  final rootPath = tempDir.resolveSymbolicLinksSync();

  final dartToolDir = Directory(_joinPath([rootPath, '.dart_tool']))
    ..createSync(recursive: true);
  File(_joinPath([dartToolDir.path, 'package_config.json']))
      .writeAsStringSync('''
{
  "configVersion": 2,
  "packages": [
    {
      "name": "bloc_signals",
      "rootUri": "../bloc_signals",
      "packageUri": "lib/",
      "languageVersion": "3.5"
    },
    {
      "name": "bloc_signals_replay",
      "rootUri": "../bloc_signals_replay",
      "packageUri": "lib/",
      "languageVersion": "3.5"
    },
    {
      "name": "flutter",
      "rootUri": "../flutter",
      "packageUri": "lib/",
      "languageVersion": "3.5"
    },
    {
      "name": "test_app",
      "rootUri": "..",
      "packageUri": "lib/",
      "languageVersion": "3.5"
    }
  ]
}
''');

  final blocSignalsLibDir =
      Directory(_joinPath([rootPath, 'bloc_signals', 'lib']))
        ..createSync(recursive: true);
  File(_joinPath([blocSignalsLibDir.path, 'bloc_signals.dart']))
      .writeAsStringSync(
    '''
class BlocSignalBase<State> {
  BlocSignalBase({State? initialState});
  State get stateValue => throw UnimplementedError();
  State get value => throw UnimplementedError();
  void emit(State state) {}
  void emitTelemetry(String name, {Map<String, Object?>? metadata}) {}
  void createEffect(void Function() cb) {}
  void onError(Object error, StackTrace stackTrace) {}
  Future<void> close() async {}
}

class CubitSignal<State> extends BlocSignalBase<State> {
  CubitSignal({super.initialState});
}

class BlocSignal<Event, State> extends BlocSignalBase<State> {
  BlocSignal({super.initialState});
  void on<E extends Event>(
    void Function(E event, void Function(State) emit) handler, {
    Function? transformer,
  }) {}
  void add(Event event) {}
  void onEvent(Event event) {}
}

mixin CubitSignalMixin<State> {
  State get stateValue => throw UnimplementedError();
  State get value => throw UnimplementedError();
  void initCubitSignal({required State initialState}) {}
  void emit(State state) {}
  void emitTelemetry(String name, {Map<String, Object?>? metadata}) {}
}

mixin BlocSignalMixin<Event, State> {
  State get stateValue => throw UnimplementedError();
  State get value => throw UnimplementedError();
  void initCubitSignal({required State initialState}) {}
  void initBlocSignal({required State initialState}) {}
  void emit(State state) {}
  void add(Event event) {}
}

class ReplayCubit<State> extends CubitSignal<State> {
  ReplayCubit({super.initialState, int? limit});
  ReplayCubit.positional(State initialState, {int? limit});
}

class ReplayBloc<Event, State> extends BlocSignal<Event, State> {
  ReplayBloc({super.initialState, int? limit});
  ReplayBloc.positional(State initialState, {int? limit});
}

void Function() effect(void Function() cb) => () {};
T signal<T>(T initial) => initial;
''',
  );

  final replayLibDir =
      Directory(_joinPath([rootPath, 'bloc_signals_replay', 'lib']))
        ..createSync(recursive: true);
  File(_joinPath([replayLibDir.path, 'bloc_signals_replay.dart']))
      .writeAsStringSync(
    '''
export 'package:bloc_signals/bloc_signals.dart' show ReplayCubit, ReplayBloc;
''',
  );

  final flutterLibDir = Directory(_joinPath([rootPath, 'flutter', 'lib']))
    ..createSync(recursive: true);
  File(_joinPath([flutterLibDir.path, 'widgets.dart'])).writeAsStringSync('''
class BuildContext {
  T read<T>() => throw UnimplementedError();
  T watch<T>() => throw UnimplementedError();
  R select<B, R>(R Function(B bloc) selector) => throw UnimplementedError();
}

class Widget {}
class StatelessWidget extends Widget {}
class StatefulWidget extends Widget {}
class State<T> {}
class Container extends Widget {}
class Text extends Widget {
  Text(String s);
}
class Button extends Widget {
  Button({void Function()? onPressed, Widget? child});
}
class ElevatedButton extends Widget {
  ElevatedButton({void Function()? onPressed, Widget? child});
}
class BlocSignalProvider<T> extends Widget {
  BlocSignalProvider({
    T Function(BuildContext context)? create,
    Widget? child,
  });
  BlocSignalProvider.value({
    T? value,
    Widget? child,
  });
}
''');

  Directory(_joinPath([rootPath, 'lib'])).createSync(recursive: true);

  String? sdkPath;
  final execDir = File(Platform.resolvedExecutable).parent;
  final defaultSdkCandidate = execDir.parent.path;
  if (!File(
    _joinPath([
      defaultSdkCandidate,
      'lib',
      '_internal',
      'allowed_experiments.json',
    ]),
  ).existsSync()) {
    // Under `flutter test`, Platform.resolvedExecutable is `flutter_tester`
    // inside `.../artifacts/engine/darwin-x64/flutter_tester` while the Dart
    // SDK is at `.../dart-sdk`.
    var current = execDir;
    for (var i = 0; i < 6; i++) {
      final candidate = _joinPath([current.path, 'dart-sdk']);
      if (File(
        _joinPath([candidate, 'lib', '_internal', 'allowed_experiments.json']),
      ).existsSync()) {
        sdkPath = candidate;
        break;
      }
      current = current.parent;
    }
  }

  return _contextCollection = AnalysisContextCollection(
    includedPaths: [rootPath],
    sdkPath: sdkPath,
  );
}

/// Runs [rule] against the semantically resolved AST of [sourceCode] and
/// returns all diagnostics reported via [ErrorReporter].
Future<List<ReportedLint>> runLintRule(
  DartLintRule rule,
  String sourceCode,
) async {
  final collection = _getOrCreateCollection();
  final rootPath = _tempWorkspaceDir!.resolveSymbolicLinksSync();
  final testFilePath =
      _joinPath([rootPath, 'lib', 'target_${++_fileCounter}.dart']);
  final testFile = File(testFilePath);

  final hasImports = sourceCode.contains("import 'package:bloc_signals/");
  final prefix = hasImports ? '' : _defaultPreamble;
  final fullSource = '$prefix$sourceCode';

  try {
    testFile.writeAsStringSync(fullSource);

    final analysisContext = collection.contextFor(testFilePath)
      ..changeFile(testFilePath);
    await analysisContext.applyPendingFileChanges();

    final session = analysisContext.currentSession;
    final result = await session.getResolvedUnit(testFilePath);
    if (result is! ResolvedUnitResult) {
      throw StateError('Failed to resolve unit for $testFilePath: $result');
    }

    final registry = _TestRegistry();
    final context = _TestContext(registry);
    final reporter = _MockErrorReporter(prefixLength: prefix.length);
    final resolver = _TestResolver(testFilePath);

    rule.run(resolver, reporter, context);
    result.unit.accept(_DispatchVisitor(registry));

    return reporter.reportedLints;
  } finally {
    if (testFile.existsSync()) {
      testFile.deleteSync();
    }
  }
}

class _MockErrorReporter implements ErrorReporter {
  _MockErrorReporter({required this.prefixLength});

  final int prefixLength;
  final List<ReportedLint> reportedLints = [];

  /// Uses `noSuchMethod` intentionally to bridge incompatible return-type
  /// signatures across `analyzer: ">=6.8.0 <15.0.0"` (`SCAR-LINT-01`): in
  /// `analyzer 6.8.0`, `ErrorReporter.atNode` and `atToken` return `void`,
  /// whereas in `analyzer 8.0.0+`, `DiagnosticReporter.atNode` and `atToken`
  /// return `Diagnostic` (`AnalysisError`). Returning `_TestAnalysisError`
  /// via `dynamic noSuchMethod` satisfies both signatures without compile-time
  /// override conflicts on downgrade or upgrade.
  @override
  dynamic noSuchMethod(Invocation invocation) {
    final name = invocation.memberName;
    if (name == #atNode) {
      final node = invocation.positionalArguments[0] as AstNode;
      final code = invocation.positionalArguments[1] as ErrorCode;
      final args = invocation.namedArguments[#arguments] as List<Object>?;
      final adjustedOffset = node.offset - prefixLength;
      reportedLints.add(
        ReportedLint(
          code: code,
          lexeme: node.toSource(),
          offset: adjustedOffset,
          length: node.length,
          arguments: args,
        ),
      );
      return _TestAnalysisError(SourceRange(adjustedOffset, node.length));
    }
    if (name == #atToken) {
      final token = invocation.positionalArguments[0] as Token;
      final code = invocation.positionalArguments[1] as ErrorCode;
      final args = invocation.namedArguments[#arguments] as List<Object>?;
      final adjustedOffset = token.offset - prefixLength;
      reportedLints.add(
        ReportedLint(
          code: code,
          lexeme: token.lexeme,
          offset: adjustedOffset,
          length: token.length,
          arguments: args,
        ),
      );
      return _TestAnalysisError(SourceRange(adjustedOffset, token.length));
    }
    return super.noSuchMethod(invocation);
  }
}

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
  _TestResolver(this.path);

  @override
  final String path;

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
  final List<void Function(ClassDeclaration)> _classDeclarations = [];
  final List<void Function(MixinDeclaration)> _mixinDeclarations = [];
  final List<void Function(MethodDeclaration)> _methodDeclarations = [];
  final List<void Function(MethodInvocation)> _methodInvocations = [];
  final List<void Function(InstanceCreationExpression)>
      _instanceCreationExpressions = [];
  final List<void Function(TopLevelVariableDeclaration)>
      _topLevelVariableDeclarations = [];
  final List<void Function(FieldDeclaration)> _fieldDeclarations = [];
  final List<void Function(ExpressionStatement)> _expressionStatements = [];
  final List<void Function(SuperConstructorInvocation)>
      _superConstructorInvocations = [];

  List<void Function(ClassDeclaration)> get classDeclarations =>
      List<void Function(ClassDeclaration)>.unmodifiable(_classDeclarations);

  List<void Function(MixinDeclaration)> get mixinDeclarations =>
      List<void Function(MixinDeclaration)>.unmodifiable(_mixinDeclarations);

  List<void Function(MethodDeclaration)> get methodDeclarations =>
      List<void Function(MethodDeclaration)>.unmodifiable(_methodDeclarations);

  List<void Function(MethodInvocation)> get methodInvocations =>
      List<void Function(MethodInvocation)>.unmodifiable(_methodInvocations);

  List<void Function(InstanceCreationExpression)>
      get instanceCreationExpressions =>
          List<void Function(InstanceCreationExpression)>.unmodifiable(
            _instanceCreationExpressions,
          );

  List<void Function(TopLevelVariableDeclaration)>
      get topLevelVariableDeclarations =>
          List<void Function(TopLevelVariableDeclaration)>.unmodifiable(
            _topLevelVariableDeclarations,
          );

  List<void Function(FieldDeclaration)> get fieldDeclarations =>
      List<void Function(FieldDeclaration)>.unmodifiable(_fieldDeclarations);

  List<void Function(ExpressionStatement)> get expressionStatements =>
      List<void Function(ExpressionStatement)>.unmodifiable(
        _expressionStatements,
      );

  List<void Function(SuperConstructorInvocation)>
      get superConstructorInvocations =>
          List<void Function(SuperConstructorInvocation)>.unmodifiable(
            _superConstructorInvocations,
          );

  @override
  void addClassDeclaration(void Function(ClassDeclaration node) cb) =>
      _classDeclarations.add(cb);

  @override
  void addMixinDeclaration(void Function(MixinDeclaration node) cb) =>
      _mixinDeclarations.add(cb);

  @override
  void addMethodDeclaration(void Function(MethodDeclaration node) cb) =>
      _methodDeclarations.add(cb);

  @override
  void addMethodInvocation(void Function(MethodInvocation node) cb) =>
      _methodInvocations.add(cb);

  @override
  void addInstanceCreationExpression(
    void Function(InstanceCreationExpression node) cb,
  ) =>
      _instanceCreationExpressions.add(cb);

  @override
  void addTopLevelVariableDeclaration(
    void Function(TopLevelVariableDeclaration node) cb,
  ) =>
      _topLevelVariableDeclarations.add(cb);

  @override
  void addFieldDeclaration(void Function(FieldDeclaration node) cb) =>
      _fieldDeclarations.add(cb);

  @override
  void addExpressionStatement(void Function(ExpressionStatement node) cb) =>
      _expressionStatements.add(cb);

  @override
  void addSuperConstructorInvocation(
    void Function(SuperConstructorInvocation node) cb,
  ) =>
      _superConstructorInvocations.add(cb);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DispatchVisitor extends RecursiveAstVisitor<void> {
  _DispatchVisitor(this.registry);
  final _TestRegistry registry;

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    for (final cb in List.of(registry.classDeclarations)) {
      cb(node);
    }
    super.visitClassDeclaration(node);
  }

  @override
  void visitMixinDeclaration(MixinDeclaration node) {
    // Work around custom_lint_core 0.8.x bug where `TypeChecker.isSuperOf`
    // unconditionally evaluates `element.supertype!` on `InterfaceElement`,
    // which throws a null-check exception on `MixinElement` (since mixins use
    // `superclassConstraints` and their `supertype` is always `null`).
    // Clearing `declaredFragment` on the AST node allows rules inspecting
    // mixins to safely evaluate resolved `onClause.superclassConstraints`.
    try {
      (node as dynamic).declaredFragment = null;
    } on Object catch (_) {}

    for (final cb in List.of(registry.mixinDeclarations)) {
      cb(node);
    }
    super.visitMixinDeclaration(node);
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    for (final cb in List.of(registry.methodDeclarations)) {
      cb(node);
    }
    super.visitMethodDeclaration(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    for (final cb in List.of(registry.methodInvocations)) {
      cb(node);
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    for (final cb in List.of(registry.instanceCreationExpressions)) {
      cb(node);
    }
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitTopLevelVariableDeclaration(TopLevelVariableDeclaration node) {
    for (final cb in List.of(registry.topLevelVariableDeclarations)) {
      cb(node);
    }
    super.visitTopLevelVariableDeclaration(node);
  }

  @override
  void visitFieldDeclaration(FieldDeclaration node) {
    for (final cb in List.of(registry.fieldDeclarations)) {
      cb(node);
    }
    super.visitFieldDeclaration(node);
  }

  @override
  void visitExpressionStatement(ExpressionStatement node) {
    for (final cb in List.of(registry.expressionStatements)) {
      cb(node);
    }
    super.visitExpressionStatement(node);
  }

  @override
  void visitSuperConstructorInvocation(SuperConstructorInvocation node) {
    for (final cb in List.of(registry.superConstructorInvocations)) {
      cb(node);
    }
    super.visitSuperConstructorInvocation(node);
  }
}

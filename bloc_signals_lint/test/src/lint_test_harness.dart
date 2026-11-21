import 'dart:io';

import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type_provider.dart';
import 'package:analyzer/dart/element/type_system.dart';
import 'package:analyzer/diagnostic/diagnostic.dart';
import 'package:analyzer/error/error.dart';
import 'package:analyzer/error/listener.dart';
import 'package:analyzer/source/source_range.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:test/test.dart';

/// A diagnostic recorded when executing an [AnalysisRule] via [runLintRule].
class ReportedLint {
  /// Creates a [ReportedLint] record.
  const new({
    required this.code,
    required this.lexeme,
    required this.offset,
    required this.length,
    this.arguments,
  });

  /// The diagnostic [DiagnosticCode] reported by the rule.
  final DiagnosticCode code;

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

  final tempDir = _tempWorkspaceDir ??= Directory.systemTemp.createTempSync(
    'bloc_signals_lint_test_',
  );
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
      "name": "bloc_signals_hydrate",
      "rootUri": "../bloc_signals_hydrate",
      "packageUri": "lib/",
      "languageVersion": "3.5"
    },
    {
      "name": "bloc_signals_jaspr",
      "rootUri": "../bloc_signals_jaspr",
      "packageUri": "lib/",
      "languageVersion": "3.5"
    },
    {
      "name": "jaspr",
      "rootUri": "../jaspr",
      "packageUri": "lib/",
      "languageVersion": "3.5"
    },
    {
      "name": "flutter_hooks",
      "rootUri": "../flutter_hooks",
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

  final blocSignalsLibDir = Directory(
    _joinPath([rootPath, 'bloc_signals', 'lib']),
  )..createSync(recursive: true);
  File(_joinPath([blocSignalsLibDir.path, 'bloc_signals.dart']))
      .writeAsStringSync('''
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

mixin BlocSignalMixin<Event, State> on BlocSignalBase<State> {
  void initCubitSignal({required State initialState}) {}
  void on<E extends Event>(
    void Function(E event, void Function(State) emit) handler, {
    Function? transformer,
  }) {}
  void add(Event event) {}
  void onEvent(Event event) {}
}

abstract class BlocSignalObserver {
  const BlocSignalObserver();
  void onEvent(BlocSignalBase<Object?> bloc, Object? event) {}
}

export 'package:bloc_signals_replay/bloc_signals_replay.dart'
    show ReplayBloc, ReplayCubit;

void Function() effect(void Function() cb) => () {};
T Function() computed<T>(T Function() cb) => cb;
T signal<T>(T initial) => initial;
''');

  final hydrateLibDir = Directory(
    _joinPath([rootPath, 'bloc_signals_hydrate', 'lib']),
  )..createSync(recursive: true);
  File(_joinPath([hydrateLibDir.path, 'bloc_signals_hydrate.dart']))
      .writeAsStringSync('''
import 'package:bloc_signals/bloc_signals.dart';

mixin HydratedMixin<State> on BlocSignalBase<State> {}

class HydratedCubitSignal<State> extends CubitSignal<State>
    with HydratedMixin<State> {
  HydratedCubitSignal({super.initialState});
}

class HydratedBlocSignal<Event, State> extends BlocSignal<Event, State>
    with HydratedMixin<State> {
  HydratedBlocSignal({super.initialState});
}
''');

  final jasprLibDir = Directory(_joinPath([rootPath, 'jaspr', 'lib']))
    ..createSync(recursive: true);
  File(_joinPath([jasprLibDir.path, 'jaspr.dart'])).writeAsStringSync('''
class Component {}

class BuildContext {
  T read<T>() => throw UnimplementedError();
  T watch<T>() => throw UnimplementedError();
  R select<B, R>(R Function(B bloc) selector) => throw UnimplementedError();
}

abstract class StatelessComponent extends Component {
  Component build(BuildContext context);
}

abstract class StatefulComponent extends Component {
  State<StatefulComponent> createState();
}

abstract class State<T extends StatefulComponent> {
  void initState() {}
  void dispose() {}
  Component build(BuildContext context);
}
''');

  final blocJasprLibDir = Directory(
    _joinPath([rootPath, 'bloc_signals_jaspr', 'lib']),
  )..createSync(recursive: true);
  File(_joinPath([blocJasprLibDir.path, 'bloc_signals_jaspr.dart']))
      .writeAsStringSync('''
export 'package:bloc_signals/bloc_signals.dart';
export 'package:jaspr/jaspr.dart';
''');

  final flutterHooksLibDir = Directory(
    _joinPath([rootPath, 'flutter_hooks', 'lib']),
  )..createSync(recursive: true);
  File(_joinPath([flutterHooksLibDir.path, 'flutter_hooks.dart']))
      .writeAsStringSync('''
import 'package:flutter/widgets.dart';

abstract class HookWidget extends StatelessWidget {
  Widget build(BuildContext context);
}

void useEffect(void Function()? Function() effect, [List<Object?>? keys]) {}
''');

  final replayLibDir = Directory(
    _joinPath([rootPath, 'bloc_signals_replay', 'lib']),
  )..createSync(recursive: true);
  File(_joinPath([replayLibDir.path, 'bloc_signals_replay.dart']))
      .writeAsStringSync('''
import 'package:bloc_signals/bloc_signals.dart';

class ReplayCubit<State> extends CubitSignal<State> {
  ReplayCubit({super.initialState, int? limit});
  ReplayCubit.positional(State initialState, {int? limit});
}

class ReplayBloc<Event, State> extends BlocSignal<Event, State> {
  ReplayBloc({super.initialState, int? limit});
  ReplayBloc.positional(State initialState, {int? limit});
}
''');

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
  static T of<T>(BuildContext context, {bool listen = false}) =>
      throw UnimplementedError();
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
/// returns all diagnostics reported via [DiagnosticReporter].
Future<List<ReportedLint>> runLintRule(
  AnalysisRule rule,
  String sourceCode,
) async {
  final collection = _getOrCreateCollection();
  final rootPath = _tempWorkspaceDir!.resolveSymbolicLinksSync();
  final testFilePath = _joinPath([
    rootPath,
    'lib',
    'target_${++_fileCounter}.dart',
  ]);
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

    final registry = _TestRuleVisitorRegistry();
    final context = _TestRuleContext(result);
    final reporter = _MockDiagnosticReporter(prefixLength: prefix.length);

    rule
      ..reporter = reporter
      ..registerNodeProcessors(registry, context);
    result.unit.accept(_DispatchVisitor(registry));

    return reporter.reportedLints;
  } finally {
    if (testFile.existsSync()) {
      testFile.deleteSync();
    }
  }
}

/// Runs [rule] and applies the [ResolvedCorrectionProducer] created by
/// [fixFactory] to the first reported diagnostic, returning the transformed
/// source code (with any auto-prepended preamble stripped).
Future<String> runLintFix(
  AnalysisRule rule,
  ResolvedCorrectionProducer Function({
    required CorrectionProducerContext context,
  })
  fixFactory,
  String sourceCode, {
  void Function(ResolvedCorrectionProducer producer)? onProducer,
  int? selectionOffset,
}) async {
  final collection = _getOrCreateCollection();
  final rootPath = _tempWorkspaceDir!.resolveSymbolicLinksSync();
  final testFilePath = _joinPath([
    rootPath,
    'lib',
    'target_${++_fileCounter}.dart',
  ]);
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
    final libResult = await session.getResolvedLibrary(testFilePath);
    if (libResult is! ResolvedLibraryResult) {
      throw StateError(
        'Failed to resolve library for $testFilePath: $libResult',
      );
    }
    final unitResult = libResult.units.firstWhere(
      (u) => u.path == testFilePath,
    );

    final int targetOffset;
    final int targetLength;
    if (selectionOffset != null) {
      targetOffset = selectionOffset + prefix.length;
      targetLength = 0;
    } else {
      final registry = _TestRuleVisitorRegistry();
      final ruleContext = _TestRuleContext(unitResult);
      final reporter = _MockDiagnosticReporter(prefixLength: prefix.length);

      rule
        ..reporter = reporter
        ..registerNodeProcessors(registry, ruleContext);
      unitResult.unit.accept(_DispatchVisitor(registry));

      if (reporter.reportedLints.isEmpty) {
        throw StateError('Expected at least one diagnostic from ${rule.name}');
      }
      final firstLint = reporter.reportedLints.first;
      targetOffset = firstLint.offset + prefix.length;
      targetLength = firstLint.length;
    }
    final producerContext = CorrectionProducerContext.createResolved(
      libraryResult: libResult,
      unitResult: unitResult,
      selectionOffset: targetOffset,
      selectionLength: targetLength,
    );
    final producer = fixFactory(context: producerContext);
    onProducer?.call(producer);
    final builder = ChangeBuilder(session: session);
    await producer.compute(builder);

    var edited = fullSource;
    final fileEdit = builder.sourceChange.edits
        .where((e) => e.file == testFilePath)
        .firstOrNull;
    if (fileEdit != null) {
      final edits = List.of(fileEdit.edits)
        ..sort((a, b) => b.offset.compareTo(a.offset));
      for (final edit in edits) {
        edited = edited.replaceRange(
          edit.offset,
          edit.offset + edit.length,
          edit.replacement,
        );
      }
    }

    return edited.startsWith(prefix) ? edited.substring(prefix.length) : edited;
  } finally {
    if (testFile.existsSync()) {
      testFile.deleteSync();
    }
  }
}

class _MockDiagnosticReporter implements DiagnosticReporter {
  new({required this.prefixLength});

  final int prefixLength;
  final List<ReportedLint> reportedLints = [];

  @override
  Diagnostic atNode(
    AstNode node,
    DiagnosticCode diagnosticCode, {
    List<Object>? arguments,
    List<DiagnosticMessage>? contextMessages,
    Object? data,
  }) {
    final adjustedOffset = node.offset - prefixLength;
    reportedLints.add(
      ReportedLint(
        code: diagnosticCode,
        lexeme: node.toSource(),
        offset: adjustedOffset,
        length: node.length,
        arguments: arguments,
      ),
    );
    return _TestDiagnostic(SourceRange(adjustedOffset, node.length));
  }

  @override
  Diagnostic atToken(
    Token token,
    DiagnosticCode diagnosticCode, {
    List<Object>? arguments,
    List<DiagnosticMessage>? contextMessages,
    Object? data,
  }) {
    final adjustedOffset = token.offset - prefixLength;
    reportedLints.add(
      ReportedLint(
        code: diagnosticCode,
        lexeme: token.lexeme,
        offset: adjustedOffset,
        length: token.length,
        arguments: arguments,
      ),
    );
    return _TestDiagnostic(SourceRange(adjustedOffset, token.length));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestDiagnostic implements Diagnostic {
  new(this.sourceRange);

  final SourceRange sourceRange;

  @override
  int get offset => sourceRange.offset;

  @override
  int get length => sourceRange.length;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestRuleContext implements RuleContext {
  new(this._unitResult);

  final ResolvedUnitResult _unitResult;

  @override
  LibraryElement? get libraryElement => _unitResult.libraryElement;

  @override
  TypeProvider get typeProvider => _unitResult.typeProvider;

  @override
  TypeSystem get typeSystem => _unitResult.typeSystem;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestRuleVisitorRegistry implements RuleVisitorRegistry {
  final List<AstVisitor<void>> _classDeclarations = [];
  final List<AstVisitor<void>> _mixinDeclarations = [];
  final List<AstVisitor<void>> _methodDeclarations = [];
  final List<AstVisitor<void>> _methodInvocations = [];
  final List<AstVisitor<void>> _instanceCreationExpressions = [];
  final List<AstVisitor<void>> _topLevelVariableDeclarations = [];
  final List<AstVisitor<void>> _fieldDeclarations = [];
  final List<AstVisitor<void>> _expressionStatements = [];
  final List<AstVisitor<void>> _superConstructorInvocations = [];

  List<AstVisitor<void>> get classDeclarations =>
      List<AstVisitor<void>>.unmodifiable(_classDeclarations);

  List<AstVisitor<void>> get mixinDeclarations =>
      List<AstVisitor<void>>.unmodifiable(_mixinDeclarations);

  List<AstVisitor<void>> get methodDeclarations =>
      List<AstVisitor<void>>.unmodifiable(_methodDeclarations);

  List<AstVisitor<void>> get methodInvocations =>
      List<AstVisitor<void>>.unmodifiable(_methodInvocations);

  List<AstVisitor<void>> get instanceCreationExpressions =>
      List<AstVisitor<void>>.unmodifiable(_instanceCreationExpressions);

  List<AstVisitor<void>> get topLevelVariableDeclarations =>
      List<AstVisitor<void>>.unmodifiable(_topLevelVariableDeclarations);

  List<AstVisitor<void>> get fieldDeclarations =>
      List<AstVisitor<void>>.unmodifiable(_fieldDeclarations);

  List<AstVisitor<void>> get expressionStatements =>
      List<AstVisitor<void>>.unmodifiable(_expressionStatements);

  List<AstVisitor<void>> get superConstructorInvocations =>
      List<AstVisitor<void>>.unmodifiable(_superConstructorInvocations);

  @override
  void addClassDeclaration(
    AbstractAnalysisRule rule,
    AstVisitor<void> visitor,
  ) => _classDeclarations.add(visitor);

  @override
  void addMixinDeclaration(
    AbstractAnalysisRule rule,
    AstVisitor<void> visitor,
  ) => _mixinDeclarations.add(visitor);

  @override
  void addMethodDeclaration(
    AbstractAnalysisRule rule,
    AstVisitor<void> visitor,
  ) => _methodDeclarations.add(visitor);

  @override
  void addMethodInvocation(
    AbstractAnalysisRule rule,
    AstVisitor<void> visitor,
  ) => _methodInvocations.add(visitor);

  @override
  void addInstanceCreationExpression(
    AbstractAnalysisRule rule,
    AstVisitor<void> visitor,
  ) => _instanceCreationExpressions.add(visitor);

  @override
  void addTopLevelVariableDeclaration(
    AbstractAnalysisRule rule,
    AstVisitor<void> visitor,
  ) => _topLevelVariableDeclarations.add(visitor);

  @override
  void addFieldDeclaration(
    AbstractAnalysisRule rule,
    AstVisitor<void> visitor,
  ) => _fieldDeclarations.add(visitor);

  @override
  void addExpressionStatement(
    AbstractAnalysisRule rule,
    AstVisitor<void> visitor,
  ) => _expressionStatements.add(visitor);

  @override
  void addSuperConstructorInvocation(
    AbstractAnalysisRule rule,
    AstVisitor<void> visitor,
  ) => _superConstructorInvocations.add(visitor);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DispatchVisitor extends RecursiveAstVisitor<void> {
  new(this.registry);
  final _TestRuleVisitorRegistry registry;

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    for (final visitor in List.of(registry.classDeclarations)) {
      visitor.visitClassDeclaration(node);
    }
    super.visitClassDeclaration(node);
  }

  @override
  void visitMixinDeclaration(MixinDeclaration node) {
    for (final visitor in List.of(registry.mixinDeclarations)) {
      visitor.visitMixinDeclaration(node);
    }
    super.visitMixinDeclaration(node);
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    for (final visitor in List.of(registry.methodDeclarations)) {
      visitor.visitMethodDeclaration(node);
    }
    super.visitMethodDeclaration(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    for (final visitor in List.of(registry.methodInvocations)) {
      visitor.visitMethodInvocation(node);
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    for (final visitor in List.of(registry.instanceCreationExpressions)) {
      visitor.visitInstanceCreationExpression(node);
    }
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitTopLevelVariableDeclaration(TopLevelVariableDeclaration node) {
    for (final visitor in List.of(registry.topLevelVariableDeclarations)) {
      visitor.visitTopLevelVariableDeclaration(node);
    }
    super.visitTopLevelVariableDeclaration(node);
  }

  @override
  void visitFieldDeclaration(FieldDeclaration node) {
    for (final visitor in List.of(registry.fieldDeclarations)) {
      visitor.visitFieldDeclaration(node);
    }
    super.visitFieldDeclaration(node);
  }

  @override
  void visitExpressionStatement(ExpressionStatement node) {
    for (final visitor in List.of(registry.expressionStatements)) {
      visitor.visitExpressionStatement(node);
    }
    super.visitExpressionStatement(node);
  }

  @override
  void visitSuperConstructorInvocation(SuperConstructorInvocation node) {
    for (final visitor in List.of(registry.superConstructorInvocations)) {
      visitor.visitSuperConstructorInvocation(node);
    }
    super.visitSuperConstructorInvocation(node);
  }
}

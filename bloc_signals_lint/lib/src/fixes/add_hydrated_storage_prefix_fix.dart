import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analysis_server_plugin/edit/dart/dart_fix_kind_priority.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/fixes/fixes.dart';

/// An automated IDE quick-fix for `RequireHydratedStoragePrefix` that inserts
/// `@override String get storagePrefix => '<snake_case>';`.
class AddHydratedStoragePrefixFix extends ResolvedCorrectionProducer {
  /// Creates an [AddHydratedStoragePrefixFix] instance.
  new({required super.context});

  static const _fixKind = FixKind(
    'bloc_signals_lint.fix.addHydratedStoragePrefix',
    DartFixKindPriority.standard,
    "Add '@override String get storagePrefix'",
  );

  @override
  CorrectionApplicability get applicability =>
      CorrectionApplicability.singleLocation;

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final classDecl = node.thisOrAncestorOfType<ClassDeclaration>();
    if (classDecl == null) return;

    final className = classDecl.namePart.typeName.lexeme;
    final snakeName = _toSnakeCase(className).replaceAll(r'$', r'\$');
    final body = classDecl.body;

    if (body is EmptyClassBody) {
      await builder.addDartFileEdit(file, (builder) {
        builder.addSimpleReplacement(
          body.sourceRange,
          " {\n  @override\n  String get storagePrefix => '$snakeName';\n}",
        );
      });
      return;
    }

    if (body is BlockClassBody) {
      await builder.addDartFileEdit(file, (builder) {
        builder.addSimpleInsertion(
          body.leftBracket.end,
          "\n  @override\n  String get storagePrefix => '$snakeName';\n",
        );
      });
    }
  }

  static String _toSnakeCase(String input) {
    return input
        .replaceAllMapped(
          RegExp('(?<=[a-z0-9])([A-Z])'),
          (m) => '_${m.group(1)!.toLowerCase()}',
        )
        .toLowerCase();
  }
}

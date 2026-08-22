import 'package:blocsignal_website/src/components/docs/pages/docs_decision_matrix.dart';
import 'package:test/test.dart';

void main() {
  group('DocsDecisionMatrixPage & StateDecisionWizard Tests', () {
    test('DocsDecisionMatrixPage instantiates with expected headings', () {
      const page = DocsDecisionMatrixPage();
      expect(page, isNotNull);
      expect(DocsDecisionMatrixPage.headings, isNotEmpty);
      expect(
        DocsDecisionMatrixPage.headings.map((h) => h.anchor),
        containsAll([
          'interactive-wizard',
          'comparison-matrix',
          'when-to-use-signals',
          'when-to-use-cubit',
          'when-to-use-bloc',
          'specialized-mixins',
          'code-recipes',
        ]),
      );
    });

    test('StateDecisionWizard instantiates correctly', () {
      const wizard = StateDecisionWizard();
      expect(wizard, isNotNull);
    });
  });
}

import 'dart:async';

import 'package:bloc_signals_jaspr/bloc_signals_jaspr.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:web/web.dart' as web;

import '../../cubits/docs_cubit.dart';

/// A code block component with syntax header, copy button, and optional side-by-side tabs.
class const DocsCodeBlock({
  final String? title,
  final String? filename,
  final String? code,
  final String? dart35Code,
  final String? dart313Code,
  final String language = 'dart',
  super.key,
}) extends StatefulComponent {
  String? get displayTitle => title ?? filename;

  @override
  State<DocsCodeBlock> createState() => _DocsCodeBlockState();
}

class _DocsCodeBlockState() extends State<DocsCodeBlock> {
  bool _copied = false;
  Timer? _copyTimer;
  String? _overrideTab;

  String _currentCode(String effectiveVersion) {
    if (component.code != null) return component.code!;
    if (effectiveVersion == '3.13' && component.dart313Code != null) {
      return component.dart313Code!;
    }
    return component.dart35Code ?? component.dart313Code ?? '';
  }

  void _copyToClipboard(String codeToCopy) {
    try {
      web.window.navigator.clipboard.writeText(codeToCopy);
      setState(() {
        _copied = true;
      });
      _copyTimer?.cancel();
      _copyTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _copied = false;
          });
        }
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _copyTimer?.cancel();
    super.dispose();
  }

  @override
  Component build(BuildContext context) {
    final hasDualVersions =
        component.dart35Code != null && component.dart313Code != null;

    String globalVersion = '3.13';
    try {
      globalVersion = context.read<DocsCubit>().stateValue.selectedDartVersion;
    } catch (_) {}
    final activeTab = _overrideTab ?? globalVersion;
    final activeCode = _currentCode(activeTab);

    return div(classes: 'docs-code-container', [
      div(classes: 'docs-code-header', [
        div(classes: 'docs-code-title-group', [
          if (component.displayTitle != null) ...[
            span(classes: 'docs-code-file-icon', [Component.text('📄')]),
            span(classes: 'docs-code-filename', [
              Component.text(component.displayTitle!),
            ]),
          ] else ...[
            span(classes: 'docs-code-lang-badge', [
              Component.text(component.language.toUpperCase()),
            ]),
          ],
        ]),
        div(classes: 'docs-code-actions', [
          if (hasDualVersions) ...[
            div(classes: 'docs-version-tabs', [
              button(
                classes:
                    'docs-version-tab ${activeTab == "3.13" ? "active" : ""}',
                onClick: () {
                  setState(() {
                    _overrideTab = '3.13';
                  });
                },
                [Component.text('Dart 3.13+ (Modern)')],
              ),
              button(
                classes:
                    'docs-version-tab ${activeTab == "3.5" ? "active" : ""}',
                onClick: () {
                  setState(() {
                    _overrideTab = '3.5';
                  });
                },
                [Component.text('Dart 3.5 (Baseline)')],
              ),
            ]),
          ],
          button(
            classes: 'docs-copy-btn ${_copied ? "copied" : ""}',
            onClick: () => _copyToClipboard(activeCode),
            attributes: {'aria-label': 'Copy code to clipboard'},
            [
              span(classes: 'docs-copy-icon', [
                Component.text(_copied ? '✓' : '📋'),
              ]),
              span(classes: 'docs-copy-text', [
                Component.text(_copied ? 'Copied!' : 'Copy'),
              ]),
            ],
          ),
        ]),
      ]),
      pre(classes: 'docs-code-body', [
        code(classes: 'language-${component.language}', [
          Component.text(activeCode),
        ]),
      ]),
    ]);
  }
}

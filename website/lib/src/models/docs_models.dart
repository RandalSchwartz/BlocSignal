import 'package:jaspr/jaspr.dart';

/// Represents an anchor heading inside a documentation article's Table of Contents.
class const TocHeading({
  required final String title,
  required final String anchor,
  final int level = 2,
});

/// Represents a single documentation article or topic page.
class const DocSectionItem({
  required final String id,
  required final String title,
  required final String path,
  required final String category,
  required final String description,
  final String? badge,
  required final Component Function() builder,
  required final List<TocHeading> headings,
  required final String sourcePath,
});

/// Represents a grouping category in the Docs navigation tree.
class const DocCategory({
  required final String title,
  required final String icon,
  required final List<DocSectionItem> sections,
});

/// Immutable state for the Docs Hub reactive cubit.
class const DocsState({
  required final String activeSectionId,
  required final String searchQuery,
  required final Set<String> expandedCategories,
  required final bool isMobileDrawerOpen,
  required final String selectedDartVersion, // '3.13' or '3.5'
}) {
  DocsState copyWith({
    String? activeSectionId,
    String? searchQuery,
    Set<String>? expandedCategories,
    bool? isMobileDrawerOpen,
    String? selectedDartVersion,
  }) {
    return DocsState(
      activeSectionId: activeSectionId ?? this.activeSectionId,
      searchQuery: searchQuery ?? this.searchQuery,
      expandedCategories: expandedCategories ?? this.expandedCategories,
      isMobileDrawerOpen: isMobileDrawerOpen ?? this.isMobileDrawerOpen,
      selectedDartVersion: selectedDartVersion ?? this.selectedDartVersion,
    );
  }
}

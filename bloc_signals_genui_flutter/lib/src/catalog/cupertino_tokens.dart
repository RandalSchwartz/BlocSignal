import 'package:bloc_signals_genui_flutter/src/a2ui_flutter_catalog.dart';
import 'package:flutter/cupertino.dart';

/// Design tokens for styling Cupertino components in [A2uiFlutterCatalog].
///
/// Allows customizing primary accent color, card background color,
/// navigation bar color, scaffold background, corner radius, and Cupertino
/// text typography.
///
/// ```dart
/// const tokens = CupertinoCatalogTokens(
///   primaryColor: CupertinoColors.activeBlue,
///   borderRadius: BorderRadius.all(Radius.circular(12)),
/// );
/// final catalog = A2uiFlutterCatalog.cupertino(tokens: tokens);
/// ```
@immutable
class CupertinoCatalogTokens {
  /// Creates a [CupertinoCatalogTokens] configuration.
  const CupertinoCatalogTokens({
    this.primaryColor,
    this.cardColor,
    this.barBackgroundColor,
    this.scaffoldBackgroundColor,
    this.borderRadius,
    this.textTheme,
  });

  /// Primary accent tint color used for buttons, active switches, and sliders.
  final Color? primaryColor;

  /// Background color for card containers.
  final Color? cardColor;

  /// Background color for navigation bars or modal headers.
  final Color? barBackgroundColor;

  /// Background color for full surface scaffold containers.
  final Color? scaffoldBackgroundColor;

  /// Default border radius applied to buttons, cards, and input fields.
  final BorderRadius? borderRadius;

  /// Cupertino typography hierarchy customization.
  final CupertinoTextThemeData? textTheme;

  /// Returns a copy of this [CupertinoCatalogTokens] with the given fields
  /// replaced.
  CupertinoCatalogTokens copyWith({
    Color? primaryColor,
    Color? cardColor,
    Color? barBackgroundColor,
    Color? scaffoldBackgroundColor,
    BorderRadius? borderRadius,
    CupertinoTextThemeData? textTheme,
  }) {
    return CupertinoCatalogTokens(
      primaryColor: primaryColor ?? this.primaryColor,
      cardColor: cardColor ?? this.cardColor,
      barBackgroundColor: barBackgroundColor ?? this.barBackgroundColor,
      scaffoldBackgroundColor:
          scaffoldBackgroundColor ?? this.scaffoldBackgroundColor,
      borderRadius: borderRadius ?? this.borderRadius,
      textTheme: textTheme ?? this.textTheme,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CupertinoCatalogTokens &&
        other.primaryColor == primaryColor &&
        other.cardColor == cardColor &&
        other.barBackgroundColor == barBackgroundColor &&
        other.scaffoldBackgroundColor == scaffoldBackgroundColor &&
        other.borderRadius == borderRadius &&
        other.textTheme == textTheme;
  }

  @override
  int get hashCode => Object.hash(
        primaryColor,
        cardColor,
        barBackgroundColor,
        scaffoldBackgroundColor,
        borderRadius,
        textTheme,
      );

  @override
  String toString() {
    return 'CupertinoCatalogTokens('
        'primaryColor: $primaryColor, '
        'cardColor: $cardColor, '
        'barBackgroundColor: $barBackgroundColor, '
        'scaffoldBackgroundColor: $scaffoldBackgroundColor, '
        'borderRadius: $borderRadius, '
        'textTheme: $textTheme'
        ')';
  }
}

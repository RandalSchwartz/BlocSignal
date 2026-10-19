import 'package:a2ui_core/a2ui_core.dart';
import 'package:json_schema_builder/json_schema_builder.dart'
    hide ValidationResult;

/// Backward-compatible type alias for [StandardCatalog].
///
/// ```dart
/// final catalog = MinimalCatalog();
/// ```
typedef MinimalCatalog = StandardCatalog;

/// Schema API definition for the standard A2UI `Card` component.
///
/// ```dart
/// final api = CardComponentApi();
/// ```
class CardComponentApi extends ComponentApi {
  /// Creates a [CardComponentApi].
  CardComponentApi()
      : super(
          name: 'Card',
          schema: Schema.object(
            properties: {
              'child': Schema.combined(
                anyOf: [
                  CommonSchemas.componentId,
                  CommonSchemas.dataBinding,
                ],
              ),
              'children': CommonSchemas.childList,
              'elevation': Schema.number(),
            },
          ),
        );
}

/// Schema API definition for the standard A2UI `Divider` component.
///
/// ```dart
/// final api = DividerComponentApi();
/// ```
class DividerComponentApi extends ComponentApi {
  /// Creates a [DividerComponentApi].
  DividerComponentApi()
      : super(
          name: 'Divider',
          schema: Schema.object(
            properties: {
              'axis': Schema.string(enumValues: ['horizontal', 'vertical']),
              'height': Schema.number(),
              'thickness': Schema.number(),
              'color': Schema.string(),
            },
          ),
        );
}

/// Schema API definition for the extended A2UI `Text` component supporting
/// all typography variants.
///
/// ```dart
/// final api = StandardTextApi();
/// ```
class StandardTextApi extends ComponentApi {
  /// Creates a [StandardTextApi].
  StandardTextApi()
      : super(
          name: 'Text',
          schema: Schema.combined(
            allOf: [
              CommonSchemas.checkable,
              Schema.object(
                properties: {
                  'text': Schema.combined(
                    anyOf: [
                      CommonSchemas.dynamicString,
                      CommonSchemasV1.dynamicString,
                    ],
                  ),
                  'variant': Schema.string(
                    enumValues: [
                      'h1',
                      'h2',
                      'h3',
                      'h4',
                      'h5',
                      'title',
                      'caption',
                      'body',
                    ],
                  ),
                },
                required: ['text'],
              ),
            ],
          ),
        );
}

/// Schema API definition for the standard A2UI `Row` component.
///
/// ```dart
/// final api = StandardRowApi();
/// ```
class StandardRowApi extends ComponentApi {
  /// Creates a [StandardRowApi].
  StandardRowApi()
      : super(
          name: 'Row',
          schema: Schema.object(
            properties: {
              'children': CommonSchemas.childList,
              'justify': Schema.string(),
              'align': Schema.string(),
              'mainAxisAlignment': Schema.string(),
              'crossAxisAlignment': Schema.string(),
            },
            required: ['children'],
          ),
        );
}

/// Schema API definition for the standard A2UI `Column` component.
///
/// ```dart
/// final api = StandardColumnApi();
/// ```
class StandardColumnApi extends ComponentApi {
  /// Creates a [StandardColumnApi].
  StandardColumnApi()
      : super(
          name: 'Column',
          schema: Schema.object(
            properties: {
              'children': CommonSchemas.childList,
              'justify': Schema.string(),
              'align': Schema.string(),
              'mainAxisAlignment': Schema.string(),
              'crossAxisAlignment': Schema.string(),
            },
            required: ['children'],
          ),
        );
}

/// Schema API definition for the standard A2UI `Button` component.
///
/// ```dart
/// final api = StandardButtonApi();
/// ```
class StandardButtonApi extends ComponentApi {
  /// Creates a [StandardButtonApi].
  StandardButtonApi()
      : super(
          name: 'Button',
          schema: Schema.combined(
            allOf: [
              CommonSchemas.checkable,
              Schema.object(
                properties: {
                  'child': Schema.combined(
                    anyOf: [
                      CommonSchemas.componentId,
                      CommonSchemas.dataBinding,
                    ],
                  ),
                  'action': CommonSchemas.action,
                  'variant': Schema.string(
                    enumValues: ['default', 'primary', 'borderless'],
                  ),
                  'label': CommonSchemas.dynamicString,
                  'text': CommonSchemas.dynamicString,
                  'title': CommonSchemas.dynamicString,
                },
                required: ['child', 'action'],
              ),
            ],
          ),
        );
}

/// Schema API definition for the standard A2UI `TextField` component.
///
/// ```dart
/// final api = StandardTextFieldApi();
/// ```
class StandardTextFieldApi extends ComponentApi {
  /// Creates a [StandardTextFieldApi].
  StandardTextFieldApi()
      : super(
          name: 'TextField',
          schema: Schema.combined(
            allOf: [
              CommonSchemas.checkable,
              Schema.object(
                properties: {
                  'label': Schema.combined(
                    anyOf: [
                      CommonSchemas.dynamicString,
                      CommonSchemasV1.dynamicString,
                    ],
                  ),
                  'value': Schema.combined(
                    anyOf: [
                      CommonSchemas.dynamicString,
                      CommonSchemasV1.dynamicString,
                    ],
                  ),
                  'textFieldType': Schema.string(
                    enumValues: [
                      'shortText',
                      'longText',
                      'number',
                      'obscured',
                      'date',
                    ],
                  ),
                  'placeholder': CommonSchemas.dynamicString,
                  'helperText': CommonSchemas.dynamicString,
                  'errorText': CommonSchemas.dynamicString,
                  'validationRegexp': Schema.string(),
                  'pattern': Schema.string(),
                  'required': Schema.boolean(),
                  'isRequired': Schema.boolean(),
                  'minLength': Schema.integer(),
                  'maxLength': Schema.integer(),
                },
                required: ['label'],
              ),
            ],
          ),
        );
}

/// Built-in string capitalization function for [StandardCatalog].
///
/// ```dart
/// final fn = CapitalizeFunction();
/// ```
class CapitalizeFunction extends FunctionImplementation {
  /// Creates a [CapitalizeFunction].
  CapitalizeFunction()
      : super(
          name: 'capitalize',
          returnType: A2uiReturnType.string,
          argumentSchema: Schema.object(
            properties: {
              'value': Schema.string(),
            },
            required: ['value'],
          ),
        );

  @override
  Object? execute(
    Map<String, Object?> args,
    DataContext context, [
    CancellationSignal? cancellationSignal,
  ]) {
    final val = args['value']?.toString() ?? '';
    if (val.isEmpty) return '';
    return '${val[0].toUpperCase()}${val.substring(1)}';
  }
}

/// A comprehensive component catalog supporting all core and standard A2UI
/// components: `Text`, `Row`, `Column`, `Button`, `TextField`, `Card`, and `Divider`.
///
/// ```dart
/// final catalog = StandardCatalog();
/// ```
class StandardCatalog extends Catalog<ComponentApi, FunctionImplementation> {
  /// Creates a [StandardCatalog].
  ///
  /// Defaults to the standard minimal catalog URI if [id] is omitted.
  StandardCatalog({
    super.id =
        'https://a2ui.org/specification/v0_9/catalogs/minimal/minimal_catalog.json',
  }) : super(
          components: [
            StandardTextApi(),
            StandardRowApi(),
            StandardColumnApi(),
            StandardButtonApi(),
            StandardTextFieldApi(),
            CardComponentApi(),
            DividerComponentApi(),
          ],
          functions: [
            CapitalizeFunction(),
            ...BasicCatalog.v0_9().functions.values,
          ],
          themeSchema: Schema.object(
            properties: {
              'primaryColor': Schema.string(pattern: r'^#[0-9a-fA-F]{6}$'),
            },
            additionalProperties: true,
          ),
        );
}

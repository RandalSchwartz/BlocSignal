import 'package:a2ui_core/a2ui_core.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

/// Schema API definition for the standard A2UI `Card` component.
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
class DividerComponentApi extends ComponentApi {
  /// Creates a [DividerComponentApi].
  DividerComponentApi()
      : super(
          name: 'Divider',
          schema: Schema.object(
            properties: {
              'height': Schema.number(),
              'thickness': Schema.number(),
              'color': Schema.string(),
            },
          ),
        );
}

/// Schema API definition for the extended A2UI `Text` component supporting
/// all typography variants.
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
                  'text': CommonSchemas.dynamicString,
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

/// A comprehensive component catalog supporting all core and standard A2UI
/// components: `Text`, `Row`, `Column`, `Button`, `TextField`, `Card`, and `Divider`.
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
            MinimalRowApi(),
            MinimalColumnApi(),
            MinimalButtonApi(),
            MinimalTextFieldApi(),
            CardComponentApi(),
            DividerComponentApi(),
          ],
          functions: [CapitalizeFunction()],
          themeSchema: Schema.object(
            properties: {
              'primaryColor': Schema.string(pattern: r'^#[0-9a-fA-F]{6}$'),
            },
            additionalProperties: true,
          ),
        );
}

import 'package:bloc_signals_genui/bloc_signals_genui.dart';
import 'package:bloc_signals_genui_flutter/bloc_signals_genui_flutter.dart';
import 'package:bloc_signals_genui_flutter/src/catalog/widgets/cupertino/cupertino_image.dart';
// Preserves sdk: ^3.5.0 compatibility on Flutter <3.47.
// ignore: deprecated_member_use
import 'package:flutter/cupertino.dart';
// Preserves sdk: ^3.5.0 compatibility on Flutter <3.47.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

A2uiComponentContext _buildImageContext(
  A2uiSurfaceBloc bloc, {
  required String url,
  String variant = 'mediumFeature',
}) {
  final props = <String, Object?>{
    'url': url,
    'variant': variant,
  };
  return A2uiComponentContext(
    component: ComponentModel('img-1', 'Image', props),
    props: props,
    surfaceBloc: bloc,
    buildChildCallback: (_) => const SizedBox.shrink(),
    buildChildrenCallback: (_) => const <Widget>[],
    surfaceId: 'surf-image-test',
  );
}

void main() {
  group('(Issue #423) Image URL policy & decode cache bounds', () {
    testWidgets('Material buildA2uiImage blocks disallowed URLs with fallback',
        (tester) async {
      final bloc = A2uiSurfaceBloc();
      addTearDown(bloc.close);

      for (final blockedUrl in const [
        'http://example.com/a.png',
        'https://169.254.169.254/latest/meta-data',
        'javascript:alert(1)',
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => buildA2uiImage(
                  context,
                  _buildImageContext(bloc, url: blockedUrl),
                ),
              ),
            ),
          ),
        );

        expect(find.byType(Image), findsNothing, reason: blockedUrl);
        expect(
          find.byIcon(Icons.broken_image_outlined),
          findsOneWidget,
          reason: blockedUrl,
        );
      }
    });

    testWidgets(
        'Material buildA2uiImage bounds cacheWidth/cacheHeight by DPR for '
        'finite variants', (tester) async {
      final bloc = A2uiSurfaceBloc();
      addTearDown(bloc.close);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(devicePixelRatio: 2),
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => buildA2uiImage(
                  context,
                  _buildImageContext(
                    bloc,
                    url: 'https://example.com/photo.png',
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      final image = tester.widget<Image>(find.byType(Image));
      expect(
        image.image,
        isA<ResizeImage>().having(
          (r) => r.width,
          'width',
          480,
        ),
      );
      final resize = image.image as ResizeImage;
      expect(resize.height, 320);
      expect(
        resize.imageProvider,
        const NetworkImage('https://example.com/photo.png'),
      );
    });

    testWidgets(
        'Material buildA2uiImage leaves cacheWidth null for header variant',
        (tester) async {
      final bloc = A2uiSurfaceBloc();
      addTearDown(bloc.close);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(devicePixelRatio: 3),
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => buildA2uiImage(
                  context,
                  _buildImageContext(
                    bloc,
                    url: 'https://example.com/banner.png',
                    variant: 'header',
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      final image = tester.widget<Image>(find.byType(Image));
      final resize = image.image as ResizeImage;
      expect(resize.width, isNull);
      expect(resize.height, 540);
    });

    testWidgets(
        'Cupertino buildCupertinoImage blocks disallowed URLs with fallback',
        (tester) async {
      final bloc = A2uiSurfaceBloc();
      addTearDown(bloc.close);

      await tester.pumpWidget(
        CupertinoApp(
          home: CupertinoPageScaffold(
            child: Builder(
              builder: (context) => buildCupertinoImage(
                context,
                _buildImageContext(bloc, url: 'https://127.0.0.1/secret.png'),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(Image), findsNothing);
      expect(find.byIcon(CupertinoIcons.photo), findsOneWidget);
    });

    testWidgets(
        'Cupertino buildCupertinoImage bounds cacheWidth/cacheHeight by DPR',
        (tester) async {
      final bloc = A2uiSurfaceBloc();
      addTearDown(bloc.close);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(devicePixelRatio: 2.5),
          child: CupertinoApp(
            home: CupertinoPageScaffold(
              child: Builder(
                builder: (context) => buildCupertinoImage(
                  context,
                  _buildImageContext(
                    bloc,
                    url: 'https://example.com/small.png',
                    variant: 'smallFeature',
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      final image = tester.widget<Image>(find.byType(Image));
      final resize = image.image as ResizeImage;
      expect(resize.width, 300);
      expect(resize.height, 200);
    });

    testWidgets(
        'Cupertino buildCupertinoImage leaves cacheWidth null for header '
        'variant', (tester) async {
      final bloc = A2uiSurfaceBloc();
      addTearDown(bloc.close);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(devicePixelRatio: 2),
          child: CupertinoApp(
            home: CupertinoPageScaffold(
              child: Builder(
                builder: (context) => buildCupertinoImage(
                  context,
                  _buildImageContext(
                    bloc,
                    url: 'https://example.com/header.png',
                    variant: 'header',
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      final image = tester.widget<Image>(find.byType(Image));
      final resize = image.image as ResizeImage;
      expect(resize.width, isNull);
      expect(resize.height, 360);
    });

    testWidgets(
        'A2uiFlutterCatalog.standard, .cupertino, and .adaptive thread custom '
        'imagePolicy', (tester) async {
      final bloc = A2uiSurfaceBloc();
      addTearDown(bloc.close);

      const customPolicy = A2uiImageUrlPolicy(
        allowedSchemes: {'http'},
        allowLoopback: true,
      );

      final catalogs = [
        A2uiFlutterCatalog.standard(imagePolicy: customPolicy),
        A2uiFlutterCatalog.cupertino(imagePolicy: customPolicy),
        A2uiFlutterCatalog.adaptive(
          imagePolicy: customPolicy,
          platformOverride: TargetPlatform.android,
        ),
        A2uiFlutterCatalog.adaptive(
          imagePolicy: customPolicy,
          platformOverride: TargetPlatform.iOS,
        ),
      ];

      for (final catalog in catalogs) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => catalog.build(
                  context,
                  _buildImageContext(
                    bloc,
                    url: 'http://localhost:8080/local.png',
                  ),
                ),
              ),
            ),
          ),
        );

        expect(find.byType(Image), findsOneWidget);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => catalog.build(
                  context,
                  _buildImageContext(
                    bloc,
                    url: 'https://example.com/blocked-by-custom.png',
                  ),
                ),
              ),
            ),
          ),
        );

        expect(find.byType(Image), findsNothing);
      }
    });
  });
}

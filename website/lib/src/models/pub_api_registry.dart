import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

/// Supported canonical API symbols linked to official pub.dev dartdoc documentation.
enum DocSymbol(
  final String symbolName,
  final String package,
  final String htmlFile,
) {
  // Core (bloc_signals)
  cubitSignal('CubitSignal', 'bloc_signals', 'CubitSignal-class.html'),
  blocSignal('BlocSignal', 'bloc_signals', 'BlocSignal-class.html'),
  blocSignalBase('BlocSignalBase', 'bloc_signals', 'BlocSignalBase-class.html'),
  blocSignalObserver(
    'BlocSignalObserver',
    'bloc_signals',
    'BlocSignalObserver-class.html',
  ),
  transition('Transition', 'bloc_signals', 'Transition-class.html'),
  change('Change', 'bloc_signals', 'Change-class.html'),
  blocSignalOn('on', 'bloc_signals', 'BlocSignal/on.html'),
  blocSignalEmit('emit', 'bloc_signals', 'BlocSignalBase/emit.html'),
  blocSignalAdd('add', 'bloc_signals', 'BlocSignal/add.html'),
  blocSignalClose('close', 'bloc_signals', 'BlocSignalBase/close.html'),
  blocSignalState('state', 'bloc_signals', 'BlocSignalBase/state.html'),
  blocSignalStateValue(
    'stateValue',
    'bloc_signals',
    'BlocSignalBase/stateValue.html',
  ),
  droppable('droppable', 'bloc_signals', 'droppable.html'),
  restartable('restartable', 'bloc_signals', 'restartable.html'),
  sequential('sequential', 'bloc_signals', 'sequential.html'),
  concurrent('concurrent', 'bloc_signals', 'concurrent.html'),

  // Flutter (bloc_signals_flutter)
  blocSignalProvider(
    'BlocSignalProvider',
    'bloc_signals_flutter',
    'BlocSignalProvider-class.html',
  ),
  multiBlocSignalProvider(
    'MultiBlocSignalProvider',
    'bloc_signals_flutter',
    'MultiBlocSignalProvider-class.html',
  ),
  blocSignalBuilder(
    'BlocSignalBuilder',
    'bloc_signals_flutter',
    'BlocSignalBuilder-class.html',
  ),
  blocSignalListener(
    'BlocSignalListener',
    'bloc_signals_flutter',
    'BlocSignalListener-class.html',
  ),
  multiBlocSignalListener(
    'MultiBlocSignalListener',
    'bloc_signals_flutter',
    'MultiBlocSignalListener-class.html',
  ),
  blocSignalConsumer(
    'BlocSignalConsumer',
    'bloc_signals_flutter',
    'BlocSignalConsumer-class.html',
  ),
  blocSignalSelector(
    'BlocSignalSelector',
    'bloc_signals_flutter',
    'BlocSignalSelector-class.html',
  ),
  blocSignalProviderExtension(
    'BlocSignalProviderExtension',
    'bloc_signals_flutter',
    'BlocSignalProviderExtension.html',
  ),
  contextRead(
    'read',
    'bloc_signals_flutter',
    'BlocSignalProviderExtension/read.html',
  ),
  contextWatch(
    'watch',
    'bloc_signals_flutter',
    'BlocSignalProviderExtension/watch.html',
  ),
  contextSelect(
    'select',
    'bloc_signals_flutter',
    'BlocSignalProviderExtension/select.html',
  ),

  // Testing (bloc_signals_test)
  blocSignalTest('blocSignalTest', 'bloc_signals_test', 'blocSignalTest.html'),

  // Hydrate (bloc_signals_hydrate)
  hydratedCubitSignal(
    'HydratedCubitSignal',
    'bloc_signals_hydrate',
    'HydratedCubitSignal-class.html',
  ),
  hydratedBlocSignal(
    'HydratedBlocSignal',
    'bloc_signals_hydrate',
    'HydratedBlocSignal-class.html',
  ),
  hydratedStorage(
    'HydratedStorage',
    'bloc_signals_hydrate',
    'HydratedStorage-class.html',
  ),
  sharedPreferencesHydratedStorage(
    'SharedPreferencesHydratedStorage',
    'bloc_signals_hydrate',
    'SharedPreferencesHydratedStorage-class.html',
  ),
  secureHydratedStorage(
    'SecureHydratedStorage',
    'bloc_signals_hydrate',
    'SecureHydratedStorage-class.html',
  ),

  // Replay (bloc_signals_replay)
  replayCubit('ReplayCubit', 'bloc_signals_replay', 'ReplayCubit-class.html'),
  replayBloc('ReplayBloc', 'bloc_signals_replay', 'ReplayBloc-class.html'),
  replayCubitMixin(
    'ReplayCubitMixin',
    'bloc_signals_replay',
    'ReplayCubitMixin-mixin.html',
  ),
  replayBlocMixin(
    'ReplayBlocMixin',
    'bloc_signals_replay',
    'ReplayBlocMixin-mixin.html',
  ),

  // Riverpod (bloc_signals_riverpod)
  riverpodBlocSignal(
    'RiverpodBlocSignal',
    'bloc_signals_riverpod',
    'RiverpodBlocSignal-class.html',
  ),
  riverpodNotifierBlocSignal(
    'RiverpodNotifierBlocSignal',
    'bloc_signals_riverpod',
    'RiverpodNotifierBlocSignal-class.html',
  ),
  blocSignalNotifier(
    'BlocSignalNotifier',
    'bloc_signals_riverpod',
    'BlocSignalNotifier-class.html',
  ),
  providerListenableBlocSignalX(
    'ProviderListenableBlocSignalX',
    'bloc_signals_riverpod',
    'ProviderListenableBlocSignalX.html',
  ),
  blocSignalRiverpodX(
    'BlocSignalRiverpodX',
    'bloc_signals_riverpod',
    'BlocSignalRiverpodX.html',
  ),

  // OpenTelemetry (bloc_signals_otel)
  otelBlocSignalObserver(
    'OtelBlocSignalObserver',
    'bloc_signals_otel',
    'OtelBlocSignalObserver-class.html',
  ),

  // DevTools (bloc_signals_devtools)
  devToolsBlocSignalObserver(
    'DevToolsBlocSignalObserver',
    'bloc_signals_devtools',
    'DevToolsBlocSignalObserver-class.html',
  ),

  // Classic BLoC (bloc_signals_bloc)
  classicBlocSignal(
    'ClassicBlocSignal',
    'bloc_signals_bloc',
    'ClassicBlocSignal-class.html',
  ),
  classicCubitSignal(
    'ClassicCubitSignal',
    'bloc_signals_bloc',
    'ClassicCubitSignal-class.html',
  ),
  blocSignalToClassicBloc(
    'BlocSignalToClassicBloc',
    'bloc_signals_bloc',
    'BlocSignalToClassicBloc-class.html',
  ),
  blocSignalToClassicCubit(
    'BlocSignalToClassicCubit',
    'bloc_signals_bloc',
    'BlocSignalToClassicCubit-class.html',
  ),
  classicBlocToBlocSignalX(
    'ClassicBlocToBlocSignalX',
    'bloc_signals_bloc',
    'ClassicBlocToBlocSignalX.html',
  ),
  classicCubitToBlocSignalX(
    'ClassicCubitToBlocSignalX',
    'bloc_signals_bloc',
    'ClassicCubitToBlocSignalX.html',
  ),
  blocSignalToClassicBlocX(
    'BlocSignalToClassicBlocX',
    'bloc_signals_bloc',
    'BlocSignalToClassicBlocX.html',
  ),
  blocSignalToClassicCubitX(
    'BlocSignalToClassicCubitX',
    'bloc_signals_bloc',
    'BlocSignalToClassicCubitX.html',
  );

  /// Canonical URL on pub.dev documentation.
  String get url =>
      'https://pub.dev/documentation/$package/latest/$package/$htmlFile';

  /// Renders a clickable inline code link to pub.dev dartdoc.
  Component link({String? label}) {
    return a(
      href: url,
      target: Target.blank,
      classes: 'docs-api-link',
      attributes: {
        'title': 'View $symbolName on pub.dev dartdoc ↗',
        'rel': 'noopener noreferrer',
      },
      [
        code([Component.text(label ?? symbolName)]),
        span(classes: 'docs-api-link-ext', [Component.text('↗')]),
      ],
    );
  }
}

/// Helper function to create an inline API doc link for any registered symbol name.
Component apiLink(DocSymbol symbol, {String? label}) =>
    symbol.link(label: label);

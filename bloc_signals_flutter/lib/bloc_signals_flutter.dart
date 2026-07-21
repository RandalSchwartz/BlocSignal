/// Flutter bindings and UI integrations for the reactive [BlocSignal] library.
///
/// Provides [BlocSignalProvider], [MultiBlocSignalProvider],
/// [BlocSignalBuilder], [BlocSignalListener], [BlocSignalConsumer], and
/// [BlocSignalSelector] to bridge reactive states with the Flutter widget tree.
library;

import 'package:bloc_signals/bloc_signals.dart';
import 'package:bloc_signals_flutter/src/bloc_signal_builder.dart';
import 'package:bloc_signals_flutter/src/bloc_signal_consumer.dart';
import 'package:bloc_signals_flutter/src/bloc_signal_listener.dart';
import 'package:bloc_signals_flutter/src/bloc_signal_provider.dart';
import 'package:bloc_signals_flutter/src/bloc_signal_selector.dart';

export 'package:bloc_signals/bloc_signals.dart';
export 'src/bloc_signal_builder.dart';
export 'src/bloc_signal_consumer.dart';
export 'src/bloc_signal_listener.dart';
export 'src/bloc_signal_provider.dart';
export 'src/bloc_signal_selector.dart';

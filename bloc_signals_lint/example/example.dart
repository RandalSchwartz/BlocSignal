/// Example showing how to configure `bloc_signals_lint` in `analysis_options.yaml`.
///
/// In your project's `analysis_options.yaml`:
/// ```yaml
/// analyzer:
///   plugins:
///     - custom_lint
/// ```
///
/// Then add `bloc_signals_lint` to your `dev_dependencies` in `pubspec.yaml`:
/// ```yaml
/// dev_dependencies:
///   custom_lint: ^0.7.0
///   bloc_signals_lint: ^0.2.1
/// ```
void main() {
  // `bloc_signals_lint` automatically highlights issues inside your IDE
  // such as duplicate event handlers, missing super.onEvent calls, or
  // calling emit() inside build() methods.
}

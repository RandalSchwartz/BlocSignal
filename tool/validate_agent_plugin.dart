import 'dart:convert';
import 'dart:io';

const _claudeCatalogPath = '.claude-plugin/marketplace.json';
const _codexCatalogPath = '.agents/plugins/marketplace.json';
const _pluginPath = 'plugins/bloc-signals';
const _pluginSkillPath = '$_pluginPath/skills/bloc-signals';
const _legacyRootSkillPath = 'skills/bloc-signals';
const _legacyAgentSkillPath = '.agents/skills/bloc-signals';

final List<String> _errors = [];

void main() {
  final root = _findRepositoryRoot();

  final claudeCatalog = _readObject(root, _claudeCatalogPath);
  final codexCatalog = _readObject(root, _codexCatalogPath);
  final claudeManifest = _readObject(
    root,
    '$_pluginPath/.claude-plugin/plugin.json',
  );
  final codexManifest = _readObject(
    root,
    '$_pluginPath/.codex-plugin/plugin.json',
  );

  _validateCatalogs(claudeCatalog, codexCatalog);
  _validateManifests(claudeManifest, codexManifest);
  _validateSkill(root);
  _validateNoLegacySkillCopies(root);
  _validateNoLegacySkillReferences(root);
  _validatePortablePaths(root);

  if (_errors.isNotEmpty) {
    stderr.writeln('Agent plugin validation failed:');
    for (final error in _errors) {
      stderr.writeln('- $error');
    }
    exitCode = 1;
    return;
  }

  stdout.writeln('Validated bloc-signals in both marketplaces.');
  stdout.writeln('The plugin contains the single BlocSignal skill bundle.');
}

Directory _findRepositoryRoot() {
  var candidate = Directory.current.absolute;
  while (true) {
    if (File('${candidate.path}/pubspec.yaml').existsSync() &&
        File('${candidate.path}/AGENTS.md').existsSync()) {
      return candidate;
    }
    final parent = candidate.parent;
    if (parent.path == candidate.path) {
      stderr.writeln('Run this command from the BlocSignal repository.');
      exit(2);
    }
    candidate = parent;
  }
}

Map<String, Object?> _readObject(Directory root, String relativePath) {
  final file = File('${root.path}/$relativePath');
  if (!file.existsSync()) {
    _errors.add('Missing $relativePath.');
    return <String, Object?>{};
  }
  try {
    final decoded = jsonDecode(file.readAsStringSync());
    if (decoded is Map<String, Object?>) return decoded;
    _errors.add('$relativePath must contain a JSON object.');
  } on FormatException catch (error) {
    _errors.add('$relativePath is not valid JSON: $error');
  }
  return <String, Object?>{};
}

void _validateCatalogs(
  Map<String, Object?> claude,
  Map<String, Object?> codex,
) {
  _expectEqual(claude['name'], 'blocsignal', 'Claude marketplace name');
  _expectEqual(codex['name'], 'blocsignal', 'Codex marketplace name');

  final claudePlugin = _onlyPlugin(claude, 'Claude');
  final codexPlugin = _onlyPlugin(codex, 'Codex');
  _expectEqual(claudePlugin['name'], 'bloc-signals', 'Claude plugin name');
  _expectEqual(codexPlugin['name'], 'bloc-signals', 'Codex plugin name');
  _expectEqual(
    claudePlugin['source'],
    './plugins/bloc-signals',
    'Claude plugin source',
  );

  final source = codexPlugin['source'];
  if (source is! Map<String, Object?>) {
    _errors.add('Codex plugin source must be an object.');
  } else {
    _expectEqual(source['source'], 'local', 'Codex source type');
    _expectEqual(
      source['path'],
      './plugins/bloc-signals',
      'Codex plugin source path',
    );
  }

  final policy = codexPlugin['policy'];
  if (policy is! Map<String, Object?>) {
    _errors.add('Codex plugin policy must be an object.');
  } else {
    _expectEqual(policy['installation'], 'AVAILABLE', 'installation policy');
    _expectEqual(policy['authentication'], 'ON_INSTALL', 'auth policy');
  }
  _expectEqual(codexPlugin['category'], 'Developer Tools', 'plugin category');
}

Map<String, Object?> _onlyPlugin(
  Map<String, Object?> catalog,
  String platform,
) {
  final plugins = catalog['plugins'];
  if (plugins is! List<Object?> || plugins.length != 1) {
    _errors.add('$platform marketplace must contain exactly one plugin.');
    return <String, Object?>{};
  }
  final plugin = plugins.single;
  if (plugin is! Map<String, Object?>) {
    _errors.add('$platform marketplace plugin must be an object.');
    return <String, Object?>{};
  }
  return plugin;
}

void _validateManifests(
  Map<String, Object?> claude,
  Map<String, Object?> codex,
) {
  for (final field in [
    'name',
    'version',
    'description',
    'homepage',
    'repository',
    'license',
  ]) {
    final value = claude[field];
    if (value is! String || value.trim().isEmpty) {
      _errors.add('Claude manifest $field must be a nonempty string.');
    }
    _expectEqual(codex[field], value, 'manifest $field parity');
  }
  _expectEqual(claude['name'], 'bloc-signals', 'manifest name');

  final version = claude['version'];
  if (version is String && !_isValidSemVer(version)) {
    _errors.add('Plugin version is not valid SemVer: $version');
  }

  final claudeAuthor = claude['author'];
  final codexAuthor = codex['author'];
  if (claudeAuthor is! Map<String, Object?> ||
      codexAuthor is! Map<String, Object?>) {
    _errors.add('Both manifests need an author object.');
  } else {
    for (final field in ['name', 'url']) {
      final value = claudeAuthor[field];
      if (value is! String || value.trim().isEmpty) {
        _errors.add('Claude manifest author.$field must be nonempty.');
      }
      _expectEqual(
        codexAuthor[field],
        value,
        'manifest author.$field parity',
      );
    }
    _expectEqual(claudeAuthor['name'], 'Randal L. Schwartz', 'manifest author');
  }

  final claudeKeywords = _stringList(claude, 'keywords', 'Claude manifest');
  final codexKeywords = _stringList(codex, 'keywords', 'Codex manifest');
  if (claudeKeywords != null &&
      codexKeywords != null &&
      !_sameStrings(claudeKeywords, codexKeywords)) {
    _errors.add('Manifest keywords must match in order.');
  }

  _expectEqual(
    claude['homepage'],
    'https://github.com/RandalSchwartz/BlocSignal',
    'manifest homepage',
  );
  _expectEqual(
    claude['repository'],
    'https://github.com/RandalSchwartz/BlocSignal',
    'manifest repository',
  );
  _expectEqual(claude['license'], 'MIT', 'manifest license');

  _expectEqual(codex['skills'], './skills/', 'Codex skills path');
  final interface = codex['interface'];
  if (interface is! Map<String, Object?>) {
    _errors.add('Codex manifest needs an interface object.');
  }
}

void _validateSkill(Directory root) {
  final pluginSkill = Directory('${root.path}/$_pluginSkillPath');
  if (!pluginSkill.existsSync()) {
    _errors.add('Missing $_pluginSkillPath.');
    return;
  }

  final pluginFiles = _relativeFiles(pluginSkill);
  const requiredFiles = {
    'SKILL.md',
    'agents/openai.yaml',
    'core.md',
    'flutter.md',
    'migration.md',
    'riverpod_migration.md',
    'otel.md',
    'testing.md',
  };
  final missingFiles = requiredFiles.difference(pluginFiles.keys.toSet());
  if (missingFiles.isNotEmpty) {
    _errors.add('Plugin skill is missing: ${missingFiles.join(', ')}.');
  }

  final skillFile = pluginFiles['SKILL.md'];
  if (skillFile == null) {
    _errors.add('The skill bundle needs SKILL.md.');
    return;
  }
  final skillText = skillFile.readAsStringSync();
  final frontmatter = RegExp(
    r'^---\nname: ([^\n]+)\ndescription: ([^\n]+)\n---\n',
  ).firstMatch(skillText);
  if (frontmatter == null) {
    _errors.add('SKILL.md needs name and description frontmatter only.');
  } else {
    _expectEqual(frontmatter.group(1), 'bloc-signals', 'skill name');
    if (frontmatter.group(2)!.trim().isEmpty) {
      _errors.add('Skill description must not be empty.');
    }
  }

  final openAi = pluginFiles['agents/openai.yaml'];
  if (openAi == null) {
    _errors.add('The skill bundle needs agents/openai.yaml.');
  } else {
    _validateOpenAiYaml(openAi);
  }
}

void _validateNoLegacySkillCopies(Directory root) {
  for (final path in [_legacyRootSkillPath, _legacyAgentSkillPath]) {
    if (Directory('${root.path}/$path').existsSync()) {
      _errors.add('Remove legacy skill directory $path.');
    }
  }
}

void _validateNoLegacySkillReferences(Directory root) {
  const legacyFragments = [
    'context7.com/skills',
    'ctx7@',
    '../skills/bloc-signals',
    './skills/bloc-signals',
    'skills/bloc-signals/SKILL.md',
  ];
  for (final entity in root.listSync(recursive: true, followLinks: false)) {
    if (entity is! File || !entity.path.endsWith('.md')) continue;
    final relative = entity.path.substring(root.path.length + 1);
    if (relative.startsWith('.git/')) continue;
    final text = entity.readAsStringSync();
    for (final fragment in legacyFragments) {
      if (text.contains(fragment)) {
        _errors.add('Remove legacy skill reference $fragment from $relative.');
      }
    }
  }
}

bool _isValidSemVer(String version) {
  return RegExp(
    r'^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)'
    r'(?:-(?:0|[1-9]\d*|\d*[A-Za-z-][0-9A-Za-z-]*)'
    r'(?:\.(?:0|[1-9]\d*|\d*[A-Za-z-][0-9A-Za-z-]*))*)?'
    r'(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?$',
  ).hasMatch(version);
}

List<String>? _stringList(
  Map<String, Object?> object,
  String field,
  String label,
) {
  final value = object[field];
  if (value is! List<Object?> ||
      value.isEmpty ||
      value.any((item) => item is! String || item.trim().isEmpty)) {
    _errors.add('$label $field must be a nonempty string array.');
    return null;
  }
  return value.cast<String>();
}

bool _sameStrings(List<String> left, List<String> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

void _validateOpenAiYaml(File file) {
  final lines = file.readAsLinesSync();
  final values = <String, String>{};
  var foundInterface = false;

  for (var index = 0; index < lines.length; index++) {
    final line = lines[index];
    if (line.trim().isEmpty || line.trimLeft().startsWith('#')) continue;

    if (!foundInterface) {
      if (line != 'interface:') {
        _errors.add('agents/openai.yaml must start with an interface mapping.');
        return;
      }
      foundInterface = true;
      continue;
    }

    if (!line.startsWith('  ') ||
        line.length == 2 ||
        line.codeUnitAt(2) == 0x20 ||
        line.contains('\t')) {
      _errors.add(
          'agents/openai.yaml has invalid indentation on line ${index + 1}.');
      continue;
    }
    final separator = line.indexOf(':', 2);
    if (separator == -1) {
      _errors
          .add('agents/openai.yaml has an invalid field on line ${index + 1}.');
      continue;
    }
    final key = line.substring(2, separator).trim();
    final rawValue = line.substring(separator + 1).trim();
    if (!RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(key) || rawValue.isEmpty) {
      _errors
          .add('agents/openai.yaml has an invalid field on line ${index + 1}.');
      continue;
    }
    if (values.containsKey(key)) {
      _errors.add('agents/openai.yaml repeats $key.');
      continue;
    }
    final value = _yamlString(rawValue, index + 1);
    if (value != null) values[key] = value;
  }

  if (!foundInterface) {
    _errors.add('agents/openai.yaml must contain an interface mapping.');
    return;
  }

  const expectedFields = {
    'display_name',
    'short_description',
    'default_prompt',
  };
  final missing = expectedFields.difference(values.keys.toSet());
  final unknown = values.keys.toSet().difference(expectedFields);
  if (missing.isNotEmpty) {
    _errors.add('agents/openai.yaml is missing: ${missing.join(', ')}.');
  }
  if (unknown.isNotEmpty) {
    _errors
        .add('agents/openai.yaml has unknown fields: ${unknown.join(', ')}.');
  }

  _expectEqual(values['display_name'], 'BlocSignal', 'skill display_name');
  final shortDescription = values['short_description'];
  if (shortDescription != null &&
      (shortDescription.length < 25 || shortDescription.length > 64)) {
    _errors.add('Skill short_description must contain 25 to 64 characters.');
  }
  final defaultPrompt = values['default_prompt'];
  if (defaultPrompt != null && !defaultPrompt.contains(r'$bloc-signals')) {
    _errors.add('Skill default_prompt must mention \$bloc-signals.');
  }
}

String? _yamlString(String rawValue, int lineNumber) {
  if (!rawValue.startsWith('"')) {
    _errors.add(
      'agents/openai.yaml values must use double-quoted strings '
      'on line $lineNumber.',
    );
    return null;
  }

  try {
    final decoded = jsonDecode(rawValue);
    if (decoded is String) return decoded;
  } on FormatException {
    // The shared error below gives the field's YAML line.
  }
  _errors.add('agents/openai.yaml has an invalid string on line $lineNumber.');
  return null;
}

Map<String, File> _relativeFiles(Directory directory) {
  final files = <String, File>{};
  for (final entity in directory.listSync(
    recursive: true,
    followLinks: false,
  )) {
    if (entity is! File || entity.path.endsWith('.DS_Store')) continue;
    final relative = entity.path.substring(directory.path.length + 1);
    files[relative] = entity;
  }
  return files;
}

bool _sameBytes(File first, File second) {
  final left = first.readAsBytesSync();
  final right = second.readAsBytesSync();
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

void _validatePortablePaths(Directory root) {
  final plugin = Directory('${root.path}/$_pluginPath');
  if (!plugin.existsSync()) {
    _errors.add('Missing $_pluginPath.');
    return;
  }
  final pluginLicense = File('${plugin.path}/LICENSE');
  final packageLicense = File('${root.path}/bloc_signals/LICENSE');
  if (!pluginLicense.existsSync()) {
    _errors.add('The plugin payload needs a LICENSE file.');
  } else if (!packageLicense.existsSync() ||
      !_sameBytes(pluginLicense, packageLicense)) {
    _errors.add('The plugin LICENSE must match bloc_signals/LICENSE.');
  }
  for (final entity in plugin.listSync(recursive: true, followLinks: false)) {
    if (entity is Link) {
      _errors.add('Plugin payload must not contain symlinks: ${entity.path}');
      continue;
    }
    if (entity is! File) continue;
    final text = entity.readAsStringSync();
    if (text.contains('/Users/') || text.contains(r'C:\Users\')) {
      _errors.add(
        'Plugin payload contains a machine-specific path: ${entity.path}',
      );
    }
    if (text.contains('../skills/') || text.contains('../../')) {
      _errors.add(
        'Plugin payload contains an external relative path: ${entity.path}',
      );
    }
  }
}

void _expectEqual(Object? actual, Object? expected, String label) {
  if (actual != expected) {
    _errors.add('$label must be $expected, found $actual.');
  }
}

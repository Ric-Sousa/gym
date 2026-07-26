import 'dart:async';
import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  final mode = args.isNotEmpty ? args[0] : 'clean';

  final input = await stdin.transform(utf8.decoder).join();

  final projectRoot = Directory.current.path.replaceAll('\\', '/');

  String pubCache;
  if (Platform.environment['PUB_CACHE'] != null) {
    pubCache = Platform.environment['PUB_CACHE']!;
  } else if (Platform.isWindows) {
    final localAppData = Platform.environment['LOCALAPPDATA'] ??
        '${Platform.environment['USERPROFILE']}\\AppData\\Local';
    pubCache = '$localAppData\\Pub\\Cache';
  } else {
    pubCache = '${Platform.environment['HOME']}/.pub-cache';
  }
  pubCache = pubCache.replaceAll('\\', '/');

  final flutterRoot = (Platform.environment['FLUTTER_ROOT'] ?? '').replaceAll('\\', '/');

  const phProjectRoot = '__PROJECT_ROOT__';
  const phPubCache = '__PUB_CACHE__';
  const phFlutterRoot = '__FLUTTER_ROOT__';

  String output;
  if (mode == 'clean') {
    output = input
        .replaceAll('file:///$projectRoot', phProjectRoot)
        .replaceAll('file:///$pubCache', phPubCache)
        .replaceAll(projectRoot, phProjectRoot);
    if (flutterRoot.isNotEmpty) {
      output = output.replaceAll('file:///$flutterRoot', phFlutterRoot);
    }
  } else {
    output = input
        .replaceAll(phProjectRoot, 'file:///$projectRoot')
        .replaceAll(phPubCache, 'file:///$pubCache')
        .replaceAll(phFlutterRoot, 'file:///$flutterRoot');
  }

  stdout.write(output);
}

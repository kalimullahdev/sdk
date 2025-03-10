// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';
import 'dart:typed_data';

import 'package:args/args.dart' as args;
import 'package:front_end/src/api_unstable/vm.dart'
    show printDiagnosticMessage, resolveInputUri;

import 'package:dart2wasm/compile.dart';
import 'package:dart2wasm/compiler_options.dart';
import 'package:dart2wasm/option.dart';

// Used to allow us to keep defaults on their respective option structs.
final CompilerOptions _d = CompilerOptions.defaultOptions();

final List<Option> options = [
  Flag("help", (o, _) {}, abbr: "h", negatable: false, defaultsTo: false),
  Flag("export-all", (o, value) => o.translatorOptions.exportAll = value,
      defaultsTo: _d.translatorOptions.exportAll),
  Flag("import-shared-memory",
      (o, value) => o.translatorOptions.importSharedMemory = value,
      defaultsTo: _d.translatorOptions.importSharedMemory),
  Flag("inlining", (o, value) => o.translatorOptions.inlining = value,
      defaultsTo: _d.translatorOptions.inlining),
  Flag(
      "lazy-constants", (o, value) => o.translatorOptions.lazyConstants = value,
      defaultsTo: _d.translatorOptions.lazyConstants),
  Flag("name-section", (o, value) => o.translatorOptions.nameSection = value,
      defaultsTo: _d.translatorOptions.nameSection),
  Flag("nominal-types", (o, value) => o.translatorOptions.nominalTypes = value,
      defaultsTo: _d.translatorOptions.nominalTypes),
  Flag("polymorphic-specialization",
      (o, value) => o.translatorOptions.polymorphicSpecialization = value,
      defaultsTo: _d.translatorOptions.polymorphicSpecialization),
  Flag("print-kernel", (o, value) => o.translatorOptions.printKernel = value,
      defaultsTo: _d.translatorOptions.printKernel),
  Flag("print-wasm", (o, value) => o.translatorOptions.printWasm = value,
      defaultsTo: _d.translatorOptions.printWasm),
  Flag("runtime-types", (o, value) => o.translatorOptions.runtimeTypes = value,
      defaultsTo: _d.translatorOptions.runtimeTypes),
  Flag("string-data-segments",
      (o, value) => o.translatorOptions.stringDataSegments = value,
      defaultsTo: _d.translatorOptions.stringDataSegments),
  IntOption(
      "inlining-limit", (o, value) => o.translatorOptions.inliningLimit = value,
      defaultsTo: "${_d.translatorOptions.inliningLimit}"),
  IntOption("shared-memory-max-pages",
      (o, value) => o.translatorOptions.sharedMemoryMaxPages = value),
  UriOption("dart-sdk", (o, value) => o.sdkPath = value,
      defaultsTo: "${_d.sdkPath}"),
  UriOption("packages", (o, value) => o.packagesPath = value),
  UriOption("libraries-spec", (o, value) => o.librariesSpecPath = value),
  UriOption("platform", (o, value) => o.platformPath = value),
  IntMultiOption(
      "watch", (o, values) => o.translatorOptions.watchPoints = values),
  StringMultiOption(
      "define", (o, values) => o.environment = processEnvironment(values),
      abbr: "D")
];

Map<String, String> processEnvironment(List<String> defines) =>
    Map<String, String>.fromEntries(defines.map((d) {
      List<String> keyAndValue = d.split('=');
      if (keyAndValue.length != 2) {
        throw ArgumentError('Bad define string: $d');
      }
      return MapEntry<String, String>(keyAndValue[0], keyAndValue[1]);
    }));

CompilerOptions parseArguments(List<String> arguments) {
  args.ArgParser parser = args.ArgParser();
  for (Option arg in options) {
    arg.applyToParser(parser);
  }

  Never usage() {
    print("Usage: dart2wasm [<options>] <infile.dart> <outfile.wasm>");
    print("");
    print("*NOTE*: Wasm compilation is experimental.");
    print("The support may change, or be removed, with no advance notice.");
    print("");
    print("Options:");
    for (String line in parser.usage.split('\n')) {
      print('\t$line');
    }
    exit(64);
  }

  try {
    args.ArgResults results = parser.parse(arguments);
    if (results['help']) {
      usage();
    }
    List<String> rest = results.rest;
    if (rest.length != 2) {
      throw ArgumentError('Requires two positional file arguments');
    }
    CompilerOptions compilerOptions =
        CompilerOptions(mainUri: resolveInputUri(rest[0]), outputFile: rest[1]);
    for (Option arg in options) {
      if (results.wasParsed(arg.name)) {
        arg.applyToOptions(compilerOptions, results[arg.name]);
      }
    }
    return compilerOptions;
  } catch (e, s) {
    print(s);
    print('Argument Error: ' + e.toString());
    usage();
  }
}

Future<int> main(List<String> args) async {
  CompilerOptions options = parseArguments(args);
  Uint8List? module = await compileToModule(
      options, (message) => printDiagnosticMessage(message, print));

  if (module == null) {
    exitCode = 1;
    return exitCode;
  }

  await File(options.outputFile).writeAsBytes(module);

  return 0;
}

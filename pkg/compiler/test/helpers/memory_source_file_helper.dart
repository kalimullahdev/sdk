// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// @dart = 2.7

library dart2js.test.memory_source_file_helper;

import 'dart:async' show Future;
export 'dart:io' show Platform;

import 'package:compiler/compiler_api.dart' as api;

import 'package:compiler/src/io/source_file.dart'
    show Binary, StringSourceFile, Utf8BytesSourceFile;

import 'package:compiler/src/source_file_provider.dart' show SourceFileProvider;

export 'package:compiler/src/source_file_provider.dart'
    show SourceFileProvider, FormattingDiagnosticHandler;

class MemorySourceFileProvider extends SourceFileProvider {
  Map<String, dynamic> memorySourceFiles;

  /// MemorySourceFiles can contain maps of file names to string contents or
  /// file names to binary contents.
  MemorySourceFileProvider(Map<String, dynamic> this.memorySourceFiles);

  @override
  Future<api.Input<List<int>>> readBytesFromUri(
      Uri resourceUri, api.InputKind inputKind) {
    if (!resourceUri.isScheme('memory')) {
      return super.readBytesFromUri(resourceUri, inputKind);
    }
    // TODO(johnniwinther): We should use inputs already in the cache. Some
    // tests currently require that we always create a fresh input.

    var source = memorySourceFiles[resourceUri.path];
    if (source == null) {
      return Future.error(new Exception(
          'No such memory file $resourceUri in ${memorySourceFiles.keys}'));
    }
    api.Input<List<int>> input;
    StringSourceFile stringFile;
    if (source is String) {
      stringFile = new StringSourceFile.fromUri(resourceUri, source);
    }
    switch (inputKind) {
      case api.InputKind.UTF8:
        input = stringFile ?? new Utf8BytesSourceFile(resourceUri, source);
        utf8SourceFiles[resourceUri] = input;
        break;
      case api.InputKind.binary:
        if (stringFile != null) {
          utf8SourceFiles[resourceUri] = stringFile;
          source = stringFile.data;
        }
        input =
            binarySourceFiles[resourceUri] = new Binary(resourceUri, source);
        break;
    }
    return new Future.value(input);
  }

  @override
  Future<api.Input> readFromUri(Uri resourceUri,
          {api.InputKind inputKind: api.InputKind.UTF8}) =>
      readBytesFromUri(resourceUri, inputKind);
}

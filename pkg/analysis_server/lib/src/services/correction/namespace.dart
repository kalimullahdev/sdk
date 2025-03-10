// Copyright (c) 2014, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/src/dart/resolver/scope.dart';

/// Returns the [Element] exported from the given [LibraryElement].
Element? getExportedElement(LibraryElement? library, String name) {
  if (library == null) {
    return null;
  }
  return _getExportNamespaceForLibrary(library)[name];
}

/// Return the [LibraryImportElement] that is referenced by [prefixNode], or `null` if
/// the node does not reference a prefix or if we cannot determine which import
/// is being referenced.
LibraryImportElement? getImportElement(SimpleIdentifier prefixNode) {
  var parent = prefixNode.parent;
  if (parent is ImportDirective) {
    return parent.element2;
  }
  return _getImportElementInfo(prefixNode);
}

/// Returns the export namespace of the given [LibraryElement].
Map<String, Element> _getExportNamespaceForLibrary(LibraryElement library) {
  var namespace = NamespaceBuilder().createExportNamespaceForLibrary(library);
  return namespace.definedNames;
}

/// Return the [LibraryImportElement] that declared [prefix] and imports [element].
///
/// [libraryElement] - the [LibraryElement] where reference is.
/// [prefix] - the import prefix, maybe `null`.
/// [element] - the referenced element.
/// [importElementsMap] - the cache of [Element]s imported by [LibraryImportElement]s.
LibraryImportElement? _getImportElement(
    LibraryElement libraryElement,
    String prefix,
    Element element,
    Map<LibraryImportElement, Set<Element>> importElementsMap) {
  if (element.enclosingElement2 is! CompilationUnitElement) {
    return null;
  }
  var usedLibrary = element.library;
  // find ImportElement that imports used library with used prefix
  List<LibraryImportElement>? candidates;
  for (var importElement in libraryElement.libraryImports) {
    // required library
    if (importElement.importedLibrary != usedLibrary) {
      continue;
    }
    // required prefix
    var prefixElement = importElement.prefix?.element;
    if (prefixElement == null) {
      continue;
    }
    if (prefix != prefixElement.name) {
      continue;
    }
    // no combinators => only possible candidate
    if (importElement.combinators.isEmpty) {
      return importElement;
    }
    // OK, we have candidate
    candidates ??= [];
    candidates.add(importElement);
  }
  // no candidates, probably element is defined in this library
  if (candidates == null) {
    return null;
  }
  // one candidate
  if (candidates.length == 1) {
    return candidates[0];
  }
  // ensure that each ImportElement has set of elements
  for (var importElement in candidates) {
    if (importElementsMap.containsKey(importElement)) {
      continue;
    }
    var namespace = importElement.namespace;
    var elements = Set<Element>.from(namespace.definedNames.values);
    importElementsMap[importElement] = elements;
  }
  // use import namespace to choose correct one
  for (var entry in importElementsMap.entries) {
    var importElement = entry.key;
    var elements = entry.value;
    if (elements.contains(element)) {
      return importElement;
    }
  }
  // not found
  return null;
}

/// Returns the [LibraryImportElement] that is referenced by [prefixNode] with a
/// [PrefixElement], maybe `null`.
LibraryImportElement? _getImportElementInfo(SimpleIdentifier prefixNode) {
  // prepare environment
  var parent = prefixNode.parent;
  var unit = prefixNode.thisOrAncestorOfType<CompilationUnit>();
  var libraryElement = unit?.declaredElement?.library;
  if (libraryElement == null) {
    return null;
  }
  // prepare used element
  Element? usedElement;
  if (parent is PrefixedIdentifier) {
    var prefixed = parent;
    if (prefixed.prefix == prefixNode) {
      usedElement = prefixed.staticElement;
    }
  } else if (parent is MethodInvocation) {
    var invocation = parent;
    if (invocation.target == prefixNode) {
      usedElement = invocation.methodName.staticElement;
    }
  }
  // we need used Element
  if (usedElement == null) {
    return null;
  }
  // find ImportElement
  var prefix = prefixNode.name;
  var importElementsMap = <LibraryImportElement, Set<Element>>{};
  return _getImportElement(
      libraryElement, prefix, usedElement, importElementsMap);
}

// Copyright (c) 2017, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

/// A visitor that visits an [AstNode] and its parent recursively along with any
/// declarations in those nodes. Consumers typically call [visit] which catches
/// the exception thrown by [finished].
abstract class LocalDeclarationVisitor extends GeneralizingAstVisitor {
  final int offset;

  LocalDeclarationVisitor(this.offset);

  void declaredClass(ClassDeclaration declaration) {}

  void declaredClassTypeAlias(ClassTypeAlias declaration) {}

  void declaredConstructor(ConstructorDeclaration declaration) {}

  void declaredEnum(EnumDeclaration declaration) {}

  void declaredExtension(ExtensionDeclaration declaration) {}

  void declaredField(FieldDeclaration fieldDecl, VariableDeclaration varDecl) {}

  void declaredFunction(FunctionDeclaration declaration) {}

  void declaredFunctionTypeAlias(FunctionTypeAlias declaration) {}

  void declaredGenericTypeAlias(GenericTypeAlias declaration) {}

  void declaredLabel(Label label, bool isCaseLabel) {}

  void declaredLocalVar(SimpleIdentifier name, TypeAnnotation? type) {}

  void declaredMethod(MethodDeclaration declaration) {}

  void declaredMixin(MixinDeclaration declaration) {}

  void declaredParam(SimpleIdentifier name, TypeAnnotation? type) {}

  void declaredTopLevelVar(
      VariableDeclarationList varList, VariableDeclaration varDecl) {}

  void declaredTypeParameter(TypeParameter declaration) {}

  /// Throw an exception indicating that [LocalDeclarationVisitor] should
  /// stop visiting. This is caught in [visit] which then exits normally.
  void finished() {
    throw _LocalDeclarationVisitorFinished();
  }

  /// Visit the given [AstNode] and its parent recursively along with any
  /// declarations in those nodes. Return `true` if [finished] is called
  /// while visiting, else `false`.
  bool visit(AstNode node) {
    try {
      node.accept(this);
      return false;
    } on _LocalDeclarationVisitorFinished {
      return true;
    }
  }

  @override
  void visitBlock(Block node) {
    _visitStatements(node.statements);
    visitNode(node);
  }

  @override
  void visitCatchClause(CatchClause node) {
    var exceptionParameter = node.exceptionParameter;
    if (exceptionParameter != null) {
      declaredParam(exceptionParameter, node.exceptionType);
    }

    var stackTraceParameter = node.stackTraceParameter;
    if (stackTraceParameter != null) {
      declaredParam(stackTraceParameter, null);
    }

    visitNode(node);
  }

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    _visitClassOrMixinMembers(node.members);
    visitNode(node);
  }

  @override
  void visitCompilationUnit(CompilationUnit node) {
    _visitCompilationUnit(node);
  }

  @override
  void visitConstructorDeclaration(ConstructorDeclaration node) {
    _visitParamList(node.parameters);
    visitNode(node);
  }

  @override
  void visitExtensionDeclaration(ExtensionDeclaration node) {
    _visitClassOrMixinMembers(node.members);
    visitNode(node);
  }

  @override
  void visitForElement(ForElement node) {
    var forLoopParts = node.forLoopParts;
    if (forLoopParts is ForEachPartsWithDeclaration) {
      var loopVariable = forLoopParts.loopVariable;
      declaredLocalVar(loopVariable.identifier, loopVariable.type);
    } else if (forLoopParts is ForPartsWithDeclarations) {
      var varList = forLoopParts.variables;
      for (var varDecl in varList.variables) {
        declaredLocalVar(varDecl.name, varList.type);
      }
    }
    visitNode(node);
  }

  @override
  void visitForStatement(ForStatement node) {
    var forLoopParts = node.forLoopParts;
    if (forLoopParts is ForEachPartsWithDeclaration) {
      var loopVariable = forLoopParts.loopVariable;
      declaredLocalVar(loopVariable.identifier, loopVariable.type);
    } else if (forLoopParts is ForPartsWithDeclarations) {
      var varList = forLoopParts.variables;
      for (var varDecl in varList.variables) {
        declaredLocalVar(varDecl.name, varList.type);
      }
    }
    visitNode(node);
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    // declaredFunction is called by the compilation unit containing it
    visitNode(node);
  }

  @override
  void visitFunctionExpression(FunctionExpression node) {
    _visitTypeParameters(node, node.typeParameters);
    _visitParamList(node.parameters);
    visitNode(node);
  }

  @override
  void visitGenericFunctionType(GenericFunctionType node) {
    _visitTypeParameters(node, node.typeParameters);
    visitNode(node);
  }

  @override
  void visitInterpolationExpression(InterpolationExpression node) {
    visitNode(node);
  }

  @override
  void visitLabeledStatement(LabeledStatement node) {
    for (var label in node.labels) {
      declaredLabel(label, false);
    }
    visitNode(node);
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    _visitTypeParameters(node, node.typeParameters);
    _visitParamList(node.parameters);
    visitNode(node);
  }

  @override
  void visitMixinDeclaration(MixinDeclaration node) {
    _visitClassOrMixinMembers(node.members);
    visitNode(node);
  }

  @override
  void visitNode(AstNode node) {
    // Support the case of searching partial ASTs by aborting on nodes with no
    // parents. This is useful for the angular plugin.
    node.parent?.accept(this);
  }

  @override
  void visitStringInterpolation(StringInterpolation node) {
    visitNode(node);
  }

  @override
  void visitSwitchMember(SwitchMember node) {
    _visitStatements(node.statements);
    visitNode(node);
  }

  @override
  void visitSwitchStatement(SwitchStatement node) {
    for (var member in node.members) {
      for (var label in member.labels) {
        declaredLabel(label, true);
      }
    }
    visitNode(node);
  }

  void _visitClassOrMixinMembers(List<ClassMember> members) {
    for (var member in members) {
      if (member is FieldDeclaration) {
        for (var varDecl in member.fields.variables) {
          declaredField(member, varDecl);
        }
      } else if (member is MethodDeclaration) {
        declaredMethod(member);
        _visitTypeParameters(member, member.typeParameters);
      }
    }
  }

  void _visitCompilationUnit(CompilationUnit node) {
    for (var declaration in node.declarations) {
      if (declaration is ClassDeclaration) {
        declaredClass(declaration);
        _visitTypeParameters(declaration, declaration.typeParameters);
        // Call declaredConstructor all ConstructorDeclarations when the class
        // is called: constructors are accessible if the class is accessible.
        for (var classDeclaration
            in node.declarations.whereType<ClassDeclaration>()) {
          for (var constructor
              in classDeclaration.members.whereType<ConstructorDeclaration>()) {
            declaredConstructor(constructor);
          }
        }
      } else if (declaration is EnumDeclaration) {
        declaredEnum(declaration);
      } else if (declaration is ExtensionDeclaration) {
        declaredExtension(declaration);
        _visitTypeParameters(declaration, declaration.typeParameters);
      } else if (declaration is FunctionDeclaration) {
        declaredFunction(declaration);
        _visitTypeParameters(
          declaration,
          declaration.functionExpression.typeParameters,
        );
      } else if (declaration is TopLevelVariableDeclaration) {
        var varList = declaration.variables;
        for (var varDecl in varList.variables) {
          declaredTopLevelVar(varList, varDecl);
        }
      } else if (declaration is ClassTypeAlias) {
        declaredClassTypeAlias(declaration);
        _visitTypeParameters(declaration, declaration.typeParameters);
      } else if (declaration is FunctionTypeAlias) {
        declaredFunctionTypeAlias(declaration);
        _visitTypeParameters(declaration, declaration.typeParameters);
      } else if (declaration is GenericTypeAlias) {
        declaredGenericTypeAlias(declaration);
        _visitTypeParameters(declaration, declaration.typeParameters);

        var type = declaration.type;
        if (type is GenericFunctionType) {
          _visitTypeParameters(type, type.typeParameters);
        }
      } else if (declaration is MixinDeclaration) {
        declaredMixin(declaration);
        _visitTypeParameters(declaration, declaration.typeParameters);
      }
    }
  }

  void _visitParamList(FormalParameterList? paramList) {
    if (paramList != null) {
      for (var param in paramList.parameters) {
        NormalFormalParameter? normalParam;
        if (param is DefaultFormalParameter) {
          normalParam = param.parameter;
        } else if (param is NormalFormalParameter) {
          normalParam = param;
        }
        TypeAnnotation? type;
        if (normalParam is FieldFormalParameter) {
          type = normalParam.type;
        } else if (normalParam is FunctionTypedFormalParameter) {
          type = normalParam.returnType;
        } else if (normalParam is SimpleFormalParameter) {
          type = normalParam.type;
        }
        var name = param.identifier;
        declaredParam(name!, type);
      }
    }
  }

  void _visitStatements(NodeList<Statement> statements) {
    for (var stmt in statements) {
      if (stmt.offset < offset) {
        if (stmt is VariableDeclarationStatement) {
          var varList = stmt.variables;
          for (var varDecl in varList.variables) {
            if (varDecl.end < offset) {
              declaredLocalVar(varDecl.name, varList.type);
            }
          }
        } else if (stmt is FunctionDeclarationStatement) {
          var declaration = stmt.functionDeclaration;
          if (declaration.offset < offset) {
            var name = declaration.name.name;
            if (name.isNotEmpty) {
              declaredFunction(declaration);
              _visitTypeParameters(
                declaration,
                declaration.functionExpression.typeParameters,
              );
            }
          }
        }
      }
    }
  }

  void _visitTypeParameters(AstNode node, TypeParameterList? typeParameters) {
    if (typeParameters == null) return;

    if (node.offset < offset && offset < node.end) {
      for (var typeParameter in typeParameters.typeParameters) {
        declaredTypeParameter(typeParameter);
      }
    }
  }
}

/// Internal exception used to indicate that [LocalDeclarationVisitor]
/// should stop visiting.
class _LocalDeclarationVisitorFinished {}

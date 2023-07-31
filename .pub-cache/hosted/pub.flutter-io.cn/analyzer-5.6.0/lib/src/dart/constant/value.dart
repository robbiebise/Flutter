// Copyright (c) 2014, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// The implementation of the class [DartObject].
import 'dart:collection';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/dart/element/type_provider.dart';
import 'package:analyzer/error/error.dart';
import 'package:analyzer/src/dart/constant/has_type_parameter_reference.dart';
import 'package:analyzer/src/dart/element/extensions.dart';
import 'package:analyzer/src/dart/element/type_system.dart';
import 'package:analyzer/src/error/codes.dart';
import 'package:meta/meta.dart';

/// The state of an object representing a boolean value.
class BoolState extends InstanceState {
  /// An instance representing the boolean value 'false'.
  static BoolState FALSE_STATE = BoolState(false);

  /// An instance representing the boolean value 'true'.
  static BoolState TRUE_STATE = BoolState(true);

  /// A state that can be used to represent a boolean whose value is not known.
  static BoolState UNKNOWN_VALUE = BoolState(null);

  /// The value of this instance.
  final bool? value;

  /// Initialize a newly created state to represent the given [value].
  BoolState(this.value);

  @override
  int get hashCode => value == null ? 0 : (value! ? 2 : 3);

  @override
  bool get isBool => true;

  @override
  bool get isBoolNumStringOrNull => true;

  @override
  bool get isUnknown => value == null;

  @override
  String get typeName => "bool";

  @override
  bool operator ==(Object other) =>
      other is BoolState && identical(value, other.value);

  @override
  BoolState convertToBool() => this;

  @override
  StringState convertToString() {
    if (value == null) {
      return StringState.UNKNOWN_VALUE;
    }
    return StringState(value! ? "true" : "false");
  }

  @override
  BoolState equalEqual(TypeSystemImpl typeSystem, InstanceState rightOperand) {
    assertBoolNumStringOrNull(rightOperand);
    return isIdentical(typeSystem, rightOperand);
  }

  @override
  bool hasPrimitiveEquality(FeatureSet featureSet) => true;

  @override
  BoolState isIdentical(TypeSystemImpl typeSystem, InstanceState rightOperand) {
    if (value == null) {
      return UNKNOWN_VALUE;
    }
    if (rightOperand is BoolState) {
      var rightValue = rightOperand.value;
      if (rightValue == null) {
        return UNKNOWN_VALUE;
      }
      return BoolState.from(identical(value, rightValue));
    }
    return FALSE_STATE;
  }

  @override
  BoolState lazyAnd(InstanceState? Function() rightOperandComputer) {
    if (value == false) {
      return FALSE_STATE;
    }
    var rightOperand = rightOperandComputer();
    assertBool(rightOperand);
    return value == null ? UNKNOWN_VALUE : rightOperand!.convertToBool();
  }

  @override
  BoolState lazyOr(InstanceState? Function() rightOperandComputer) {
    if (value == true) {
      return TRUE_STATE;
    }
    var rightOperand = rightOperandComputer();
    assertBool(rightOperand);
    return value == null ? UNKNOWN_VALUE : rightOperand!.convertToBool();
  }

  @override
  BoolState logicalNot() {
    if (value == null) {
      return UNKNOWN_VALUE;
    }
    return value! ? FALSE_STATE : TRUE_STATE;
  }

  @override
  String toString() =>
      value == null ? "-unknown-" : (value! ? "true" : "false");

  /// Return the boolean state representing the given boolean [value].
  static BoolState from(bool value) =>
      value ? BoolState.TRUE_STATE : BoolState.FALSE_STATE;
}

/// Information about a const constructor invocation.
class ConstructorInvocation {
  /// The constructor that was called.
  final ConstructorElement constructor;

  /// Values of specified arguments, actual values for positional, and `null`
  /// for named (which are provided as [namedArguments]).
  final List<DartObjectImpl?> _argumentValues;

  /// The named arguments passed to the constructor.
  final Map<String, DartObjectImpl> namedArguments;

  ConstructorInvocation(
      this.constructor, this._argumentValues, this.namedArguments);

  /// The positional arguments passed to the constructor.
  List<DartObjectImpl> get positionalArguments {
    var result = <DartObjectImpl>[];
    for (var argument in _argumentValues) {
      if (argument != null) {
        result.add(argument);
      } else {
        break;
      }
    }
    return result;
  }
}

/// A representation of an instance of a Dart class.
class DartObjectImpl implements DartObject {
  final TypeSystemImpl _typeSystem;

  @override
  final DartType type;

  /// The state of the object.
  final InstanceState state;

  @override
  final VariableElement? variable;

  /// Initialize a newly created object to have the given [type] and [state].
  DartObjectImpl(this._typeSystem, this.type, this.state, {this.variable});

  /// Creates a duplicate instance of [other], tied to [variable].
  factory DartObjectImpl.forVariable(
      DartObjectImpl other, VariableElement variable) {
    return DartObjectImpl(other._typeSystem, other.type, other.state,
        variable: variable);
  }

  /// Create an object to represent an unknown value.
  factory DartObjectImpl.validWithUnknownValue(
    TypeSystemImpl typeSystem,
    DartType type,
  ) {
    if (type.isDartCoreBool) {
      return DartObjectImpl(typeSystem, type, BoolState.UNKNOWN_VALUE);
    } else if (type.isDartCoreDouble) {
      return DartObjectImpl(typeSystem, type, DoubleState.UNKNOWN_VALUE);
    } else if (type.isDartCoreInt) {
      return DartObjectImpl(typeSystem, type, IntState.UNKNOWN_VALUE);
    } else if (type.isDartCoreString) {
      return DartObjectImpl(typeSystem, type, StringState.UNKNOWN_VALUE);
    }
    return DartObjectImpl(
      typeSystem,
      type,
      GenericState(type, {}, isUnknown: true),
    );
  }

  Map<String, DartObjectImpl>? get fields => state.fields;

  @override
  int get hashCode => Object.hash(type, state);

  @override
  bool get hasKnownValue => !state.isUnknown;

  /// Return `true` if this object represents an object whose type is 'bool'.
  bool get isBool => state.isBool;

  /// Return `true` if this object represents an object whose type is either
  /// 'bool', 'num', 'String', or 'Null'.
  bool get isBoolNumStringOrNull => state.isBoolNumStringOrNull;

  /// Return `true` if this object represents an object whose type is 'int'.
  bool get isInt => state.isInt;

  @override
  bool get isNull => state is NullState;

  /// Return `true` if this object represents an unknown value.
  bool get isUnknown => state.isUnknown;

  /// Return `true` if this object represents an instance of a user-defined
  /// class.
  bool get isUserDefinedObject => state is GenericState;

  @visibleForTesting
  List<DartType>? get typeArguments => (state as FunctionState)._typeArguments;

  @override
  bool operator ==(Object other) {
    if (other is DartObjectImpl) {
      return _typeSystem.runtimeTypesEqual(type, other.type) &&
          state == other.state;
    }
    return false;
  }

  /// Return the result of invoking the '+' operator on this object with the
  /// given [rightOperand].
  ///
  /// Throws an [EvaluationException] if the operator is not appropriate for an
  /// object of this kind.
  DartObjectImpl add(TypeSystemImpl typeSystem, DartObjectImpl rightOperand) {
    InstanceState result = state.add(rightOperand.state);
    if (result is IntState) {
      return DartObjectImpl(
        typeSystem,
        typeSystem.typeProvider.intType,
        result,
      );
    } else if (result is DoubleState) {
      return DartObjectImpl(
        typeSystem,
        typeSystem.typeProvider.doubleType,
        result,
      );
    } else if (result is StringState) {
      return DartObjectImpl(
        typeSystem,
        typeSystem.typeProvider.stringType,
        result,
      );
    }
    // We should never get here.
    throw StateError("add returned a ${result.runtimeType}");
  }

  /// Return the result of invoking the '~' operator on this object.
  ///
  /// Throws an [EvaluationException] if the operator is not appropriate for an
  /// object of this kind.
  DartObjectImpl bitNot(TypeSystemImpl typeSystem) {
    return DartObjectImpl(
      typeSystem,
      typeSystem.typeProvider.intType,
      state.bitNot(),
    );
  }

  /// Return the result of casting this object to the given [castType].
  DartObjectImpl castToType(
      TypeSystemImpl typeSystem, DartObjectImpl castType) {
    _assertType(castType);
    var resultType = (castType.state as TypeState)._type;

    // If we don't know the type, we cannot prove that the cast will fail.
    if (resultType == null) {
      return this;
    }

    // We don't know the actual value of a type parameter.
    // So, the object type might be a subtype of the result type.
    if (hasTypeParameterReference(resultType)) {
      return this;
    }

    if (!typeSystem.isSubtypeOf(type, resultType)) {
      throw EvaluationException(
          CompileTimeErrorCode.CONST_EVAL_THROWS_EXCEPTION);
    }
    return this;
  }

  /// Return the result of invoking the ' ' operator on this object with the
  /// [rightOperand].
  ///
  /// Throws an [EvaluationException] if the operator is not appropriate for an
  /// object of this kind.
  DartObjectImpl concatenate(
      TypeSystemImpl typeSystem, DartObjectImpl rightOperand) {
    return DartObjectImpl(
      typeSystem,
      typeSystem.typeProvider.stringType,
      state.concatenate(rightOperand.state),
    );
  }

  /// Return the result of applying boolean conversion to this object.
  ///
  /// Throws an [EvaluationException] if the operator is not appropriate for an
  /// object of this kind.
  DartObjectImpl convertToBool(TypeSystemImpl typeSystem) {
    InterfaceType boolType = typeSystem.typeProvider.boolType;
    if (identical(type, boolType)) {
      return this;
    }
    return DartObjectImpl(typeSystem, boolType, state.convertToBool());
  }

  /// Return the result of invoking the '/' operator on this object with the
  /// [rightOperand].
  ///
  /// Throws an [EvaluationException] if the operator is not appropriate for
  /// an object of this kind.
  DartObjectImpl divide(
      TypeSystemImpl typeSystem, DartObjectImpl rightOperand) {
    InstanceState result = state.divide(rightOperand.state);
    if (result is IntState) {
      return DartObjectImpl(
        typeSystem,
        typeSystem.typeProvider.intType,
        result,
      );
    } else if (result is DoubleState) {
      return DartObjectImpl(
        typeSystem,
        typeSystem.typeProvider.doubleType,
        result,
      );
    }
    // We should never get here.
    throw StateError("divide returned a ${result.runtimeType}");
  }

  /// Return the result of invoking the '&' operator on this object with the
  /// [rightOperand].
  ///
  /// Throws an [EvaluationException] if the operator is not appropriate for an
  /// object of this kind.
  DartObjectImpl eagerAnd(
      TypeSystemImpl typeSystem, DartObjectImpl rightOperand) {
    if (isBool && rightOperand.isBool) {
      return DartObjectImpl(
        typeSystem,
        typeSystem.typeProvider.boolType,
        state.logicalAnd(rightOperand.state),
      );
    } else if (isInt && rightOperand.isInt) {
      return DartObjectImpl(
        typeSystem,
        typeSystem.typeProvider.intType,
        state.bitAnd(rightOperand.state),
      );
    }
    throw EvaluationException(CompileTimeErrorCode.CONST_EVAL_TYPE_BOOL_INT);
  }

  /// Return the result of invoking the '|' operator on this object with the
  /// [rightOperand].
  ///
  /// Throws an [EvaluationException] if the operator is not appropriate for an
  /// object of this kind.
  DartObjectImpl eagerOr(
      TypeSystemImpl typeSystem, DartObjectImpl rightOperand) {
    if (isBool && rightOperand.isBool) {
      return DartObjectImpl(
        typeSystem,
        typeSystem.typeProvider.boolType,
        state.logicalOr(rightOperand.state),
      );
    } else if (isInt && rightOperand.isInt) {
      return DartObjectImpl(
        typeSystem,
        typeSystem.typeProvider.intType,
        state.bitOr(rightOperand.state),
      );
    }
    throw EvaluationException(CompileTimeErrorCode.CONST_EVAL_TYPE_BOOL_INT);
  }

  /// Return the result of invoking the '^' operator on this object with the
  /// [rightOperand].
  ///
  /// Throws an [EvaluationException] if the operator is not appropriate for an
  /// object of this kind.
  DartObjectImpl eagerXor(
      TypeSystemImpl typeSystem, DartObjectImpl rightOperand) {
    if (isBool && rightOperand.isBool) {
      return DartObjectImpl(
        typeSystem,
        typeSystem.typeProvider.boolType,
        state.logicalXor(rightOperand.state),
      );
    } else if (isInt && rightOperand.isInt) {
      return DartObjectImpl(
        typeSystem,
        typeSystem.typeProvider.intType,
        state.bitXor(rightOperand.state),
      );
    }
    throw EvaluationException(CompileTimeErrorCode.CONST_EVAL_TYPE_BOOL_INT);
  }

  /// Return the result of invoking the '==' operator on this object with the
  /// [rightOperand].
  ///
  /// Throws an [EvaluationException] if the operator is not appropriate for an
  /// object of this kind.
  DartObjectImpl equalEqual(
      TypeSystemImpl typeSystem, DartObjectImpl rightOperand) {
    if (isNull || rightOperand.isNull) {
      return DartObjectImpl(
        typeSystem,
        typeSystem.typeProvider.boolType,
        isNull && rightOperand.isNull
            ? BoolState.TRUE_STATE
            : BoolState.FALSE_STATE,
      );
    }
    if (isBoolNumStringOrNull) {
      return DartObjectImpl(
        typeSystem,
        typeSystem.typeProvider.boolType,
        state.equalEqual(typeSystem, rightOperand.state),
      );
    }
    throw EvaluationException(
        CompileTimeErrorCode.CONST_EVAL_TYPE_BOOL_NUM_STRING);
  }

  @override
  DartObject? getField(String name) {
    final state = this.state;
    if (state is GenericState) {
      return state.fields[name];
    } else if (state is RecordState) {
      return state.getField(name);
    }
    return null;
  }

  /// Gets the constructor that was called to create this value, if this is a
  /// const constructor invocation. Otherwise returns null.
  ConstructorInvocation? getInvocation() {
    final state = this.state;
    if (state is GenericState) {
      return state.invocation;
    }
    return null;
  }

  /// Return the result of invoking the '&gt;' operator on this object with the
  /// [rightOperand].
  ///
  /// Throws an [EvaluationException] if the operator is not appropriate for an
  /// object of this kind.
  DartObjectImpl greaterThan(
      TypeSystemImpl typeSystem, DartObjectImpl rightOperand) {
    return DartObjectImpl(
      typeSystem,
      typeSystem.typeProvider.boolType,
      state.greaterThan(rightOperand.state),
    );
  }

  /// Return the result of invoking the '&gt;=' operator on this object with the
  /// [rightOperand].
  ///
  /// Throws an [EvaluationException] if the operator is not appropriate for an
  /// object of this kind.
  DartObjectImpl greaterThanOrEqual(
      TypeSystemImpl typeSystem, DartObjectImpl rightOperand) {
    return DartObjectImpl(
      typeSystem,
      typeSystem.typeProvider.boolType,
      state.greaterThanOrEqual(rightOperand.state),
    );
  }

  /// Returns `true` if this value, inside a library with the [featureSet],
  /// has primitive equality, so can be used at compile-time.
  bool hasPrimitiveEquality(FeatureSet featureSet) {
    return state.hasPrimitiveEquality(featureSet);
  }

  /// Return the result of testing whether this object has the given
  /// [testedType].
  DartObjectImpl hasType(TypeSystemImpl typeSystem, DartObjectImpl testedType) {
    _assertType(testedType);
    var typeType = (testedType.state as TypeState)._type;
    BoolState state;
    if (typeType == null) {
      state = BoolState.TRUE_STATE;
    } else {
      state = BoolState.from(typeSystem.isSubtypeOf(type, typeType));
    }
    return DartObjectImpl(typeSystem, typeSystem.typeProvider.boolType, state);
  }

  /// Return the result of invoking the '~/' operator on this object with the
  /// [rightOperand].
  ///
  /// Throws an [EvaluationException] if the operator is not appropriate for an
  /// object of this kind.
  DartObjectImpl integerDivide(
      TypeSystemImpl typeSystem, DartObjectImpl rightOperand) {
    return DartObjectImpl(
      typeSystem,
      typeSystem.typeProvider.intType,
      state.integerDivide(rightOperand.state),
    );
  }

  /// Return the result of invoking the identical function on this object with
  /// the [rightOperand]. The [typeProvider] is the type provider used to find
  /// known types.
  @Deprecated('Use isIdentical2() instead')
  DartObjectImpl isIdentical(
      TypeProvider typeProvider, DartObjectImpl rightOperand) {
    var typeSystem = TypeSystemImpl(
      implicitCasts: false,
      isNonNullableByDefault: false,
      strictCasts: false,
      strictInference: false,
      typeProvider: typeProvider,
    );
    return isIdentical2(typeSystem, rightOperand);
  }

  /// Return the result of invoking the identical function on this object with
  /// the [rightOperand].
  DartObjectImpl isIdentical2(
      TypeSystemImpl typeSystem, DartObjectImpl rightOperand) {
    // Workaround for Flutter `const kIsWeb = identical(0, 0.0)`.
    if (type.isDartCoreInt && rightOperand.type.isDartCoreDouble ||
        type.isDartCoreDouble && rightOperand.type.isDartCoreInt) {
      return DartObjectImpl(
        typeSystem,
        typeSystem.typeProvider.boolType,
        BoolState.UNKNOWN_VALUE,
      );
    }

    if (!_typeSystem.runtimeTypesEqual(type, rightOperand.type)) {
      return DartObjectImpl(
        typeSystem,
        typeSystem.typeProvider.boolType,
        BoolState(false),
      );
    }

    return DartObjectImpl(
      typeSystem,
      typeSystem.typeProvider.boolType,
      state.isIdentical(typeSystem, rightOperand.state),
    );
  }

  /// Return the result of invoking the '&&' operator on this object with the
  /// [rightOperand].
  ///
  /// Throws an [EvaluationException] if the operator is not appropriate for an
  /// object of this kind.
  DartObjectImpl lazyAnd(TypeSystemImpl typeSystem,
      DartObjectImpl? Function() rightOperandComputer) {
    return DartObjectImpl(
      typeSystem,
      typeSystem.typeProvider.boolType,
      state.lazyAnd(() => rightOperandComputer()?.state),
    );
  }

  /// Return the result of invoking the '==' operator on this object with the
  /// [rightOperand].
  ///
  /// Throws an [EvaluationException] if the operator is not appropriate for an
  /// object of this kind.
  DartObjectImpl lazyEqualEqual(
      TypeSystemImpl typeSystem, DartObjectImpl rightOperand) {
    if (isNull || rightOperand.isNull) {
      return DartObjectImpl(
        typeSystem,
        typeSystem.typeProvider.boolType,
        isNull && rightOperand.isNull
            ? BoolState.TRUE_STATE
            : BoolState.FALSE_STATE,
      );
    }
    if (isBoolNumStringOrNull) {
      return DartObjectImpl(
        typeSystem,
        typeSystem.typeProvider.boolType,
        state.lazyEqualEqual(typeSystem, rightOperand.state),
      );
    }
    throw EvaluationException(
        CompileTimeErrorCode.CONST_EVAL_TYPE_BOOL_NUM_STRING);
  }

  /// Return the result of invoking the '||' operator on this object with the
  /// [rightOperand].
  ///
  /// Throws an [EvaluationException] if the operator is not appropriate for an
  /// object of this kind.
  DartObjectImpl lazyOr(TypeSystemImpl typeSystem,
          DartObjectImpl? Function() rightOperandComputer) =>
      DartObjectImpl(
        typeSystem,
        typeSystem.typeProvider.boolType,
        state.lazyOr(() => rightOperandComputer()?.state),
      );

  /// Return the result of invoking the '&lt;' operator on this object with the
  /// [rightOperand].
  ///
  /// Throws an [EvaluationException] if the operator is not appropriate for an
  /// object of this kind.
  DartObjectImpl lessThan(
      TypeSystemImpl typeSystem, DartObjectImpl rightOperand) {
    return DartObjectImpl(
      typeSystem,
      typeSystem.typeProvider.boolType,
      state.lessThan(rightOperand.state),
    );
  }

  /// Return the result of invoking the '&lt;=' operator on this object with the
  /// [rightOperand].
  ///
  /// Throws an [EvaluationException] if the operator is not appropriate for an
  /// object of this kind.
  DartObjectImpl lessThanOrEqual(
      TypeSystemImpl typeSystem, DartObjectImpl rightOperand) {
    return DartObjectImpl(
      typeSystem,
      typeSystem.typeProvider.boolType,
      state.lessThanOrEqual(rightOperand.state),
    );
  }

  /// Return the result of invoking the '!' operator on this object.
  ///
  /// Throws an [EvaluationException] if the operator is not appropriate for an
  /// object of this kind.
  DartObjectImpl logicalNot(TypeSystemImpl typeSystem) {
    return DartObjectImpl(
      typeSystem,
      typeSystem.typeProvider.boolType,
      state.logicalNot(),
    );
  }

  /// Return the result of invoking the '&gt;&gt;&gt;' operator on this object
  /// with the [rightOperand].
  ///
  /// Throws an [EvaluationException] if the operator is not appropriate for an
  /// object of this kind.
  DartObjectImpl logicalShiftRight(
      TypeSystemImpl typeSystem, DartObjectImpl rightOperand) {
    return DartObjectImpl(
      typeSystem,
      typeSystem.typeProvider.intType,
      state.logicalShiftRight(rightOperand.state),
    );
  }

  /// Return the result of invoking the '-' operator on this object with the
  /// [rightOperand].
  ///
  /// Throws an [EvaluationException] if the operator is not appropriate for an
  /// object of this kind.
  DartObjectImpl minus(TypeSystemImpl typeSystem, DartObjectImpl rightOperand) {
    InstanceState result = state.minus(rightOperand.state);
    if (result is IntState) {
      return DartObjectImpl(
        typeSystem,
        typeSystem.typeProvider.intType,
        result,
      );
    } else if (result is DoubleState) {
      return DartObjectImpl(
        typeSystem,
        typeSystem.typeProvider.doubleType,
        result,
      );
    }
    // We should never get here.
    throw StateError("minus returned a ${result.runtimeType}");
  }

  /// Return the result of invoking the '-' operator on this object.
  ///
  /// Throws an [EvaluationException] if the operator is not appropriate for an
  /// object of this kind.
  DartObjectImpl negated(TypeSystemImpl typeSystem) {
    InstanceState result = state.negated();
    if (result is IntState) {
      return DartObjectImpl(
        typeSystem,
        typeSystem.typeProvider.intType,
        result,
      );
    } else if (result is DoubleState) {
      return DartObjectImpl(
        typeSystem,
        typeSystem.typeProvider.doubleType,
        result,
      );
    }
    // We should never get here.
    throw StateError("negated returned a ${result.runtimeType}");
  }

  /// Return the result of invoking the '!=' operator on this object with the
  /// [rightOperand].
  ///
  /// Throws an [EvaluationException] if the operator is not appropriate for an
  /// object of this kind.
  DartObjectImpl notEqual(
      TypeSystemImpl typeSystem, DartObjectImpl rightOperand) {
    return equalEqual(typeSystem, rightOperand).logicalNot(typeSystem);
  }

  /// Return the result of converting this object to a 'String'.
  ///
  /// Throws an [EvaluationException] if the object cannot be converted to a
  /// 'String'.
  DartObjectImpl performToString(TypeSystemImpl typeSystem) {
    InterfaceType stringType = typeSystem.typeProvider.stringType;
    if (identical(type, stringType)) {
      return this;
    }
    return DartObjectImpl(typeSystem, stringType, state.convertToString());
  }

  /// Return the result of invoking the '%' operator on this object with the
  /// [rightOperand].
  ///
  /// Throws an [EvaluationException] if the operator is not appropriate for an
  /// object of this kind.
  DartObjectImpl remainder(
      TypeSystemImpl typeSystem, DartObjectImpl rightOperand) {
    InstanceState result = state.remainder(rightOperand.state);
    if (result is IntState) {
      return DartObjectImpl(
        typeSystem,
        typeSystem.typeProvider.intType,
        result,
      );
    } else if (result is DoubleState) {
      return DartObjectImpl(
        typeSystem,
        typeSystem.typeProvider.doubleType,
        result,
      );
    }
    // We should never get here.
    throw StateError("remainder returned a ${result.runtimeType}");
  }

  /// Return the result of invoking the '&lt;&lt;' operator on this object with
  /// the [rightOperand].
  ///
  /// Throws an [EvaluationException] if the operator is not appropriate for an
  /// object of this kind.
  DartObjectImpl shiftLeft(
      TypeSystemImpl typeSystem, DartObjectImpl rightOperand) {
    return DartObjectImpl(
      typeSystem,
      typeSystem.typeProvider.intType,
      state.shiftLeft(rightOperand.state),
    );
  }

  /// Return the result of invoking the '&gt;&gt;' operator on this object with
  /// the [rightOperand].
  ///
  /// Throws an [EvaluationException] if the operator is not appropriate for an
  /// object of this kind.
  DartObjectImpl shiftRight(
      TypeSystemImpl typeSystem, DartObjectImpl rightOperand) {
    return DartObjectImpl(
      typeSystem,
      typeSystem.typeProvider.intType,
      state.shiftRight(rightOperand.state),
    );
  }

  /// Return the result of invoking the 'length' getter on this object.
  ///
  /// Throws an [EvaluationException] if the operator is not appropriate for an
  /// object of this kind.
  DartObjectImpl stringLength(TypeSystemImpl typeSystem) {
    return DartObjectImpl(
      typeSystem,
      typeSystem.typeProvider.intType,
      state.stringLength(),
    );
  }

  /// Return the result of invoking the '*' operator on this object with the
  /// [rightOperand].
  ///
  /// Throws an [EvaluationException] if the operator is not appropriate for an
  /// object of this kind.
  DartObjectImpl times(TypeSystemImpl typeSystem, DartObjectImpl rightOperand) {
    InstanceState result = state.times(rightOperand.state);
    if (result is IntState) {
      return DartObjectImpl(
        typeSystem,
        typeSystem.typeProvider.intType,
        result,
      );
    } else if (result is DoubleState) {
      return DartObjectImpl(
        typeSystem,
        typeSystem.typeProvider.doubleType,
        result,
      );
    }
    // We should never get here.
    throw StateError("times returned a ${result.runtimeType}");
  }

  @override
  bool? toBoolValue() {
    final state = this.state;
    if (state is BoolState) {
      return state.value;
    }
    return null;
  }

  @override
  double? toDoubleValue() {
    final state = this.state;
    if (state is DoubleState) {
      return state.value;
    }
    return null;
  }

  @override
  ExecutableElement? toFunctionValue() {
    final state = this.state;
    return state is FunctionState ? state._element : null;
  }

  @override
  int? toIntValue() {
    final state = this.state;
    if (state is IntState) {
      return state.value;
    }
    return null;
  }

  @override
  List<DartObjectImpl>? toListValue() {
    final state = this.state;
    if (state is ListState) {
      return state._elements;
    }
    return null;
  }

  @override
  Map<DartObjectImpl, DartObjectImpl>? toMapValue() {
    final state = this.state;
    if (state is MapState) {
      return state._entries;
    }
    return null;
  }

  @override
  Set<DartObjectImpl>? toSetValue() {
    final state = this.state;
    if (state is SetState) {
      return state._elements;
    }
    return null;
  }

  @override
  String toString() {
    return "${type.getDisplayString(withNullability: false)} ($state)";
  }

  @override
  String? toStringValue() {
    final state = this.state;
    if (state is StringState) {
      return state.value;
    }
    return null;
  }

  @override
  String? toSymbolValue() {
    final state = this.state;
    if (state is SymbolState) {
      return state.value;
    }
    return null;
  }

  @override
  DartType? toTypeValue() {
    final state = this.state;
    if (state is TypeState) {
      return state._type;
    }
    return null;
  }

  /// Return the result of type-instantiating this object as [type].
  ///
  /// [typeArguments] are the type arguments used in the instantiation.
  DartObjectImpl? typeInstantiate(
    TypeSystemImpl typeSystem,
    FunctionType type,
    List<DartType> typeArguments,
  ) {
    var functionState = state as FunctionState;
    return DartObjectImpl(
      typeSystem,
      type,
      FunctionState(
        functionState._element,
        typeArguments: typeArguments,
        viaTypeAlias: functionState._viaTypeAlias,
      ),
    );
  }

  /// Set the `index` and `_name` fields for this enum constant.
  void updateEnumConstant({
    required int index,
    required String name,
  }) {
    var fields = state.fields!;
    fields['index'] = DartObjectImpl(
      _typeSystem,
      _typeSystem.typeProvider.intType,
      IntState(index),
    );
    fields['_name'] = DartObjectImpl(
      _typeSystem,
      _typeSystem.typeProvider.stringType,
      StringState(name),
    );
  }

  /// Throw an exception if the given [object]'s state does not represent a Type
  /// value.
  void _assertType(DartObjectImpl object) {
    if (object.state is! TypeState) {
      throw EvaluationException(CompileTimeErrorCode.CONST_EVAL_TYPE_TYPE);
    }
  }
}

/// The state of an object representing a double.
class DoubleState extends NumState {
  /// A state that can be used to represent a double whose value is not known.
  static DoubleState UNKNOWN_VALUE = DoubleState(null);

  /// The value of this instance.
  final double? value;

  /// Initialize a newly created state to represent a double with the given
  /// [value].
  DoubleState(this.value);

  @override
  int get hashCode => value == null ? 0 : value.hashCode;

  @override
  bool get isUnknown => value == null;

  @override
  String get typeName => "double";

  @override
  bool operator ==(Object other) =>
      other is DoubleState && (value == other.value);

  @override
  NumState add(InstanceState rightOperand) {
    assertNumOrNull(rightOperand);
    if (value == null) {
      return UNKNOWN_VALUE;
    }
    if (rightOperand is IntState) {
      var rightValue = rightOperand.value;
      if (rightValue == null) {
        return UNKNOWN_VALUE;
      }
      return DoubleState(value! + rightValue.toDouble());
    } else if (rightOperand is DoubleState) {
      var rightValue = rightOperand.value;
      if (rightValue == null) {
        return UNKNOWN_VALUE;
      }
      return DoubleState(value! + rightValue);
    }
    throw EvaluationException(CompileTimeErrorCode.CONST_EVAL_THROWS_EXCEPTION);
  }

  @override
  StringState convertToString() {
    if (value == null) {
      return StringState.UNKNOWN_VALUE;
    }
    return StringState(value.toString());
  }

  @override
  NumState divide(InstanceState rightOperand) {
    assertNumOrNull(rightOperand);
    if (value == null) {
      return UNKNOWN_VALUE;
    }
    if (rightOperand is IntState) {
      var rightValue = rightOperand.value;
      if (rightValue == null) {
        return UNKNOWN_VALUE;
      }
      return DoubleState(value! / rightValue.toDouble());
    } else if (rightOperand is DoubleState) {
      var rightValue = rightOperand.value;
      if (rightValue == null) {
        return UNKNOWN_VALUE;
      }
      return DoubleState(value! / rightValue);
    }
    throw EvaluationException(CompileTimeErrorCode.CONST_EVAL_THROWS_EXCEPTION);
  }

  @override
  BoolState greaterThan(InstanceState rightOperand) {
    assertNumOrNull(rightOperand);
    if (value == null) {
      return BoolState.UNKNOWN_VALUE;
    }
    if (rightOperand is IntState) {
      var rightValue = rightOperand.value;
      if (rightValue == null) {
        return BoolState.UNKNOWN_VALUE;
      }
      return BoolState.from(value! > rightValue.toDouble());
    } else if (rightOperand is DoubleState) {
      var rightValue = rightOperand.value;
      if (rightValue == null) {
        return BoolState.UNKNOWN_VALUE;
      }
      return BoolState.from(value! > rightValue);
    }
    throw EvaluationException(CompileTimeErrorCode.CONST_EVAL_THROWS_EXCEPTION);
  }

  @override
  BoolState greaterThanOrEqual(InstanceState rightOperand) {
    assertNumOrNull(rightOperand);
    if (value == null) {
      return BoolState.UNKNOWN_VALUE;
    }
    if (rightOperand is IntState) {
      var rightValue = rightOperand.value;
      if (rightValue == null) {
        return BoolState.UNKNOWN_VALUE;
      }
      return BoolState.from(value! >= rightValue.toDouble());
    } else if (rightOperand is DoubleState) {
      var rightValue = rightOperand.value;
      if (rightValue == null) {
        return BoolState.UNKNOWN_VALUE;
      }
      return BoolState.from(value! >= rightValue);
    }
    throw EvaluationException(CompileTimeErrorCode.CONST_EVAL_THROWS_EXCEPTION);
  }

  @override
  IntState integerDivide(InstanceState rightOperand) {
    assertNumOrNull(rightOperand);
    if (value == null) {
      return IntState.UNKNOWN_VALUE;
    }
    if (rightOperand is IntState) {
      var rightValue = rightOperand.value;
      if (rightValue == null) {
        return IntState.UNKNOWN_VALUE;
      }
      var result = value! / rightValue.toDouble();
      if (result.isFinite) {
        return IntState(result.toInt());
      }
    } else if (rightOperand is DoubleState) {
      var rightValue = rightOperand.value;
      if (rightValue == null) {
        return IntState.UNKNOWN_VALUE;
      }
      double result = value! / rightValue;
      if (result.isFinite) {
        return IntState(result.toInt());
      }
    }
    throw EvaluationException(CompileTimeErrorCode.CONST_EVAL_THROWS_EXCEPTION);
  }

  @override
  BoolState isIdentical(TypeSystemImpl typeSystem, InstanceState rightOperand) {
    if (value == null) {
      return BoolState.UNKNOWN_VALUE;
    }
    if (rightOperand is DoubleState) {
      var rightValue = rightOperand.value;
      if (rightValue == null) {
        return BoolState.UNKNOWN_VALUE;
      }
      return BoolState.from(value == rightValue);
    } else if (rightOperand is IntState) {
      var rightValue = rightOperand.value;
      if (rightValue == null) {
        return BoolState.UNKNOWN_VALUE;
      }
      return BoolState.from(value == rightValue.toDouble());
    }
    return BoolState.FALSE_STATE;
  }

  @override
  BoolState lessThan(InstanceState rightOperand) {
    assertNumOrNull(rightOperand);
    if (value == null) {
      return BoolState.UNKNOWN_VALUE;
    }
    if (rightOperand is IntState) {
      var rightValue = rightOperand.value;
      if (rightValue == null) {
        return BoolState.UNKNOWN_VALUE;
      }
      return BoolState.from(value! < rightValue.toDouble());
    } else if (rightOperand is DoubleState) {
      var rightValue = rightOperand.value;
      if (rightValue == null) {
        return BoolState.UNKNOWN_VALUE;
      }
      return BoolState.from(value! < rightValue);
    }
    throw EvaluationException(CompileTimeErrorCode.CONST_EVAL_THROWS_EXCEPTION);
  }

  @override
  BoolState lessThanOrEqual(InstanceState rightOperand) {
    assertNumOrNull(rightOperand);
    if (value == null) {
      return BoolState.UNKNOWN_VALUE;
    }
    if (rightOperand is IntState) {
      var rightValue = rightOperand.value;
      if (rightValue == null) {
        return BoolState.UNKNOWN_VALUE;
      }
      return BoolState.from(value! <= rightValue.toDouble());
    } else if (rightOperand is DoubleState) {
      var rightValue = rightOperand.value;
      if (rightValue == null) {
        return BoolState.UNKNOWN_VALUE;
      }
      return BoolState.from(value! <= rightValue);
    }
    throw EvaluationException(CompileTimeErrorCode.CONST_EVAL_THROWS_EXCEPTION);
  }

  @override
  NumState minus(InstanceState rightOperand) {
    assertNumOrNull(rightOperand);
    if (value == null) {
      return UNKNOWN_VALUE;
    }
    if (rightOperand is IntState) {
      var rightValue = rightOperand.value;
      if (rightValue == null) {
        return UNKNOWN_VALUE;
      }
      return DoubleState(value! - rightValue.toDouble());
    } else if (rightOperand is DoubleState) {
      var rightValue = rightOperand.value;
      if (rightValue == null) {
        return UNKNOWN_VALUE;
      }
      return DoubleState(value! - rightValue);
    }
    throw EvaluationException(CompileTimeErrorCode.CONST_EVAL_THROWS_EXCEPTION);
  }

  @override
  NumState negated() {
    if (value == null) {
      return UNKNOWN_VALUE;
    }
    return DoubleState(-value!);
  }

  @override
  NumState remainder(InstanceState rightOperand) {
    assertNumOrNull(rightOperand);
    if (value == null) {
      return UNKNOWN_VALUE;
    }
    if (rightOperand is IntState) {
      var rightValue = rightOperand.value;
      if (rightValue == null) {
        return UNKNOWN_VALUE;
      }
      return DoubleState(value! % rightValue.toDouble());
    } else if (rightOperand is DoubleState) {
      var rightValue = rightOperand.value;
      if (rightValue == null) {
        return UNKNOWN_VALUE;
      }
      return DoubleState(value! % rightValue);
    }
    throw EvaluationException(CompileTimeErrorCode.CONST_EVAL_THROWS_EXCEPTION);
  }

  @override
  NumState times(InstanceState rightOperand) {
    assertNumOrNull(rightOperand);
    if (value == null) {
      return UNKNOWN_VALUE;
    }
    if (rightOperand is IntState) {
      var rightValue = rightOperand.value;
      if (rightValue == null) {
        return UNKNOWN_VALUE;
      }
      return DoubleState(value! * rightValue.toDouble());
    } else if (rightOperand is DoubleState) {
      var rightValue = rightOperand.value;
      if (rightValue == null) {
        return UNKNOWN_VALUE;
      }
      return DoubleState(value! * rightValue);
    }
    throw EvaluationException(CompileTimeErrorCode.CONST_EVAL_THROWS_EXCEPTION);
  }

  @override
  String toString() => value == null ? "-unknown-" : value.toString();
}

/// Exception that would be thrown during the evaluation of Dart code.
class EvaluationException {
  /// The error code associated with the exception.
  final ErrorCode errorCode;

  /// Initialize a newly created exception to have the given [errorCode].
  EvaluationException(this.errorCode);
}

/// The state of an object representing a function.
class FunctionState extends InstanceState {
  /// The element representing the function being modeled.
  final ExecutableElement? _element;

  final List<DartType>? _typeArguments;

  /// The type alias which was referenced when tearing off a constructor,
  /// if this function is a constructor tear-off, referenced via a type alias,
  /// and the type alias is not a proper rename for the class, and the
  /// constructor tear-off is generic, so the tear-off cannot be considered
  /// equivalent to tearing off the associated constructor function of the
  /// aliased class.
  ///
  /// Otherwise null.
  final TypeDefiningElement? _viaTypeAlias;

  /// Initialize a newly created state to represent the function with the given
  /// [element].
  FunctionState(this._element,
      {List<DartType>? typeArguments, TypeDefiningElement? viaTypeAlias})
      : _typeArguments = typeArguments,
        _viaTypeAlias = viaTypeAlias;

  @override
  int get hashCode => _element == null ? 0 : _element.hashCode;

  @override
  String get typeName => "Function";

  @override
  bool operator ==(Object other) {
    if (other is! FunctionState) {
      return false;
    }
    if (_element != other._element) {
      return false;
    }
    var typeArguments = _typeArguments;
    var otherTypeArguments = other._typeArguments;
    if (typeArguments == null || otherTypeArguments == null) {
      return typeArguments == null && otherTypeArguments == null;
    }
    if (typeArguments.length != otherTypeArguments.length) {
      return false;
    }
    if (_viaTypeAlias != other._viaTypeAlias) {
      return false;
    }
    for (var i = 0; i < typeArguments.length; i++) {
      if (typeArguments[i] != otherTypeArguments[i]) {
        return false;
      }
    }
    return true;
  }

  @override
  StringState convertToString() {
    if (_element == null) {
      return StringState.UNKNOWN_VALUE;
    }
    return StringState(_element!.name);
  }

  @override
  BoolState equalEqual(TypeSystemImpl typeSystem, InstanceState rightOperand) {
    return isIdentical(typeSystem, rightOperand);
  }

  @override
  bool hasPrimitiveEquality(FeatureSet featureSet) => true;

  @override
  BoolState isIdentical(TypeSystemImpl typeSystem, InstanceState rightOperand) {
    if (_element == null) {
      return BoolState.UNKNOWN_VALUE;
    }
    if (rightOperand is FunctionState) {
      var rightElement = rightOperand._element;
      if (rightElement == null) {
        return BoolState.UNKNOWN_VALUE;
      }

      var element = _element;
      var otherElement = rightOperand._element;
      if (element?.declaration != otherElement?.declaration) {
        return BoolState.FALSE_STATE;
      }
      if (_viaTypeAlias != rightOperand._viaTypeAlias) {
        return BoolState.FALSE_STATE;
      }
      var typeArguments = _typeArguments;
      var otherTypeArguments = rightOperand._typeArguments;
      if (typeArguments == null || otherTypeArguments == null) {
        return BoolState.from(
            typeArguments == null && otherTypeArguments == null);
      }
      if (typeArguments.length != otherTypeArguments.length) {
        return BoolState.FALSE_STATE;
      }
      for (var i = 0; i < typeArguments.length; i++) {
        if (!typeSystem.runtimeTypesEqual(
          typeArguments[i],
          otherTypeArguments[i],
        )) {
          return BoolState.FALSE_STATE;
        }
      }
      return BoolState.TRUE_STATE;
    }
    return BoolState.FALSE_STATE;
  }

  @override
  String toString() => _element?.name ?? "-unknown-";
}

/// The state of an object representing a Dart object for which there is no more
/// specific state.
class GenericState extends InstanceState {
  /// Pseudo-field that we use to represent fields in the superclass.
  static String SUPERCLASS_FIELD = "(super)";

  /// The type of the object being represented.
  final DartType _type;

  /// The values of the fields of this instance.
  final Map<String, DartObjectImpl> _fieldMap;

  /// Information about the constructor invoked to generate this instance.
  final ConstructorInvocation? invocation;

  @override
  final bool isUnknown;

  /// Initialize a newly created state to represent a newly created object. The
  /// [fieldMap] contains the values of the fields of the instance.
  GenericState(
    this._type,
    this._fieldMap, {
    this.invocation,
    this.isUnknown = false,
  });

  @override
  Map<String, DartObjectImpl> get fields => _fieldMap;

  @override
  int get hashCode {
    int hashCode = 0;
    for (DartObjectImpl value in _fieldMap.values) {
      hashCode += value.hashCode;
    }
    return hashCode;
  }

  @override
  String get typeName => "user defined type";

  @override
  bool operator ==(Object other) {
    if (other is GenericState) {
      HashSet<String> otherFields =
          HashSet<String>.from(other._fieldMap.keys.toSet());
      for (String fieldName in _fieldMap.keys.toSet()) {
        if (_fieldMap[fieldName] != other._fieldMap[fieldName]) {
          return false;
        }
        otherFields.remove(fieldName);
      }
      for (String fieldName in otherFields) {
        if (other._fieldMap[fieldName] != _fieldMap[fieldName]) {
          return false;
        }
      }
      return true;
    }
    return false;
  }

  @override
  StringState convertToString() => StringState.UNKNOWN_VALUE;

  @override
  BoolState equalEqual(TypeSystemImpl typeSystem, InstanceState rightOperand) {
    assertBoolNumStringOrNull(rightOperand);
    return isIdentical(typeSystem, rightOperand);
  }

  @override
  bool hasPrimitiveEquality(FeatureSet featureSet) {
    final type = _type;
    if (type is InterfaceType) {
      bool isFromDartCoreObject(ExecutableElement? element) {
        final enclosing = element?.enclosingElement;
        return enclosing is ClassElement && enclosing.isDartCoreObject;
      }

      final element = type.element;
      final library = element.library;

      final eqEq = type.lookUpMethod2('==', library, concrete: true);
      if (!isFromDartCoreObject(eqEq)) {
        return false;
      }

      if (featureSet.isEnabled(Feature.patterns)) {
        final hash = type.lookUpGetter2('hashCode', library, concrete: true);
        if (!isFromDartCoreObject(hash)) {
          return false;
        }
      }

      return true;
    } else {
      return false;
    }
  }

  @override
  BoolState isIdentical(TypeSystemImpl typeSystem, InstanceState rightOperand) {
    return BoolState.from(this == rightOperand);
  }

  @override
  String toString() {
    StringBuffer buffer = StringBuffer();
    List<String> fieldNames = _fieldMap.keys.toList();
    fieldNames.sort();
    bool first = true;
    for (String fieldName in fieldNames) {
      if (first) {
        first = false;
      } else {
        buffer.write('; ');
      }
      buffer.write(fieldName);
      buffer.write(' = ');
      buffer.write(_fieldMap[fieldName]);
    }
    return buffer.toString();
  }
}

/// The state of an object representing a Dart object.
abstract class InstanceState {
  /// If this represents a generic dart object, return a map from its field
  /// names to their values. Otherwise return null.
  Map<String, DartObjectImpl>? get fields => null;

  /// Return `true` if this object represents an object whose type is 'bool'.
  bool get isBool => false;

  /// Return `true` if this object represents an object whose type is either
  /// 'bool', 'num', 'String', or 'Null'.
  bool get isBoolNumStringOrNull => false;

  /// Return `true` if this object represents an object whose type is 'int'.
  bool get isInt => false;

  /// Return `true` if this object represents the value 'null'.
  bool get isNull => false;

  /// Return `true` if this object represents an unknown value.
  bool get isUnknown => false;

  /// Return the name of the type of this value.
  String get typeName;

  /// Return the result of invoking the '+' operator on this object with the
  /// [rightOperand].
  ///
  /// Throws an [EvaluationException] if the operator is not appropriate for an
  /// object of this kind.
  InstanceState add(InstanceState rightOperand) {
    if (this is StringState && rightOperand is StringState) {
      return concatenate(rightOperand);
    }
    assertNumOrNull(this);
    assertNumOrNull(rightOperand);
    throw EvaluationException(CompileTimeErrorCode.CONST_EVAL_THROWS_EXCEPTION);
  }

  /// Throw an exception if the given [state] does not represent a boolean value.
  void assertBool(InstanceState? state) {
    if (state is! BoolState) {
      throw EvaluationException(CompileTimeErrorCode.CONST_EVAL_TYPE_BOOL);
    }
  }

  /// Throw an exception if the given [state] does not represent a boolean,
  /// numeric, string or null value.
  void assertBoolNumStringOrNull(InstanceState state) {
    if (!(state is BoolState ||
        state is NumState ||
        state is StringState ||
        state is NullState)) {
      throw EvaluationException(
          CompileTimeErrorCode.CONST_EVAL_TYPE_BOOL_NUM_STRING);
    }
  }

  /// Throw an exception if the given [state] does not represent an integer or
  /// null value.
  void assertIntOrNull(InstanceState state) {
    if (!(state is IntState || state is NullState)) {
      throw EvaluationException(CompileTimeErrorCode.CONST_EVAL_TYPE_INT);
    }
  }

  /// Throw an exception if the given [state] does not represent a boolean,
  /// numeric, string or null value.
  void assertNumOrNull(InstanceState state) {
    if (!(state is NumState || state is NullState)) {
      throw EvaluationException(CompileTimeErrorCode.CONST_EVAL_TYPE_NUM);
    }
  }

  /// Throw an exception if the given [state] does not represent a String value.
  void assertString(InstanceState state) {
    if (state is! StringState) {
      throw EvaluationException(CompileTimeErrorCode.CONST_EVAL_TYPE_BOOL);
    }
  }

  /// Return the result of invoking the '&' operator on this object with the
  /// [rightOperand].
  ///
  /// Throws an [EvaluationException] if the operator is not appropriate for an
  /// object of this kind.
  IntState bitAnd(InstanceState rightOperand) {
    assertIntOrNull(this);
    assertIntOrNull(rightOperand);
    throw EvaluationException(CompileTimeErrorCode.CONST_EVAL_THROWS_EXCEPTION);
  }

  /// Return the result of invoking the '~' operator on this object.
  ///
  /// Throws an [EvaluationException] if the operator is not appropriate for an
  /// object of this kind.
  IntState bitNot() {
    assertIntOrNull(this);
    throw EvaluationException(CompileTimeErrorCode.CONST_EVAL_THROWS_EXCEPTION);
  }

  /// Return the result of invoking the '|' operator on this object with the
  /// [rightOperand].
  ///
  /// Throws an [EvaluationException] if the operator is not appropriate for an
  /// object of this kind.
  IntState bitOr(InstanceState rightOperand) {
    assertIntOrNull(this);
    assertIntOrNull(rightOperand);
    throw EvaluationException(CompileTimeErrorCode.CONST_EVAL_THROWS_EXCEPTION);
  }

  /// Return the result of invoking the '^' operator on this object with the
  /// [rightOperand].
  ///
  /// Throws an [EvaluationException] if the operator is not appropriate for an
  /// object of this kind.
  IntState bitXor(InstanceState rightOperand) {
    assertIntOrNull(this);
    assertIntOrNull(rightOperand);
    throw EvaluationException(CompileTimeErrorCode.CONST_EVAL_THROWS_EXCEPTION);
  }

  /// Return the result of invoking the ' ' operator on this object with the
  /// [rightOperand].
  ///
  /// Throws an [EvaluationException] if the operator is not appropriate for an
  /// object of this kind.
  StringState concatenate(InstanceState rightOperand) {
    assertString(rightOperand);
    throw EvaluationException(CompileTimeErrorCode.CONST_EVAL_THROWS_EXCEPTION);
  }

  /// Return the result of applying boolean conversion to this object.
  ///
  /// Throws an [EvaluationException] if the operator is not appropriate for an
  /// object of this kind.
  BoolState convertToBool() => BoolState.FALSE_STATE;

  /// Return the result of converting this object to a String.
  ///
  /// Throws an [EvaluationException] if the operator is not appropriate for an
  /// object of this kind.
  StringState convertToString();

  /// Return the result of invoking the '/' operator on this object with the
  /// [rightOperand].
  ///
  /// Throws an [EvaluationException] if the operator is not appropriate for an
  /// object of this kind.
  NumState divide(InstanceState rightOperand) {
    assertNumOrNull(this);
    assertNumOrNull(rightOperand);
    throw EvaluationException(CompileTimeErrorCode.CONST_EVAL_THROWS_EXCEPTION);
  }

  /// Return the result of invoking the '==' operator on this object with the
  /// [rightOperand].
  ///
  /// Throws an [EvaluationException] if the operator is not appropriate for an
  /// object of this kind.
  BoolState equalEqual(TypeSystemImpl typeSystem, InstanceState rightOperand);

  /// Return the result of invoking the '&gt;' operator on this object with the
  /// [rightOperand].
  ///
  /// Throws an [EvaluationException] if the operator is not appropriate for an
  /// object of this kind.
  BoolState greaterThan(InstanceState rightOperand) {
    assertNumOrNull(this);
    assertNumOrNull(rightOperand);
    throw EvaluationException(CompileTimeErrorCode.CONST_EVAL_THROWS_EXCEPTION);
  }

  /// Return the result of invoking the '&gt;=' operator on this object with the
  /// [rightOperand].
  ///
  /// Throws an [EvaluationException] if the operator is not appropriate for an
  /// object of this kind.
  BoolState greaterThanOrEqual(InstanceState rightOperand) {
    assertNumOrNull(this);
    assertNumOrNull(rightOperand);
    throw EvaluationException(CompileTimeErrorCode.CONST_EVAL_THROWS_EXCEPTION);
  }

  /// Returns `true` if this value, inside a library with the [featureSet],
  /// has primitive equality, so can be used at compile-time.
  bool hasPrimitiveEquality(FeatureSet featureSet) => false;

  /// Return the result of invoking the '~/' operator on this object with the
  /// [rightOperand].
  ///
  /// Throws an [EvaluationException] if the operator is not appropriate for an
  /// object of this kind.
  IntState integerDivide(InstanceState rightOperand) {
    assertNumOrNull(this);
    assertNumOrNull(rightOperand);
    throw EvaluationException(CompileTimeErrorCode.CONST_EVAL_THROWS_EXCEPTION);
  }

  /// Return the result of invoking the identical function on this object with
  /// the [rightOperand].
  BoolState isIdentical(TypeSystemImpl typeSystem, InstanceState rightOperand);

  /// Return the result of invoking the '&&' operator on this object with the
  /// [rightOperand].
  ///
  /// Throws an [EvaluationException] if the operator is not appropriate for an
  /// object of this kind.
  BoolState lazyAnd(InstanceState? Function() rightOperandComputer) {
    assertBool(this);
    if (convertToBool() == BoolState.FALSE_STATE) {
      return this as BoolState;
    }
    var rightOperand = rightOperandComputer();
    assertBool(rightOperand);
    return rightOperand!.convertToBool();
  }

  /// Return the result of invoking the '==' operator on this object with the
  /// [rightOperand].
  ///
  /// Throws an [EvaluationException] if the operator is not appropriate for an
  /// object of this kind.
  BoolState lazyEqualEqual(
    TypeSystemImpl typeSystem,
    InstanceState rightOperand,
  ) {
    return isIdentical(typeSystem, rightOperand);
  }

  /// Return the result of invoking the '||' operator on this object with the
  /// [rightOperand].
  ///
  /// Throws an [EvaluationException] if the operator is not appropriate for an
  /// object of this kind.
  BoolState lazyOr(InstanceState? Function() rightOperandComputer) {
    assertBool(this);
    if (convertToBool() == BoolState.TRUE_STATE) {
      return this as BoolState;
    }
    var rightOperand = rightOperandComputer();
    assertBool(rightOperand);
    return rightOperand!.convertToBool();
  }

  /// Return the result of invoking the '&lt;' operator on this object with the
  /// [rightOperand].
  ///
  /// Throws an [EvaluationException] if the operator is not appropriate for an
  /// object of this kind.
  BoolState lessThan(InstanceState rightOperand) {
    assertNumOrNull(this);
    assertNumOrNull(rightOperand);
    throw EvaluationException(CompileTimeErrorCode.CONST_EVAL_THROWS_EXCEPTION);
  }

  /// Return the result of invoking the '&lt;=' operator on this object with the
  /// [rightOperand].
  ///
  /// Throws an [EvaluationException] if the operator is not appropriate for an
  /// object of this kind.
  BoolState lessThanOrEqual(InstanceState rightOperand) {
    assertNumOrNull(this);
    assertNumOrNull(rightOperand);
    throw EvaluationException(CompileTimeErrorCode.CONST_EVAL_THROWS_EXCEPTION);
  }

  /// Return the result of invoking the '&' operator on this object with the
  /// [rightOperand].
  ///
  /// Throws an [EvaluationException] if the operator is not appropriate for an
  /// object of this kind.
  BoolState logicalAnd(InstanceState rightOperand) {
    assertBool(this);
    assertBool(rightOperand);
    var leftValue = convertToBool().value;
    var rightValue = rightOperand.convertToBool().value;
    if (leftValue == null || rightValue == null) {
      return BoolState.UNKNOWN_VALUE;
    }
    return BoolState.from(leftValue & rightValue);
  }

  /// Return the result of invoking the '!' operator on this object.
  ///
  /// Throws an [EvaluationException] if the operator is not appropriate for an
  /// object of this kind.
  BoolState logicalNot() {
    assertBool(this);
    return BoolState.TRUE_STATE;
  }

  /// Return the result of invoking the '|' operator on this object with the
  /// [rightOperand].
  ///
  /// Throws an [EvaluationException] if the operator is not appropriate for an
  /// object of this kind.
  BoolState logicalOr(InstanceState rightOperand) {
    assertBool(this);
    assertBool(rightOperand);
    var leftValue = convertToBool().value;
    var rightValue = rightOperand.convertToBool().value;
    if (leftValue == null || rightValue == null) {
      return BoolState.UNKNOWN_VALUE;
    }
    return BoolState.from(leftValue | rightValue);
  }

  /// Return the result of invoking the '&gt;&gt;&gt;' operator on this object
  /// with the [rightOperand].
  ///
  /// Throws an [EvaluationException] if the operator is not appropriate for an
  /// object of this kind.
  IntState logicalShiftRight(InstanceState rightOperand) {
    assertIntOrNull(this);
    assertIntOrNull(rightOperand);
    throw EvaluationException(CompileTimeErrorCode.CONST_EVAL_THROWS_EXCEPTION);
  }

  /// Return the result of invoking the '^' operator on this object with the
  /// [rightOperand].
  ///
  /// Throws an [EvaluationException] if the operator is not appropriate for an
  /// object of this kind.
  BoolState logicalXor(InstanceState rightOperand) {
    assertBool(this);
    assertBool(rightOperand);
    var leftValue = convertToBool().value;
    var rightValue = rightOperand.convertToBool().value;
    if (leftValue == null || rightValue == null) {
      return BoolState.UNKNOWN_VALUE;
    }
    return BoolState.from(leftValue ^ rightValue);
  }

  /// Return the result of invoking the '-' operator on this object with the
  /// [rightOperand].
  ///
  /// Throws an [EvaluationException] if the operator is not appropriate for an
  /// object of this kind.
  NumState minus(InstanceState rightOperand) {
    assertNumOrNull(this);
    assertNumOrNull(rightOperand);
    throw EvaluationException(CompileTimeErrorCode.CONST_EVAL_THROWS_EXCEPTION);
  }

  /// Return the result of invoking the '-' operator on this object.
  ///
  /// Throws an [EvaluationException] if the operator is not appropriate for an
  /// object of this kind.
  NumState negated() {
    assertNumOrNull(this);
    throw EvaluationException(CompileTimeErrorCode.CONST_EVAL_THROWS_EXCEPTION);
  }

  /// Return the result of invoking the '%' operator on this object with the
  /// [rightOperand].
  ///
  /// Throws an [EvaluationException] if the operator is not appropriate for an
  /// object of this kind.
  NumState remainder(InstanceState rightOperand) {
    assertNumOrNull(this);
    assertNumOrNull(rightOperand);
    throw EvaluationException(CompileTimeErrorCode.CONST_EVAL_THROWS_EXCEPTION);
  }

  /// Return the result of invoking the '&lt;&lt;' operator on this object with
  /// the [rightOperand].
  ///
  /// Throws an [EvaluationException] if the operator is not appropriate for an
  /// object of this kind.
  IntState shiftLeft(InstanceState rightOperand) {
    assertIntOrNull(this);
    assertIntOrNull(rightOperand);
    throw EvaluationException(CompileTimeErrorCode.CONST_EVAL_THROWS_EXCEPTION);
  }

  /// Return the result of invoking the '&gt;&gt;' operator on this object with
  /// the [rightOperand].
  ///
  /// Throws an [EvaluationException] if the operator is not appropriate for an
  /// object of this kind.
  IntState shiftRight(InstanceState rightOperand) {
    assertIntOrNull(this);
    assertIntOrNull(rightOperand);
    throw EvaluationException(CompileTimeErrorCode.CONST_EVAL_THROWS_EXCEPTION);
  }

  /// Return the result of invoking the 'length' getter on this object.
  ///
  /// Throws an [EvaluationException] if the operator is not appropriate for an
  /// object of this kind.
  IntState stringLength() {
    assertString(this);
    throw EvaluationException(CompileTimeErrorCode.CONST_EVAL_THROWS_EXCEPTION);
  }

  /// Return the result of invoking the '*' operator on this object with the
  /// [rightOperand].
  ///
  /// Throws an [EvaluationException] if the operator is not appropriate for an
  /// object of this kind.
  NumState times(InstanceState rightOperand) {
    assertNumOrNull(this);
    assertNumOrNull(rightOperand);
    throw EvaluationException(CompileTimeErrorCode.CONST_EVAL_THROWS_EXCEPTION);
  }
}

/// The state of an object representing an int.
class IntState extends NumState {
  /// A state that can be used to represent an int whose value is not known.
  static IntState UNKNOWN_VALUE = IntState(null);

  /// The value of this instance.
  final int? value;

  /// Initialize a newly created state to represent an int with the given
  /// [value].
  IntState(this.value);

  @override
  int get hashCode => value == null ? 0 : value.hashCode;

  @override
  bool get isInt => true;

  @override
  bool get isUnknown => value == null;

  @override
  String get typeName => "int";

  @override
  bool operator ==(Object other) => other is IntState && (value == other.value);

  @override
  NumState add(InstanceState rightOperand) {
    assertNumOrNull(rightOperand);
    if (value == null) {
      if (rightOperand is DoubleState) {
        return DoubleState.UNKNOWN_VALUE;
      }
      return UNKNOWN_VALUE;
    }
    if (rightOperand is IntState) {
      var rightValue = rightOperand.value;
      if (rightValue == null) {
        return UNKNOWN_VALUE;
      }
      return IntState(value! + rightValue);
    } else if (rightOperand is DoubleState) {
      var rightValue = rightOperand.value;
      if (rightValue == null) {
        return DoubleState.UNKNOWN_VALUE;
      }
      return DoubleState(value!.toDouble() + rightValue);
    }
    throw EvaluationException(CompileTimeErrorCode.CONST_EVAL_THROWS_EXCEPTION);
  }

  @override
  IntState bitAnd(InstanceState rightOperand) {
    assertIntOrNull(rightOperand);
    if (value == null) {
      return UNKNOWN_VALUE;
    }
    if (rightOperand is IntState) {
      var rightValue = rightOperand.value;
      if (rightValue == null) {
        return UNKNOWN_VALUE;
      }
      return IntState(value! & rightValue);
    }
    throw EvaluationException(CompileTimeErrorCode.CONST_EVAL_THROWS_EXCEPTION);
  }

  @override
  IntState bitNot() {
    if (value == null) {
      return UNKNOWN_VALUE;
    }
    return IntState(~value!);
  }

  @override
  IntState bitOr(InstanceState rightOperand) {
    assertIntOrNull(rightOperand);
    if (value == null) {
      return UNKNOWN_VALUE;
    }
    if (rightOperand is IntState) {
      var rightValue = rightOperand.value;
      if (rightValue == null) {
        return UNKNOWN_VALUE;
      }
      return IntState(value! | rightValue);
    }
    throw EvaluationException(CompileTimeErrorCode.CONST_EVAL_THROWS_EXCEPTION);
  }

  @override
  IntState bitXor(InstanceState rightOperand) {
    assertIntOrNull(rightOperand);
    if (value == null) {
      return UNKNOWN_VALUE;
    }
    if (rightOperand is IntState) {
      var rightValue = rightOperand.value;
      if (rightValue == null) {
        return UNKNOWN_VALUE;
      }
      return IntState(value! ^ rightValue);
    }
    throw EvaluationException(CompileTimeErrorCode.CONST_EVAL_THROWS_EXCEPTION);
  }

  @override
  StringState convertToString() {
    if (value == null) {
      return StringState.UNKNOWN_VALUE;
    }
    return StringState(value.toString());
  }

  @override
  NumState divide(InstanceState rightOperand) {
    assertNumOrNull(rightOperand);
    if (value == null) {
      return DoubleState.UNKNOWN_VALUE;
    }
    if (rightOperand is IntState) {
      var rightValue = rightOperand.value;
      if (rightValue == null) {
        return DoubleState.UNKNOWN_VALUE;
      } else {
        return DoubleState(value!.toDouble() / rightValue.toDouble());
      }
    } else if (rightOperand is DoubleState) {
      var rightValue = rightOperand.value;
      if (rightValue == null) {
        return DoubleState.UNKNOWN_VALUE;
      }
      return DoubleState(value!.toDouble() / rightValue);
    }
    throw EvaluationException(CompileTimeErrorCode.CONST_EVAL_THROWS_EXCEPTION);
  }

  @override
  BoolState greaterThan(InstanceState rightOperand) {
    assertNumOrNull(rightOperand);
    if (value == null) {
      return BoolState.UNKNOWN_VALUE;
    }
    if (rightOperand is IntState) {
      var rightValue = rightOperand.value;
      if (rightValue == null) {
        return BoolState.UNKNOWN_VALUE;
      }
      return BoolState.from(value!.compareTo(rightValue) > 0);
    } else if (rightOperand is DoubleState) {
      var rightValue = rightOperand.value;
      if (rightValue == null) {
        return BoolState.UNKNOWN_VALUE;
      }
      return BoolState.from(value!.toDouble() > rightValue);
    }
    throw EvaluationException(CompileTimeErrorCode.CONST_EVAL_THROWS_EXCEPTION);
  }

  @override
  BoolState greaterThanOrEqual(InstanceState rightOperand) {
    assertNumOrNull(rightOperand);
    if (value == null) {
      return BoolState.UNKNOWN_VALUE;
    }
    if (rightOperand is IntState) {
      var rightValue = rightOperand.value;
      if (rightValue == null) {
        return BoolState.UNKNOWN_VALUE;
      }
      return BoolState.from(value!.compareTo(rightValue) >= 0);
    } else if (rightOperand is DoubleState) {
      var rightValue = rightOperand.value;
      if (rightValue == null) {
        return BoolState.UNKNOWN_VALUE;
      }
      return BoolState.from(value!.toDouble() >= rightValue);
    }
    throw EvaluationException(CompileTimeErrorCode.CONST_EVAL_THROWS_EXCEPTION);
  }

  @override
  bool hasPrimitiveEquality(FeatureSet featureSet) => true;

  @override
  IntState integerDivide(InstanceState rightOperand) {
    assertNumOrNull(rightOperand);
    if (value == null) {
      return UNKNOWN_VALUE;
    }
    if (rightOperand is IntState) {
      var rightValue = rightOperand.value;
      if (rightValue == null) {
        return UNKNOWN_VALUE;
      } else if (rightValue == 0) {
        throw EvaluationException(CompileTimeErrorCode.CONST_EVAL_THROWS_IDBZE);
      }
      return IntState(value! ~/ rightValue);
    } else if (rightOperand is DoubleState) {
      var rightValue = rightOperand.value;
      if (rightValue == null) {
        return UNKNOWN_VALUE;
      }
      double result = value!.toDouble() / rightValue;
      if (result.isFinite) {
        return IntState(result.toInt());
      }
    }
    throw EvaluationException(CompileTimeErrorCode.CONST_EVAL_THROWS_EXCEPTION);
  }

  @override
  BoolState isIdentical(TypeSystemImpl typeSystem, InstanceState rightOperand) {
    if (value == null) {
      return BoolState.UNKNOWN_VALUE;
    }
    if (rightOperand is IntState) {
      var rightValue = rightOperand.value;
      if (rightValue == null) {
        return BoolState.UNKNOWN_VALUE;
      }
      return BoolState.from(value == rightValue);
    } else if (rightOperand is DoubleState) {
      var rightValue = rightOperand.value;
      if (rightValue == null) {
        return BoolState.UNKNOWN_VALUE;
      }
      return BoolState.from(rightValue == value!.toDouble());
    }
    return BoolState.FALSE_STATE;
  }

  @override
  BoolState lessThan(InstanceState rightOperand) {
    assertNumOrNull(rightOperand);
    if (value == null) {
      return BoolState.UNKNOWN_VALUE;
    }
    if (rightOperand is IntState) {
      var rightValue = rightOperand.value;
      if (rightValue == null) {
        return BoolState.UNKNOWN_VALUE;
      }
      return BoolState.from(value!.compareTo(rightValue) < 0);
    } else if (rightOperand is DoubleState) {
      var rightValue = rightOperand.value;
      if (rightValue == null) {
        return BoolState.UNKNOWN_VALUE;
      }
      return BoolState.from(value!.toDouble() < rightValue);
    }
    throw EvaluationException(CompileTimeErrorCode.CONST_EVAL_THROWS_EXCEPTION);
  }

  @override
  BoolState lessThanOrEqual(InstanceState rightOperand) {
    assertNumOrNull(rightOperand);
    if (value == null) {
      return BoolState.UNKNOWN_VALUE;
    }
    if (rightOperand is IntState) {
      var rightValue = rightOperand.value;
      if (rightValue == null) {
        return BoolState.UNKNOWN_VALUE;
      }
      return BoolState.from(value!.compareTo(rightValue) <= 0);
    } else if (rightOperand is DoubleState) {
      var rightValue = rightOperand.value;
      if (rightValue == null) {
        return BoolState.UNKNOWN_VALUE;
      }
      return BoolState.from(value!.toDouble() <= rightValue);
    }
    throw EvaluationException(CompileTimeErrorCode.CONST_EVAL_THROWS_EXCEPTION);
  }

  @override
  IntState logicalShiftRight(InstanceState rightOperand) {
    assertIntOrNull(rightOperand);
    if (value == null) {
      return UNKNOWN_VALUE;
    }
    if (rightOperand is IntState) {
      var rightValue = rightOperand.value;
      if (rightValue == null) {
        return UNKNOWN_VALUE;
      } else if (rightValue >= 64) {
        return IntState(0);
      } else if (rightValue >= 0) {
        // TODO(srawlins): Replace with real operator once stable, like:
        //     return new IntState(value >>> rightValue);
        return IntState(
            (value! >> rightValue) & ((1 << (64 - rightValue)) - 1));
      }
    }
    throw EvaluationException(CompileTimeErrorCode.CONST_EVAL_THROWS_EXCEPTION);
  }

  @override
  NumState minus(InstanceState rightOperand) {
    assertNumOrNull(rightOperand);
    if (value == null) {
      if (rightOperand is DoubleState) {
        return DoubleState.UNKNOWN_VALUE;
      }
      return UNKNOWN_VALUE;
    }
    if (rightOperand is IntState) {
      var rightValue = rightOperand.value;
      if (rightValue == null) {
        return UNKNOWN_VALUE;
      }
      return IntState(value! - rightValue);
    } else if (rightOperand is DoubleState) {
      var rightValue = rightOperand.value;
      if (rightValue == null) {
        return DoubleState.UNKNOWN_VALUE;
      }
      return DoubleState(value!.toDouble() - rightValue);
    }
    throw EvaluationException(CompileTimeErrorCode.CONST_EVAL_THROWS_EXCEPTION);
  }

  @override
  NumState negated() {
    if (value == null) {
      return UNKNOWN_VALUE;
    }
    return IntState(-value!);
  }

  @override
  NumState remainder(InstanceState rightOperand) {
    assertNumOrNull(rightOperand);
    if (value == null) {
      if (rightOperand is DoubleState) {
        return DoubleState.UNKNOWN_VALUE;
      }
      return UNKNOWN_VALUE;
    }
    if (rightOperand is IntState) {
      var rightValue = rightOperand.value;
      if (rightValue == null) {
        return UNKNOWN_VALUE;
      }
      if (rightValue != 0) {
        return IntState(value! % rightValue);
      }
    } else if (rightOperand is DoubleState) {
      var rightValue = rightOperand.value;
      if (rightValue == null) {
        return DoubleState.UNKNOWN_VALUE;
      }
      return DoubleState(value!.toDouble() % rightValue);
    }
    throw EvaluationException(CompileTimeErrorCode.CONST_EVAL_THROWS_EXCEPTION);
  }

  @override
  IntState shiftLeft(InstanceState rightOperand) {
    assertIntOrNull(rightOperand);
    if (value == null) {
      return UNKNOWN_VALUE;
    }
    if (rightOperand is IntState) {
      var rightValue = rightOperand.value;
      if (rightValue == null) {
        return UNKNOWN_VALUE;
      } else if (rightValue.bitLength > 31) {
        return UNKNOWN_VALUE;
      }
      if (rightValue >= 0) {
        return IntState(value! << rightValue);
      }
    }
    throw EvaluationException(CompileTimeErrorCode.CONST_EVAL_THROWS_EXCEPTION);
  }

  @override
  IntState shiftRight(InstanceState rightOperand) {
    assertIntOrNull(rightOperand);
    if (value == null) {
      return UNKNOWN_VALUE;
    }
    if (rightOperand is IntState) {
      var rightValue = rightOperand.value;
      if (rightValue == null) {
        return UNKNOWN_VALUE;
      } else if (rightValue.bitLength > 31) {
        return UNKNOWN_VALUE;
      }
      if (rightValue >= 0) {
        return IntState(value! >> rightValue);
      }
    }
    throw EvaluationException(CompileTimeErrorCode.CONST_EVAL_THROWS_EXCEPTION);
  }

  @override
  NumState times(InstanceState rightOperand) {
    assertNumOrNull(rightOperand);
    if (value == null) {
      if (rightOperand is DoubleState) {
        return DoubleState.UNKNOWN_VALUE;
      }
      return UNKNOWN_VALUE;
    }
    if (rightOperand is IntState) {
      var rightValue = rightOperand.value;
      if (rightValue == null) {
        return UNKNOWN_VALUE;
      }
      return IntState(value! * rightValue);
    } else if (rightOperand is DoubleState) {
      var rightValue = rightOperand.value;
      if (rightValue == null) {
        return DoubleState.UNKNOWN_VALUE;
      }
      return DoubleState(value!.toDouble() * rightValue);
    }
    throw EvaluationException(CompileTimeErrorCode.CONST_EVAL_THROWS_EXCEPTION);
  }

  @override
  String toString() => value == null ? "-unknown-" : value.toString();
}

/// The state of an object representing a list.
class ListState extends InstanceState {
  /// The elements of the list.
  final List<DartObjectImpl> _elements;

  /// Initialize a newly created state to represent a list with the given
  /// [elements].
  ListState(this._elements);

  @override
  int get hashCode {
    int value = 0;
    int count = _elements.length;
    for (int i = 0; i < count; i++) {
      value = (value << 3) ^ _elements[i].hashCode;
    }
    return value;
  }

  @override
  String get typeName => "List";

  @override
  bool operator ==(Object other) {
    if (other is ListState) {
      List<DartObjectImpl> otherElements = other._elements;
      int count = _elements.length;
      if (otherElements.length != count) {
        return false;
      } else if (count == 0) {
        return true;
      }
      for (int i = 0; i < count; i++) {
        if (_elements[i] != otherElements[i]) {
          return false;
        }
      }
      return true;
    }
    return false;
  }

  @override
  StringState convertToString() => StringState.UNKNOWN_VALUE;

  @override
  BoolState equalEqual(TypeSystemImpl typeSystem, InstanceState rightOperand) {
    assertBoolNumStringOrNull(rightOperand);
    return isIdentical(typeSystem, rightOperand);
  }

  @override
  bool hasPrimitiveEquality(FeatureSet featureSet) => true;

  @override
  BoolState isIdentical(TypeSystemImpl typeSystem, InstanceState rightOperand) {
    return BoolState.from(this == rightOperand);
  }

  @override
  String toString() {
    StringBuffer buffer = StringBuffer();
    buffer.write('[');
    bool first = true;
    for (var element in _elements) {
      if (first) {
        first = false;
      } else {
        buffer.write(', ');
      }
      buffer.write(element);
    }
    buffer.write(']');
    return buffer.toString();
  }
}

/// The state of an object representing a map.
class MapState extends InstanceState {
  /// The entries in the map.
  final Map<DartObjectImpl, DartObjectImpl> _entries;

  /// Initialize a newly created state to represent a map with the given
  /// [entries].
  MapState(this._entries);

  @override
  int get hashCode {
    int value = 0;
    for (DartObjectImpl key in _entries.keys.toSet()) {
      value = (value << 3) ^ key.hashCode;
    }
    return value;
  }

  @override
  String get typeName => "Map";

  @override
  bool operator ==(Object other) {
    if (other is MapState) {
      Map<DartObjectImpl, DartObjectImpl> otherElements = other._entries;
      int count = _entries.length;
      if (otherElements.length != count) {
        return false;
      } else if (count == 0) {
        return true;
      }
      for (DartObjectImpl key in _entries.keys) {
        var value = _entries[key];
        var otherValue = otherElements[key];
        if (value != otherValue) {
          return false;
        }
      }
      return true;
    }
    return false;
  }

  @override
  StringState convertToString() => StringState.UNKNOWN_VALUE;

  @override
  BoolState equalEqual(TypeSystemImpl typeSystem, InstanceState rightOperand) {
    assertBoolNumStringOrNull(rightOperand);
    return isIdentical(typeSystem, rightOperand);
  }

  @override
  bool hasPrimitiveEquality(FeatureSet featureSet) => true;

  @override
  BoolState isIdentical(TypeSystemImpl typeSystem, InstanceState rightOperand) {
    return BoolState.from(this == rightOperand);
  }

  @override
  String toString() {
    StringBuffer buffer = StringBuffer();
    buffer.write('{');
    bool first = true;
    _entries.forEach((DartObjectImpl key, DartObjectImpl value) {
      if (first) {
        first = false;
      } else {
        buffer.write(', ');
      }
      buffer.write(key);
      buffer.write(' = ');
      buffer.write(value);
    });
    buffer.write('}');
    return buffer.toString();
  }
}

/// The state of an object representing the value 'null'.
class NullState extends InstanceState {
  /// An instance representing the boolean value 'null'.
  static NullState NULL_STATE = NullState();

  @override
  int get hashCode => 0;

  @override
  bool get isBoolNumStringOrNull => true;

  @override
  bool get isNull => true;

  @override
  String get typeName => "Null";

  @override
  bool operator ==(Object other) => other is NullState;

  @override
  BoolState convertToBool() {
    throw EvaluationException(CompileTimeErrorCode.CONST_EVAL_THROWS_EXCEPTION);
  }

  @override
  StringState convertToString() => StringState("null");

  @override
  BoolState equalEqual(TypeSystemImpl typeSystem, InstanceState rightOperand) {
    assertBoolNumStringOrNull(rightOperand);
    return isIdentical(typeSystem, rightOperand);
  }

  @override
  bool hasPrimitiveEquality(FeatureSet featureSet) => true;

  @override
  BoolState isIdentical(TypeSystemImpl typeSystem, InstanceState rightOperand) {
    return BoolState.from(rightOperand is NullState);
  }

  @override
  BoolState logicalNot() {
    throw EvaluationException(CompileTimeErrorCode.CONST_EVAL_THROWS_EXCEPTION);
  }

  @override
  String toString() => "null";
}

/// The state of an object representing a number.
abstract class NumState extends InstanceState {
  @override
  bool get isBoolNumStringOrNull => true;

  @override
  BoolState equalEqual(TypeSystemImpl typeSystem, InstanceState rightOperand) {
    assertBoolNumStringOrNull(rightOperand);
    return isIdentical(typeSystem, rightOperand);
  }
}

/// The state of an object representing a record.
class RecordState extends InstanceState {
  /// The values of the positional fields.
  final List<DartObjectImpl> positionalFields;

  /// The values of the named fields.
  final Map<String, DartObjectImpl> namedFields;

  @override
  late final hashCode = Object.hashAll([
    ...positionalFields,
    ...namedFields.values,
  ]);

  /// Initialize a newly created state to represent a record with the given
  /// values of [positionalFields] and [namedFields].
  RecordState(this.positionalFields, this.namedFields);

  @override
  String get typeName => 'Record';

  @override
  bool operator ==(Object other) {
    if (other is! RecordState) {
      return false;
    }
    var positionalCount = positionalFields.length;
    var otherPositionalFields = other.positionalFields;
    if (otherPositionalFields.length != positionalCount) {
      return false;
    }
    var namedCount = namedFields.length;
    var otherNamedFields = other.namedFields;
    if (otherNamedFields.length != namedCount) {
      return false;
    }
    for (var i = 0; i < positionalCount; i++) {
      if (positionalFields[i] != otherPositionalFields[i]) {
        return false;
      }
    }
    for (var entry in namedFields.entries) {
      var otherValue = otherNamedFields[entry.key];
      if (otherValue == null) {
        return false;
      }
      if (entry.value != otherValue) {
        return false;
      }
    }
    return true;
  }

  @override
  // The behavior of `toString` is undefined.
  StringState convertToString() => StringState.UNKNOWN_VALUE;

  @override
  BoolState equalEqual(TypeSystemImpl typeSystem, InstanceState rightOperand) {
    return isIdentical(typeSystem, rightOperand);
  }

  /// Returns the value of the field with the given [name].
  DartObject? getField(String name) {
    final index = RecordTypeExtension.positionalFieldIndex(name);
    if (index != null && index < positionalFields.length) {
      return positionalFields[index];
    } else {
      return namedFields[name];
    }
  }

  @override
  bool hasPrimitiveEquality(FeatureSet featureSet) {
    return [...positionalFields, ...namedFields.values].every(
      (e) => e.hasPrimitiveEquality(featureSet),
    );
  }

  @override
  BoolState isIdentical(TypeSystemImpl typeSystem, InstanceState rightOperand) {
    if (this != rightOperand) {
      return BoolState.FALSE_STATE;
    }
    return BoolState.UNKNOWN_VALUE;
  }

  @override
  String toString() {
    var buffer = StringBuffer();
    buffer.write('(');
    bool first = true;
    for (var value in positionalFields) {
      if (first) {
        first = false;
      } else {
        buffer.write(', ');
      }
      buffer.write(value);
    }
    var entries = namedFields.entries.toList();
    if (entries.isNotEmpty) {
      entries.sort((first, second) => first.key.compareTo(second.key));
      if (!first) {
        buffer.write(', ');
        first = true;
      }
      buffer.write('{');
      for (var entry in entries) {
        if (first) {
          first = false;
        } else {
          buffer.write(', ');
        }
        buffer.write(entry.key);
        buffer.write(': ');
        buffer.write(entry.value);
      }
      buffer.write('}');
    }
    buffer.write(')');
    return buffer.toString();
  }
}

/// The state of an object representing a set.
class SetState extends InstanceState {
  /// The elements of the set.
  final Set<DartObjectImpl> _elements;

  /// Initialize a newly created state to represent a set with the given
  /// [elements].
  SetState(this._elements);

  @override
  int get hashCode {
    int value = 0;
    for (DartObjectImpl element in _elements) {
      value = (value << 3) ^ element.hashCode;
    }
    return value;
  }

  @override
  String get typeName => "Set";

  @override
  bool operator ==(Object other) {
    if (other is SetState) {
      List<DartObjectImpl> elements = _elements.toList();
      List<DartObjectImpl> otherElements = other._elements.toList();
      int count = elements.length;
      if (otherElements.length != count) {
        return false;
      } else if (count == 0) {
        return true;
      }
      for (int i = 0; i < count; i++) {
        if (elements[i] != otherElements[i]) {
          return false;
        }
      }
      return true;
    }
    return false;
  }

  @override
  StringState convertToString() => StringState.UNKNOWN_VALUE;

  @override
  BoolState equalEqual(TypeSystemImpl typeSystem, InstanceState rightOperand) {
    assertBoolNumStringOrNull(rightOperand);
    return isIdentical(typeSystem, rightOperand);
  }

  @override
  bool hasPrimitiveEquality(FeatureSet featureSet) => true;

  @override
  BoolState isIdentical(TypeSystemImpl typeSystem, InstanceState rightOperand) {
    return BoolState.from(this == rightOperand);
  }

  @override
  String toString() {
    StringBuffer buffer = StringBuffer();
    buffer.write('{');
    bool first = true;
    for (var element in _elements) {
      if (first) {
        first = false;
      } else {
        buffer.write(', ');
      }
      buffer.write(element);
    }
    buffer.write('}');
    return buffer.toString();
  }
}

/// The state of an object representing a string.
class StringState extends InstanceState {
  /// A state that can be used to represent a double whose value is not known.
  static StringState UNKNOWN_VALUE = StringState(null);

  /// The value of this instance.
  final String? value;

  /// Initialize a newly created state to represent the given [value].
  StringState(this.value);

  @override
  int get hashCode => value == null ? 0 : value.hashCode;

  @override
  bool get isBoolNumStringOrNull => true;

  @override
  bool get isUnknown => value == null;

  @override
  String get typeName => "String";

  @override
  bool operator ==(Object other) =>
      other is StringState && (value == other.value);

  @override
  StringState concatenate(InstanceState rightOperand) {
    if (value == null) {
      return UNKNOWN_VALUE;
    }
    if (rightOperand is StringState) {
      var rightValue = rightOperand.value;
      if (rightValue == null) {
        return UNKNOWN_VALUE;
      }
      return StringState("$value$rightValue");
    }
    return super.concatenate(rightOperand);
  }

  @override
  StringState convertToString() => this;

  @override
  BoolState equalEqual(TypeSystemImpl typeSystem, InstanceState rightOperand) {
    assertBoolNumStringOrNull(rightOperand);
    return isIdentical(typeSystem, rightOperand);
  }

  @override
  bool hasPrimitiveEquality(FeatureSet featureSet) => true;

  @override
  BoolState isIdentical(TypeSystemImpl typeSystem, InstanceState rightOperand) {
    if (value == null) {
      return BoolState.UNKNOWN_VALUE;
    }
    if (rightOperand is StringState) {
      var rightValue = rightOperand.value;
      if (rightValue == null) {
        return BoolState.UNKNOWN_VALUE;
      }
      return BoolState.from(value == rightValue);
    }
    return BoolState.FALSE_STATE;
  }

  @override
  IntState stringLength() {
    if (value == null) {
      return IntState.UNKNOWN_VALUE;
    }
    return IntState(value!.length);
  }

  @override
  String toString() => value == null ? "-unknown-" : "'$value'";
}

/// The state of an object representing a symbol.
class SymbolState extends InstanceState {
  /// The value of this instance.
  final String? value;

  /// Initialize a newly created state to represent the given [value].
  SymbolState(this.value);

  @override
  int get hashCode => value == null ? 0 : value.hashCode;

  @override
  String get typeName => "Symbol";

  @override
  bool operator ==(Object other) =>
      other is SymbolState && (value == other.value);

  @override
  StringState convertToString() {
    if (value == null) {
      return StringState.UNKNOWN_VALUE;
    }
    return StringState(value);
  }

  @override
  BoolState equalEqual(TypeSystemImpl typeSystem, InstanceState rightOperand) {
    assertBoolNumStringOrNull(rightOperand);
    return isIdentical(typeSystem, rightOperand);
  }

  @override
  bool hasPrimitiveEquality(FeatureSet featureSet) => true;

  @override
  BoolState isIdentical(TypeSystemImpl typeSystem, InstanceState rightOperand) {
    if (value == null) {
      return BoolState.UNKNOWN_VALUE;
    }
    if (rightOperand is SymbolState) {
      var rightValue = rightOperand.value;
      if (rightValue == null) {
        return BoolState.UNKNOWN_VALUE;
      }
      return BoolState.from(value == rightValue);
    }
    return BoolState.FALSE_STATE;
  }

  @override
  String toString() => value == null ? "-unknown-" : "#$value";
}

/// The state of an object representing a type.
class TypeState extends InstanceState {
  /// The element representing the type being modeled.
  final DartType? _type;

  /// Initialize a newly created state to represent the given [value].
  TypeState(this._type);

  @override
  int get hashCode => _type?.hashCode ?? 0;

  @override
  String get typeName => "Type";

  @override
  bool operator ==(Object other) =>
      other is TypeState && (_type == other._type);

  @override
  StringState convertToString() {
    if (_type == null) {
      return StringState.UNKNOWN_VALUE;
    }
    return StringState(_type!.getDisplayString(withNullability: false));
  }

  @override
  BoolState equalEqual(TypeSystemImpl typeSystem, InstanceState rightOperand) {
    assertBoolNumStringOrNull(rightOperand);
    return isIdentical(typeSystem, rightOperand);
  }

  @override
  bool hasPrimitiveEquality(FeatureSet featureSet) => true;

  @override
  BoolState isIdentical(TypeSystemImpl typeSystem, InstanceState rightOperand) {
    if (_type == null) {
      return BoolState.UNKNOWN_VALUE;
    }
    if (rightOperand is TypeState) {
      var rightType = rightOperand._type;
      if (rightType == null) {
        return BoolState.UNKNOWN_VALUE;
      }

      return BoolState.from(
        typeSystem.runtimeTypesEqual(_type!, rightType),
      );
    }
    return BoolState.FALSE_STATE;
  }

  @override
  String toString() {
    return _type?.getDisplayString(withNullability: true) ?? '-unknown-';
  }
}

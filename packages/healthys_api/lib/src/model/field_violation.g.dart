// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'field_violation.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$FieldViolationCWProxy {
  FieldViolation field(String? field);

  FieldViolation message(String? message);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `FieldViolation(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// FieldViolation(...).copyWith(id: 12, name: "My name")
  /// ````
  FieldViolation call({String? field, String? message});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfFieldViolation.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfFieldViolation.copyWith.fieldName(...)`
class _$FieldViolationCWProxyImpl implements _$FieldViolationCWProxy {
  const _$FieldViolationCWProxyImpl(this._value);

  final FieldViolation _value;

  @override
  FieldViolation field(String? field) => this(field: field);

  @override
  FieldViolation message(String? message) => this(message: message);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `FieldViolation(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// FieldViolation(...).copyWith(id: 12, name: "My name")
  /// ````
  FieldViolation call({
    Object? field = const $CopyWithPlaceholder(),
    Object? message = const $CopyWithPlaceholder(),
  }) {
    return FieldViolation(
      field: field == const $CopyWithPlaceholder()
          ? _value.field
          // ignore: cast_nullable_to_non_nullable
          : field as String?,
      message: message == const $CopyWithPlaceholder()
          ? _value.message
          // ignore: cast_nullable_to_non_nullable
          : message as String?,
    );
  }
}

extension $FieldViolationCopyWith on FieldViolation {
  /// Returns a callable class that can be used as follows: `instanceOfFieldViolation.copyWith(...)` or like so:`instanceOfFieldViolation.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$FieldViolationCWProxy get copyWith => _$FieldViolationCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FieldViolation _$FieldViolationFromJson(Map<String, dynamic> json) =>
    $checkedCreate('FieldViolation', json, ($checkedConvert) {
      final val = FieldViolation(
        field: $checkedConvert('field', (v) => v as String?),
        message: $checkedConvert('message', (v) => v as String?),
      );
      return val;
    });

Map<String, dynamic> _$FieldViolationToJson(FieldViolation instance) =>
    <String, dynamic>{'field': ?instance.field, 'message': ?instance.message};

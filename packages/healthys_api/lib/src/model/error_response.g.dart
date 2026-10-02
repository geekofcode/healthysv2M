// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'error_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ErrorResponseCWProxy {
  ErrorResponse timestamp(DateTime? timestamp);

  ErrorResponse status(int status);

  ErrorResponse error(String? error);

  ErrorResponse code(String? code);

  ErrorResponse message(String? message);

  ErrorResponse path(String? path);

  ErrorResponse correlationId(String? correlationId);

  ErrorResponse violations(List<FieldViolation> violations);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ErrorResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ErrorResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  ErrorResponse call({
    DateTime? timestamp,
    int status,
    String? error,
    String? code,
    String? message,
    String? path,
    String? correlationId,
    List<FieldViolation> violations,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfErrorResponse.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfErrorResponse.copyWith.fieldName(...)`
class _$ErrorResponseCWProxyImpl implements _$ErrorResponseCWProxy {
  const _$ErrorResponseCWProxyImpl(this._value);

  final ErrorResponse _value;

  @override
  ErrorResponse timestamp(DateTime? timestamp) => this(timestamp: timestamp);

  @override
  ErrorResponse status(int status) => this(status: status);

  @override
  ErrorResponse error(String? error) => this(error: error);

  @override
  ErrorResponse code(String? code) => this(code: code);

  @override
  ErrorResponse message(String? message) => this(message: message);

  @override
  ErrorResponse path(String? path) => this(path: path);

  @override
  ErrorResponse correlationId(String? correlationId) =>
      this(correlationId: correlationId);

  @override
  ErrorResponse violations(List<FieldViolation> violations) =>
      this(violations: violations);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ErrorResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ErrorResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  ErrorResponse call({
    Object? timestamp = const $CopyWithPlaceholder(),
    Object? status = const $CopyWithPlaceholder(),
    Object? error = const $CopyWithPlaceholder(),
    Object? code = const $CopyWithPlaceholder(),
    Object? message = const $CopyWithPlaceholder(),
    Object? path = const $CopyWithPlaceholder(),
    Object? correlationId = const $CopyWithPlaceholder(),
    Object? violations = const $CopyWithPlaceholder(),
  }) {
    return ErrorResponse(
      timestamp: timestamp == const $CopyWithPlaceholder()
          ? _value.timestamp
          // ignore: cast_nullable_to_non_nullable
          : timestamp as DateTime?,
      status: status == const $CopyWithPlaceholder()
          ? _value.status
          // ignore: cast_nullable_to_non_nullable
          : status as int,
      error: error == const $CopyWithPlaceholder()
          ? _value.error
          // ignore: cast_nullable_to_non_nullable
          : error as String?,
      code: code == const $CopyWithPlaceholder()
          ? _value.code
          // ignore: cast_nullable_to_non_nullable
          : code as String?,
      message: message == const $CopyWithPlaceholder()
          ? _value.message
          // ignore: cast_nullable_to_non_nullable
          : message as String?,
      path: path == const $CopyWithPlaceholder()
          ? _value.path
          // ignore: cast_nullable_to_non_nullable
          : path as String?,
      correlationId: correlationId == const $CopyWithPlaceholder()
          ? _value.correlationId
          // ignore: cast_nullable_to_non_nullable
          : correlationId as String?,
      violations: violations == const $CopyWithPlaceholder()
          ? _value.violations
          // ignore: cast_nullable_to_non_nullable
          : violations as List<FieldViolation>,
    );
  }
}

extension $ErrorResponseCopyWith on ErrorResponse {
  /// Returns a callable class that can be used as follows: `instanceOfErrorResponse.copyWith(...)` or like so:`instanceOfErrorResponse.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ErrorResponseCWProxy get copyWith => _$ErrorResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ErrorResponse _$ErrorResponseFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ErrorResponse', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['status', 'violations']);
      final val = ErrorResponse(
        timestamp: $checkedConvert(
          'timestamp',
          (v) => v == null ? null : DateTime.parse(v as String),
        ),
        status: $checkedConvert('status', (v) => (v as num).toInt()),
        error: $checkedConvert('error', (v) => v as String?),
        code: $checkedConvert('code', (v) => v as String?),
        message: $checkedConvert('message', (v) => v as String?),
        path: $checkedConvert('path', (v) => v as String?),
        correlationId: $checkedConvert('correlationId', (v) => v as String?),
        violations: $checkedConvert(
          'violations',
          (v) => (v as List<dynamic>)
              .map((e) => FieldViolation.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
      );
      return val;
    });

Map<String, dynamic> _$ErrorResponseToJson(ErrorResponse instance) =>
    <String, dynamic>{
      'timestamp': ?instance.timestamp?.toIso8601String(),
      'status': instance.status,
      'error': ?instance.error,
      'code': ?instance.code,
      'message': ?instance.message,
      'path': ?instance.path,
      'correlationId': ?instance.correlationId,
      'violations': instance.violations.map((e) => e.toJson()).toList(),
    };

//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:healthys_api/src/model/field_violation.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'error_response.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class ErrorResponse {
  /// Returns a new [ErrorResponse] instance.
  ErrorResponse({
    this.timestamp,

    required this.status,

    this.error,

    this.code,

    this.message,

    this.path,

    this.correlationId,

    required this.violations,
  });

  @JsonKey(name: r'timestamp', required: false, includeIfNull: false)
  final DateTime? timestamp;

  @JsonKey(name: r'status', required: true, includeIfNull: false)
  final int status;

  @JsonKey(name: r'error', required: false, includeIfNull: false)
  final String? error;

  @JsonKey(name: r'code', required: false, includeIfNull: false)
  final String? code;

  @JsonKey(name: r'message', required: false, includeIfNull: false)
  final String? message;

  @JsonKey(name: r'path', required: false, includeIfNull: false)
  final String? path;

  @JsonKey(name: r'correlationId', required: false, includeIfNull: false)
  final String? correlationId;

  @JsonKey(name: r'violations', required: true, includeIfNull: false)
  final List<FieldViolation> violations;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ErrorResponse &&
          other.timestamp == timestamp &&
          other.status == status &&
          other.error == error &&
          other.code == code &&
          other.message == message &&
          other.path == path &&
          other.correlationId == correlationId &&
          other.violations == violations;

  @override
  int get hashCode =>
      timestamp.hashCode +
      status.hashCode +
      error.hashCode +
      code.hashCode +
      message.hashCode +
      path.hashCode +
      correlationId.hashCode +
      violations.hashCode;

  factory ErrorResponse.fromJson(Map<String, dynamic> json) =>
      _$ErrorResponseFromJson(json);

  Map<String, dynamic> toJson() => _$ErrorResponseToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

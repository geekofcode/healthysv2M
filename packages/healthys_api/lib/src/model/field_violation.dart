//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'field_violation.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class FieldViolation {
  /// Returns a new [FieldViolation] instance.
  FieldViolation({this.field, this.message});

  @JsonKey(name: r'field', required: false, includeIfNull: false)
  final String? field;

  @JsonKey(name: r'message', required: false, includeIfNull: false)
  final String? message;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FieldViolation &&
          other.field == field &&
          other.message == message;

  @override
  int get hashCode => field.hashCode + message.hashCode;

  factory FieldViolation.fromJson(Map<String, dynamic> json) =>
      _$FieldViolationFromJson(json);

  Map<String, dynamic> toJson() => _$FieldViolationToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

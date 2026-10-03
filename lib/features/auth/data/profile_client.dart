import 'package:dio/dio.dart';
import '../domain/session.dart';

class DioProfileClient implements ProfileClient {
  DioProfileClient(this.dio);
  final Dio dio;
  @override
  Future<MobileProfile> fetch(String token) async {
    final response = await dio.get<Map<String, dynamic>>(
      'persons/me',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    final data = response.data;
    if (data == null ||
        data['id'] is! String ||
        (data['id'] as String).isEmpty) {
      throw const FormatException('Missing profile identity');
    }
    return MobileProfile(Map<String, dynamic>.unmodifiable(data));
  }
}

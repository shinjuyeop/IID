import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:w5_flutter_app/services/api_client.dart';

void main() {
  group('ApiClient', () {
    test('should fetch data successfully', () async {
      // Arrange
      final mock = MockClient((req) async {
        if (req.url.path.endsWith('/status')) {
          return http.Response(jsonEncode({
            'temperature': 24.5,
            'humidity': 50.0,
            'distance': 30.0,
            'led_status': [1, 0, 1],
            'auto_mode': true,
          }), 200);
        }
        return http.Response('Not found', 404);
      });

      final api = ApiClient(baseUrl: 'http://localhost:8080', httpClient: mock);

      // Act
      final result = await api.fetchData();

      // Assert
      expect(result, isA<Status>());
      expect(result.autoMode, true);
      expect(result.ledStatus.length, 3);
    });

    test('should throw on server error', () async {
      // Arrange
      final mock = MockClient((req) async => http.Response('err', 500));
      final api = ApiClient(baseUrl: 'http://localhost:8080', httpClient: mock);

      // Assert
      expect(() => api.fetchData(), throwsA(isA<ApiException>()));
    });
  });
}
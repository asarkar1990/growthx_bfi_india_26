import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:carepath_india/src/care_plan_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('CarePlanApi', () {
    test('normalizes trailing slashes and handles default URL', () {
      final api = CarePlanApi(baseUrl: 'http://127.0.0.1:8000/');
      expect(api.baseUrl, 'http://127.0.0.1:8000');
    });

    test('checkHealth returns true on 200 and false on error', () async {
      final healthyClient = MockClient((request) async {
        if (request.url.path == '/health') {
          return http.Response('{"status": "ok"}', 200);
        }
        return http.Response('Not found', 404);
      });

      final healthyApi = CarePlanApi(
        httpClient: healthyClient,
        baseUrl: 'http://127.0.0.1:8000',
      );
      expect(await healthyApi.checkHealth(), isTrue);

      final failingClient = MockClient((request) async {
        return http.Response('Server Error', 500);
      });
      final failingApi = CarePlanApi(
        httpClient: failingClient,
        baseUrl: 'http://127.0.0.1:8000',
      );
      expect(await failingApi.checkHealth(), isFalse);
    });

    test('createPlan sends multipart request and parses valid plan', () async {
      final rawJson = await File(
        'assets/samples/sample_plan_en.json',
      ).readAsString();
      final samplePlanMap = jsonDecode(rawJson) as Map<String, dynamic>;

      final client = MockClient((request) async {
        expect(request.url.path, '/api/v1/plans');
        expect(request.method, 'POST');
        return http.Response(
          jsonEncode({
            'plan': samplePlanMap,
            'meta': {'isSample': false},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final api = CarePlanApi(
        httpClient: client,
        baseUrl: 'http://127.0.0.1:8000',
      );
      final plan = await api.createPlan(
        language: 'en',
        useSample: false,
        fileName: 'discharge.pdf',
        fileBytes: Uint8List.fromList([1, 2, 3]),
      );

      expect(plan.patientName, 'Mr. Arindam Sarkar');
      expect(plan.language, 'en');
      expect(plan.items.isNotEmpty, isTrue);
    });

    test('createPlan throws ApiException with backend error envelope', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'error': {
              'code': 'MODEL_UNAVAILABLE',
              'message':
                  'Document processing is temporarily unavailable. Try the sample document.',
            },
          }),
          503,
          headers: {'content-type': 'application/json'},
        );
      });

      final api = CarePlanApi(
        httpClient: client,
        baseUrl: 'http://127.0.0.1:8000',
      );

      expect(
        () => api.createPlan(
          language: 'en',
          useSample: false,
          fileName: 'discharge.pdf',
          fileBytes: Uint8List.fromList([1, 2, 3]),
        ),
        throwsA(
          isA<ApiException>()
              .having((e) => e.code, 'code', 'MODEL_UNAVAILABLE')
              .having((e) => e.statusCode, 'statusCode', 503)
              .having(
                (e) => e.message,
                'message',
                contains('Document processing is temporarily unavailable'),
              ),
        ),
      );
    });
  });
}

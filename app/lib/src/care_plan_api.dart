import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import 'models.dart';

class ApiException implements Exception {
  const ApiException({
    required this.code,
    required this.message,
    required this.statusCode,
  });

  final String code;
  final String message;
  final int statusCode;

  @override
  String toString() => '$code ($statusCode): $message';
}

class CarePlanApi {
  CarePlanApi({http.Client? httpClient, String? baseUrl})
    : _client = httpClient ?? http.Client(),
      baseUrl = normalizeBaseUrl(baseUrl ?? defaultApiBaseUrl());

  final http.Client _client;
  final String baseUrl;

  static const String envBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );

  static String normalizeBaseUrl(String url) {
    var clean = url.trim();
    if (clean.endsWith('/')) {
      clean = clean.substring(0, clean.length - 1);
    }
    return clean;
  }

  static String defaultApiBaseUrl() {
    final url = normalizeBaseUrl(envBaseUrl);
    // When running inside an Android emulator, loopback 127.0.0.1 points to the laptop via 10.0.2.2
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      if (url.contains('127.0.0.1')) {
        return url.replaceAll('127.0.0.1', '10.0.2.2');
      }
      if (url.contains('localhost')) {
        return url.replaceAll('localhost', '10.0.2.2');
      }
    }
    return url;
  }

  Uri _uri(String path) {
    final cleanPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$baseUrl$cleanPath');
  }

  Future<bool> checkHealth({
    Duration timeout = const Duration(seconds: 4),
  }) async {
    try {
      final response = await _client.get(_uri('/health')).timeout(timeout);
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<DischargePlan> createPlan({
    required String language,
    bool useSample = false,
    String? fileName,
    Uint8List? fileBytes,
    Duration timeout = const Duration(seconds: 120),
  }) async {
    final uri = _uri('/api/v1/plans');
    final request = http.MultipartRequest('POST', uri);
    request.fields['language'] = language;
    request.fields['useSample'] = useSample ? 'true' : 'false';

    if (!useSample && fileBytes != null && fileName != null) {
      final ext = fileName.split('.').last.toLowerCase();
      final mimeType = switch (ext) {
        'pdf' => MediaType('application', 'pdf'),
        'png' => MediaType('image', 'png'),
        'jpg' || 'jpeg' => MediaType('image', 'jpeg'),
        _ => MediaType('application', 'octet-stream'),
      };
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          fileBytes,
          filename: fileName,
          contentType: mimeType,
        ),
      );
    }

    http.StreamedResponse streamedResponse;
    try {
      final future = _client.send(request);
      streamedResponse = await future.timeout(timeout);
    } on Exception {
      throw ApiException(
        code: 'CONNECTION_ERROR',
        message:
            'Could not reach backend at $baseUrl. Ensure your backend server is running on your laptop.',
        statusCode: 0,
      );
    }

    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final body =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final planJson = body['plan'] as Map<String, dynamic>;
      return DischargePlan.fromJson(planJson);
    }

    try {
      final body =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      if (body.containsKey('error')) {
        final err = body['error'] as Map<String, dynamic>;
        throw ApiException(
          code: err['code'] as String? ?? 'UNKNOWN_ERROR',
          message: err['message'] as String? ?? 'An unexpected error occurred.',
          statusCode: response.statusCode,
        );
      }
    } on FormatException {
      // Body was not JSON formatted
    }

    throw ApiException(
      code: 'HTTP_${response.statusCode}',
      message:
          'Server returned ${response.statusCode}: ${response.reasonPhrase ?? "Request failed"}',
      statusCode: response.statusCode,
    );
  }
}

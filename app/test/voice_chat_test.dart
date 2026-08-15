import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:carepath_india/main.dart';
import 'package:carepath_india/src/care_plan_api.dart';
import 'package:carepath_india/src/care_plan_cubit.dart';
import 'package:carepath_india/src/models.dart';
import 'package:carepath_india/src/storage_service.dart';
import 'package:carepath_india/src/voice_chat_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class FakeWebSocketChannel implements WebSocketChannel {
  final StreamController<dynamic> _controller =
      StreamController<dynamic>.broadcast();
  final List<dynamic> sent = [];

  @override
  Stream get stream => _controller.stream;

  @override
  WebSocketSink get sink => _FakeSink(this);

  void emitFromServer(dynamic data) {
    _controller.add(data);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSink implements WebSocketSink {
  _FakeSink(this._channel);
  final FakeWebSocketChannel _channel;

  @override
  void add(dynamic data) {
    _channel.sent.add(data);
  }

  @override
  Future close([int? closeCode, String? closeReason]) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sampleJson = File(
    'assets/samples/sample_plan_en.json',
  ).readAsStringSync();
  final sampleMap = jsonDecode(sampleJson) as Map<String, dynamic>;
  final testPlan = DischargePlan.fromJson(sampleMap);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'VoiceChatCubit initializes session, sends text, and receives transcripts',
    () async {
      final fakeChannel = FakeWebSocketChannel();
      final cubit = VoiceChatCubit(channelFactory: (uri) => fakeChannel);

      cubit.initSession(testPlan, apiBaseUrl: 'http://127.0.0.1:8000');

      expect(cubit.state.status, VoiceStatus.active);
      expect(cubit.state.messages, hasLength(1));
      expect(cubit.state.messages.first.role, 'model');

      // Send user message
      cubit.sendTextMessage('When do I take Taxim-O?');
      expect(cubit.state.messages, hasLength(2));
      expect(cubit.state.messages.last.text, 'When do I take Taxim-O?');
      expect(fakeChannel.sent, hasLength(1));

      // Emit streaming transcript from server
      fakeChannel.emitFromServer(
        jsonEncode({
          'type': 'transcript',
          'role': 'model',
          'text': 'Take Taxim-O in the morning and evening after food.',
        }),
      );

      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(cubit.state.messages, hasLength(3));
      expect(
        cubit.state.messages.last.text,
        'Take Taxim-O in the morning and evening after food.',
      );
      expect(cubit.state.status, VoiceStatus.speaking);

      // Mute toggle
      cubit.toggleMute();
      expect(cubit.state.isMuted, isTrue);
      cubit.toggleMute();
      expect(cubit.state.isMuted, isFalse);

      // Disconnect
      cubit.disconnect();
      expect(cubit.state.status, VoiceStatus.disconnected);
    },
  );

  testWidgets(
    'Center microphone button opens VoiceChatScreen and handles interactions',
    (tester) async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'plan': sampleMap,
            'meta': {'isSample': true},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final cubit = CarePlanCubit(
        api: CarePlanApi(
          httpClient: mockClient,
          baseUrl: 'http://127.0.0.1:8000',
        ),
        storage: CarePlanStorage(),
      );

      await tester.pumpWidget(CarePathApp(cubit: cubit));

      // Create and activate plan
      cubit.useSample();
      unawaited(cubit.createPlan(stageDelay: const Duration(milliseconds: 10)));
      await tester.pump(const Duration(milliseconds: 15));
      await tester.pump(const Duration(milliseconds: 15));
      await tester.pump(const Duration(milliseconds: 50));

      await tester.ensureVisible(find.text('Confirm & Activate Recovery Plan'));
      await tester.tap(find.text('Confirm & Activate Recovery Plan'));
      await tester.pumpAndSettle();

      // Verify center mic button exists in bottom bar
      final micButton = find.byIcon(Icons.mic_rounded);
      expect(micButton, findsOneWidget);

      // Tap center mic button
      await tester.tap(micButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // VoiceChatScreen is now displayed
      expect(find.text('Mr. Arindam Sarkar'), findsOneWidget);
      expect(find.text('Aster Whitefield Hospital'), findsWidgets);
      expect(find.text('Morning Medicines ☀️'), findsOneWidget);

      // Tap a suggestion chip
      await tester.tap(find.text('Morning Medicines ☀️'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.text('What medications do I take in the morning?'),
        findsOneWidget,
      );

      // Close voice screen
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      // Back to plan screen
      expect(find.text('Mr. Arindam Sarkar’s Recovery Plan'), findsOneWidget);
    },
  );
}

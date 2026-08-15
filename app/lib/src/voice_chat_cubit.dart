import 'dart:async';
import 'dart:convert';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'models.dart';

enum VoiceStatus {
  idle,
  connecting,
  active,
  listening,
  speaking,
  error,
  disconnected,
}

class VoiceMessage extends Equatable {
  const VoiceMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.timestamp,
    this.isStreaming = false,
  });

  final String id;
  final String role; // 'user', 'model', 'system'
  final String text;
  final DateTime timestamp;
  final bool isStreaming;

  VoiceMessage copyWith({
    String? id,
    String? role,
    String? text,
    DateTime? timestamp,
    bool? isStreaming,
  }) {
    return VoiceMessage(
      id: id ?? this.id,
      role: role ?? this.role,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      isStreaming: isStreaming ?? this.isStreaming,
    );
  }

  @override
  List<Object?> get props => [id, role, text, timestamp, isStreaming];
}

class VoiceChatState extends Equatable {
  const VoiceChatState({
    this.status = VoiceStatus.idle,
    this.isMuted = false,
    this.messages = const [],
    this.errorMessage,
    this.activePlan,
  });

  final VoiceStatus status;
  final bool isMuted;
  final List<VoiceMessage> messages;
  final String? errorMessage;
  final DischargePlan? activePlan;

  VoiceChatState copyWith({
    VoiceStatus? status,
    bool? isMuted,
    List<VoiceMessage>? messages,
    String? errorMessage,
    DischargePlan? activePlan,
    bool clearError = false,
  }) {
    return VoiceChatState(
      status: status ?? this.status,
      isMuted: isMuted ?? this.isMuted,
      messages: messages ?? this.messages,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      activePlan: activePlan ?? this.activePlan,
    );
  }

  @override
  List<Object?> get props => [
    status,
    isMuted,
    messages,
    errorMessage,
    activePlan,
  ];
}

class VoiceChatCubit extends Cubit<VoiceChatState> {
  VoiceChatCubit({this.channelFactory}) : super(const VoiceChatState());

  final WebSocketChannel Function(Uri)? channelFactory;
  WebSocketChannel? _channel;
  StreamSubscription? _sub;

  void initSession(DischargePlan plan, {required String apiBaseUrl}) {
    emit(
      state.copyWith(
        activePlan: plan,
        status: VoiceStatus.connecting,
        clearError: true,
      ),
    );
    _connectWebSocket(apiBaseUrl, plan);
  }

  void _connectWebSocket(String apiBaseUrl, DischargePlan plan) {
    try {
      final base = apiBaseUrl
          .replaceAll('http://', 'ws://')
          .replaceAll('https://', 'wss://');
      final uri = Uri.parse(
        '$base/ws/voice-chat/${plan.patientName.replaceAll(" ", "_")}',
      );

      final channel = channelFactory != null
          ? channelFactory!(uri)
          : WebSocketChannel.connect(uri);
      _channel = channel;

      // Welcome message
      final welcome = VoiceMessage(
        id: 'msg_welcome',
        role: 'model',
        text:
            'Hello! I am your CarePath voice assistant for ${plan.patientName}’s discharge recovery plan. How can I help you today?',
        timestamp: DateTime.now(),
      );

      emit(state.copyWith(status: VoiceStatus.active, messages: [welcome]));

      _sub = channel.stream.listen(
        (data) {
          _handleIncomingData(data);
        },
        onError: (err) {
          emit(
            state.copyWith(
              status: VoiceStatus.error,
              errorMessage: 'Voice connection error: $err',
            ),
          );
        },
        onDone: () {
          if (state.status != VoiceStatus.disconnected) {
            emit(state.copyWith(status: VoiceStatus.disconnected));
          }
        },
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: VoiceStatus.error,
          errorMessage: 'Unable to open live voice socket: $e',
        ),
      );
    }
  }

  void _handleIncomingData(dynamic data) {
    try {
      if (data is String) {
        final json = jsonDecode(data) as Map<String, dynamic>;
        final type = json['type'] as String?;

        if (type == 'transcript') {
          final text = json['text'] as String? ?? '';
          final role = json['role'] as String? ?? 'model';
          _appendOrUpdateModelMessage(text, role: role);
          emit(state.copyWith(status: VoiceStatus.speaking));
        } else if (type == 'turn_complete') {
          emit(state.copyWith(status: VoiceStatus.listening));
        } else if (type == 'error') {
          emit(
            state.copyWith(
              status: VoiceStatus.error,
              errorMessage: json['message'] as String? ?? 'Voice server error',
            ),
          );
        }
      }
    } catch (_) {}
  }

  void _appendOrUpdateModelMessage(String text, {required String role}) {
    final list = List<VoiceMessage>.from(state.messages);
    if (list.isNotEmpty && list.last.role == role && list.last.isStreaming) {
      final updated = list.last.copyWith(text: list.last.text + text);
      list[list.length - 1] = updated;
    } else {
      list.add(
        VoiceMessage(
          id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
          role: role,
          text: text,
          timestamp: DateTime.now(),
          isStreaming: true,
        ),
      );
    }
    emit(state.copyWith(messages: list));
  }

  void sendTextMessage(String text) {
    if (text.trim().isEmpty) return;
    final userMsg = VoiceMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      role: 'user',
      text: text.trim(),
      timestamp: DateTime.now(),
    );

    final updated = List<VoiceMessage>.from(state.messages)..add(userMsg);
    emit(state.copyWith(messages: updated, status: VoiceStatus.speaking));

    try {
      _channel?.sink.add(jsonEncode({'type': 'text', 'text': text.trim()}));
    } catch (e) {
      emit(state.copyWith(errorMessage: 'Failed to send message: $e'));
    }
  }

  void toggleMute() {
    emit(state.copyWith(isMuted: !state.isMuted));
  }

  void disconnect() {
    _sub?.cancel();
    _channel?.sink.close();
    emit(state.copyWith(status: VoiceStatus.disconnected));
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    _channel?.sink.close();
    return super.close();
  }
}

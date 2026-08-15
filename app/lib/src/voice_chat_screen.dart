import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'care_plan_cubit.dart';
import 'models.dart';
import 'theme.dart';
import 'voice_chat_cubit.dart';

class VoiceChatScreen extends StatefulWidget {
  const VoiceChatScreen({required this.plan, super.key});
  final DischargePlan plan;

  @override
  State<VoiceChatScreen> createState() => _VoiceChatScreenState();
}

class _VoiceChatScreenState extends State<VoiceChatScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    final apiBaseUrl = context.read<CarePlanCubit>().state.apiBaseUrl;
    context.read<VoiceChatCubit>().initSession(
      widget.plan,
      apiBaseUrl: apiBaseUrl,
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<VoiceChatCubit, VoiceChatState>(
      listener: (context, state) {
        _scrollToBottom();
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor: const Color(0xFF0C0916),
          appBar: AppBar(
            backgroundColor: const Color(0xFF130E22),
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            leading: IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () {
                context.read<VoiceChatCubit>().disconnect();
                Navigator.of(context).pop();
              },
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      widget.plan.patientName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _StatusBadge(status: state.status, isMuted: state.isMuted),
                  ],
                ),
                Text(
                  widget.plan.hospital,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF9C93AC),
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: state.isMuted
                    ? 'Unmute microphone'
                    : 'Mute microphone',
                icon: Icon(
                  state.isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                  color: state.isMuted ? Colors.redAccent : AppTheme.lavender,
                ),
                onPressed: () => context.read<VoiceChatCubit>().toggleMute(),
              ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                // Top Waveform / Visualizer
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 20,
                    horizontal: 24,
                  ),
                  decoration: const BoxDecoration(
                    color: Color(0xFF130E22),
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(24),
                    ),
                  ),
                  child: Column(
                    children: [
                      _WaveformVisualizer(
                        anim: _animController,
                        status: state.status,
                        isMuted: state.isMuted,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _statusText(state.status, state.isMuted),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.lavender,
                        ),
                      ),
                    ],
                  ),
                ),

                // Conversation Transcript Feed
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    itemCount: state.messages.length,
                    itemBuilder: (context, index) {
                      final msg = state.messages[index];
                      return _MessageBubble(message: msg);
                    },
                  ),
                ),

                // Suggestion Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      _SuggestionChip(
                        label: 'Morning Medicines ☀️',
                        onTap: () =>
                            context.read<VoiceChatCubit>().sendTextMessage(
                              'What medications do I take in the morning?',
                            ),
                      ),
                      const SizedBox(width: 8),
                      _SuggestionChip(
                        label: 'Follow-up Visits 📅',
                        onTap: () =>
                            context.read<VoiceChatCubit>().sendTextMessage(
                              'When is my next hospital OPD follow up?',
                            ),
                      ),
                      const SizedBox(width: 8),
                      _SuggestionChip(
                        label: 'Warning Signs ⚠️',
                        onTap: () =>
                            context.read<VoiceChatCubit>().sendTextMessage(
                              'What are the warning signs I should watch out for?',
                            ),
                      ),
                      const SizedBox(width: 8),
                      _SuggestionChip(
                        label: 'Diet Advice 🥗',
                        onTap: () =>
                            context.read<VoiceChatCubit>().sendTextMessage(
                              'What are my dietary restrictions?',
                            ),
                      ),
                    ],
                  ),
                ),

                // Bottom Control & Input Bar
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                  decoration: const BoxDecoration(
                    color: Color(0xFF130E22),
                    border: Border(
                      top: BorderSide(color: Color(0xFF281E40), width: 1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _textController,
                          decoration: InputDecoration(
                            hintText: 'Ask voice assistant or type query…',
                            hintStyle: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF8E86A2),
                            ),
                            filled: true,
                            fillColor: const Color(0xFF0C0916),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: const BorderSide(
                                color: Color(0xFF2E224E),
                              ),
                            ),
                          ),
                          onSubmitted: (val) {
                            if (val.trim().isNotEmpty) {
                              context.read<VoiceChatCubit>().sendTextMessage(
                                val,
                              );
                              _textController.clear();
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton.filled(
                        style: IconButton.styleFrom(
                          backgroundColor: AppTheme.violet,
                        ),
                        icon: const Icon(Icons.send_rounded, size: 18),
                        onPressed: () {
                          if (_textController.text.trim().isNotEmpty) {
                            context.read<VoiceChatCubit>().sendTextMessage(
                              _textController.text,
                            );
                            _textController.clear();
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _statusText(VoiceStatus status, bool isMuted) {
    if (isMuted) return 'Microphone is muted';
    return switch (status) {
      VoiceStatus.connecting => 'Connecting to Gemini Live…',
      VoiceStatus.active ||
      VoiceStatus.listening => 'Listening… Speak naturally or tap a question',
      VoiceStatus.speaking => 'Gemini is speaking…',
      VoiceStatus.error => 'Connection issue. Retry query below.',
      VoiceStatus.disconnected => 'Call ended',
      _ => 'Ready to talk',
    };
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status, required this.isMuted});
  final VoiceStatus status;
  final bool isMuted;

  @override
  Widget build(BuildContext context) {
    final (color, label) = isMuted
        ? (Colors.redAccent, 'MUTED')
        : switch (status) {
            VoiceStatus.speaking => (Colors.greenAccent, 'LIVE'),
            VoiceStatus.active ||
            VoiceStatus.listening => (AppTheme.lavender, 'LISTENING'),
            VoiceStatus.connecting => (Colors.amberAccent, 'CONNECTING'),
            VoiceStatus.error => (Colors.redAccent, 'ERROR'),
            _ => (Colors.grey, 'OFFLINE'),
          };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w900,
          letterSpacing: .6,
          color: color,
        ),
      ),
    );
  }
}

class _WaveformVisualizer extends StatelessWidget {
  const _WaveformVisualizer({
    required this.anim,
    required this.status,
    required this.isMuted,
  });

  final Animation<double> anim;
  final VoiceStatus status;
  final bool isMuted;

  @override
  Widget build(BuildContext context) {
    final active =
        (status == VoiceStatus.speaking || status == VoiceStatus.active) &&
        !isMuted;

    return AnimatedBuilder(
      animation: anim,
      builder: (context, _) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(9, (index) {
            final phase = index * 0.4;
            final dynamicHeight = active
                ? 14.0 + 26.0 * (sin(anim.value * 2 * pi + phase).abs())
                : (status == VoiceStatus.listening
                      ? 8.0 + 8.0 * (sin(anim.value * pi + phase).abs())
                      : 6.0);

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: 5,
              height: dynamicHeight,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: isMuted
                      ? [
                          Colors.redAccent.withValues(alpha: 0.5),
                          Colors.redAccent,
                        ]
                      : [AppTheme.violet, AppTheme.lavender],
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});
  final VoiceMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF2A1C52),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.auto_awesome,
                color: AppTheme.lavender,
                size: 16,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser
                    ? const Color(0xFF7C3AED)
                    : const Color(0xFF1B152B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isUser ? Colors.transparent : const Color(0xFF332554),
                ),
              ),
              child: Text(
                message.text,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.45,
                  color: isUser ? Colors.white : const Color(0xFFE2DCED),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      backgroundColor: const Color(0xFF1B152B),
      side: const BorderSide(color: Color(0xFF3A295E)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      label: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          color: AppTheme.lavender,
          fontWeight: FontWeight.w600,
        ),
      ),
      onPressed: onTap,
    );
  }
}

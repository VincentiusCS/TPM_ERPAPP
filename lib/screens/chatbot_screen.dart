import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../routes/app_routes.dart';
import '../services/chatbot_service.dart';
import '../widgets/animated_character.dart';
import '../widgets/app_bottom_nav.dart';

/// A chat message model for the UI.
class _ChatMessage {
  final String text;
  final bool isUser;

  _ChatMessage({required this.text, required this.isUser});
}

class ChatbotScreen extends StatefulWidget {
  final ChatbotService chatbotService;

  const ChatbotScreen({super.key, required this.chatbotService});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  // Gyroscope shake detection
  StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;
  DateTime? _lastShakeTime;
  static const double _shakeThreshold = 10.0;
  static const Duration _shakeCooldown = Duration(seconds: 3);

  // Scenario selection state
  List<Map<String, dynamic>> _scenarios = [];
  bool _loadingScenarios = true;
  String? _scenarioError;

  // Chat state
  String? _selectedScenarioId;
  String? _selectedScenarioName;
  String _sessionId = '';
  final List<_ChatMessage> _messages = [];
  bool _sendingMessage = false;
  bool _sessionEnded = false;
  String? _feedback;
  bool _loadingFeedback = false;

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadScenarios();
  }

  @override
  void dispose() {
    _gyroscopeSubscription?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _generateSessionId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random();
    final chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final suffix = List.generate(8, (_) => chars[random.nextInt(chars.length)]).join();
    return '$timestamp-$suffix';
  }

  void _startGyroscopeListener() {
    _gyroscopeSubscription?.cancel();
    try {
      _gyroscopeSubscription = gyroscopeEventStream().listen((GyroscopeEvent event) {
        final magnitude = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
        if (magnitude > _shakeThreshold) {
          final now = DateTime.now();
          if (_lastShakeTime == null || now.difference(_lastShakeTime!) > _shakeCooldown) {
            _lastShakeTime = now;
            resetSession();
          }
        }
      });
    } on PlatformException {
      _gyroscopeSubscription = null;
    }
  }

  void _stopGyroscopeListener() {
    _gyroscopeSubscription?.cancel();
    _gyroscopeSubscription = null;
  }

  Future<void> _loadScenarios() async {
    setState(() { _loadingScenarios = true; _scenarioError = null; });
    try {
      final scenarios = await widget.chatbotService.getScenarios();
      setState(() { _scenarios = scenarios; _loadingScenarios = false; });
    } on DioException catch (e) {
      setState(() { _loadingScenarios = false; _scenarioError = e.response?.data?['message'] ?? 'Gagal memuat skenario'; });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_scenarioError!), action: SnackBarAction(label: 'Coba Lagi', onPressed: _loadScenarios)));
      }
    }
  }

  void _selectScenario(Map<String, dynamic> scenario) {
    setState(() {
      _selectedScenarioId = scenario['id'] as String;
      _selectedScenarioName = scenario['name'] as String;
      _sessionId = _generateSessionId();
      _messages.clear();
      _sessionEnded = false;
      _feedback = null;
    });
    _startGyroscopeListener();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _sendingMessage || _sessionEnded) return;
    _messageController.clear();
    setState(() { _messages.add(_ChatMessage(text: text, isUser: true)); _sendingMessage = true; });
    _scrollToBottom();
    try {
      final response = await widget.chatbotService.sendMessage(scenarioId: _selectedScenarioId!, sessionId: _sessionId, message: text);
      final reply = response['reply'] as String? ?? '';
      if (response['session_id'] != null) _sessionId = response['session_id'] as String;
      setState(() { _messages.add(_ChatMessage(text: reply, isUser: false)); _sendingMessage = false; });
      _scrollToBottom();
    } on DioException catch (e) {
      setState(() { _sendingMessage = false; });
      if (mounted) {
        final errorMsg = e.response?.data?['message'] ?? 'Gagal mengirim pesan';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMsg), action: SnackBarAction(label: 'Coba Lagi', onPressed: () { _messageController.text = text; _sendMessage(); })));
      }
    }
  }

  Future<void> _endSession() async {
    setState(() { _sessionEnded = true; _loadingFeedback = true; });
    try {
      final response = await widget.chatbotService.getFeedback(sessionId: _sessionId);
      setState(() { _feedback = response['feedback'] as String? ?? 'Tidak ada feedback.'; _loadingFeedback = false; });
      _scrollToBottom();
    } on DioException catch (e) {
      setState(() { _loadingFeedback = false; _sessionEnded = false; });
      if (mounted) {
        final errorMsg = e.response?.data?['message'] ?? 'Gagal mendapatkan feedback';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMsg), action: SnackBarAction(label: 'Coba Lagi', onPressed: _endSession)));
      }
    }
  }

  void resetSession() {
    _stopGyroscopeListener();
    setState(() { _selectedScenarioId = null; _selectedScenarioName = null; _sessionId = ''; _messages.clear(); _sessionEnded = false; _feedback = null; });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF8F8),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            Expanded(
              child: _selectedScenarioId == null ? _buildScenarioList() : _buildChatUI(),
            ),
            if (_selectedScenarioId == null || _sessionEnded)
              const AppBottomNav(activeIndex: 4),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Container(width: 36, height: 36, decoration: BoxDecoration(color: const Color(0xFF1C1B1B), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.person, color: Colors.white, size: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _selectedScenarioId != null ? (_selectedScenarioName ?? 'Chat') : 'AI Chatbot Training',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Color(0xFF1C1B1B)),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (_selectedScenarioId != null && !_sessionEnded)
            GestureDetector(
              onTap: _endSession,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: const Color(0xFF1C1B1B), borderRadius: BorderRadius.circular(8)),
                child: const Text('End', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ),
          if (_selectedScenarioId != null)
            IconButton(icon: const Icon(Icons.refresh, color: Color(0xFF444748)), tooltip: 'Reset', onPressed: resetSession),
        ],
      ),
    );
  }

  Widget _buildScenarioList() {
    if (_loadingScenarios) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF1C1B1B)));
    }
    if (_scenarioError != null && _scenarios.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(_scenarioError!, style: const TextStyle(color: Color(0xFFBA1A1A)), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadScenarios,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1C1B1B), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Retry'),
          ),
        ]),
      );
    }
    if (_scenarios.isEmpty) {
      return const Center(child: Text('Tidak ada skenario tersedia.', style: TextStyle(color: Color(0xFF444748))));
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Select a Scenario', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: Color(0xFF1C1B1B), letterSpacing: -0.24)),
          const SizedBox(height: 8),
          const Text('Choose a training scenario to practice your customer service skills.', style: TextStyle(fontSize: 14, color: Color(0xFF444748))),
          const SizedBox(height: 20),
          // Quiz mode button
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, AppRoutes.quiz),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1B1B),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                children: [
                  Icon(Icons.quiz_outlined, color: Colors.white, size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Mode Quiz', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                        SizedBox(height: 2),
                        Text('Uji kemampuan customer service kamu!', style: TextStyle(fontSize: 12, color: Color(0xFF858383))),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: Color(0xFF858383)),
                ],
              ),
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _scenarios.map((scenario) {
              return GestureDetector(
                onTap: () => _selectScenario(scenario),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFC4C7C7).withOpacity(0.2)),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 4))],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(color: const Color(0xFFF1EDEC), borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.chat_bubble_outline, size: 20, color: Color(0xFF1C1B1B)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(scenario['name'] as String? ?? 'Skenario', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1C1B1B))),
                          if (scenario['description'] != null) ...[
                            const SizedBox(height: 2),
                            Text(scenario['description'] as String, style: const TextStyle(fontSize: 12, color: Color(0xFF444748)), maxLines: 2, overflow: TextOverflow.ellipsis),
                          ],
                        ]),
                      ),
                      const Icon(Icons.chevron_right, color: Color(0xFFC4C7C7)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  CharacterMood _determineMood() {
    if (_sendingMessage) return CharacterMood.talking;

    // Find the last AI message
    final lastAiMessage = _messages.lastWhere(
      (m) => !m.isUser,
      orElse: () => _ChatMessage(text: '', isUser: false),
    );
    final text = lastAiMessage.text.toLowerCase();

    if (text.isEmpty) return CharacterMood.neutral;

    // Check for angry keywords (Indonesian)
    const angryKeywords = ['kesal', 'marah', 'batal', 'refund', 'buruk', 'kecewa', 'komplain', 'gagal', 'parah', 'uang kembali', 'melaporkan'];
    if (angryKeywords.any((k) => text.contains(k))) return CharacterMood.angry;

    // Check for happy keywords (Indonesian)
    const happyKeywords = ['terima kasih', 'bagus', 'sempurna', 'mantap', 'selesai', 'senang', 'puas', 'berhasil', 'hebat'];
    if (happyKeywords.any((k) => text.contains(k))) return CharacterMood.happy;

    // Check for confused keywords (Indonesian)
    const confusedKeywords = ['tidak mengerti', 'bingung', 'maksudnya', 'apa itu', 'kurang jelas', 'belum paham', 'gimana'];
    if (confusedKeywords.any((k) => text.contains(k))) return CharacterMood.confused;

    return CharacterMood.neutral;
  }

  Widget _buildChatUI() {
    final currentMood = _determineMood();
    return Column(
      children: [
        // Character avatar (fixed at top)
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: AnimatedCharacter(mood: currentMood, size: 100),
        ),
        // Chat messages + feedback (scrollable together when session ended)
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: _sessionEnded ? 80 : 16),
            itemCount: _messages.length + (_feedback != null ? 1 : 0) + (_loadingFeedback ? 1 : 0),
            itemBuilder: (context, index) {
              if (index < _messages.length) {
                return _buildChatBubble(_messages[index]);
              }
              final feedbackIndex = index - _messages.length;
              if (_loadingFeedback && feedbackIndex == 0) {
                return const Padding(padding: EdgeInsets.all(8.0), child: Center(child: CircularProgressIndicator(color: Color(0xFF1C1B1B))));
              }
              if (_feedback != null) {
                return _buildFeedbackCard();
              }
              return const SizedBox.shrink();
            },
          ),
        ),
        // Input
        if (!_sessionEnded) _buildInputArea(),
      ],
    );
  }

  Widget _buildChatBubble(_ChatMessage message) {
    final isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFF1C1B1B) : const Color(0xFFF7F3F2),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isUser ? const Radius.circular(16) : Radius.zero,
            bottomRight: isUser ? Radius.zero : const Radius.circular(16),
          ),
        ),
        child: Text(
          message.text,
          style: TextStyle(
            fontSize: 14,
            color: isUser ? Colors.white : const Color(0xFF1C1B1B),
          ),
        ),
      ),
    );
  }

  Widget _buildFeedbackCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFC4C7C7).withOpacity(0.2)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 24, height: 24,
              decoration: BoxDecoration(color: const Color(0xFFF7F3F2), borderRadius: BorderRadius.circular(6)),
              child: const Icon(Icons.star, color: Color(0xFF1C1B1B), size: 14),
            ),
            const SizedBox(width: 8),
            const Text('Session Evaluation', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF1C1B1B))),
          ]),
          const SizedBox(height: 12),
          Text(_feedback!, style: const TextStyle(fontSize: 14, color: Color(0xFF444748))),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: resetSession,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1C1B1B), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
              child: const Text('Start New Session', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 12 + (bottomInset > 0 ? 0 : 0)),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: const Color(0xFFC4C7C7).withOpacity(0.2))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(color: const Color(0xFFF7F3F2), borderRadius: BorderRadius.circular(12)),
              child: TextField(
                controller: _messageController,
                decoration: const InputDecoration(
                  hintText: 'Type your message...',
                  hintStyle: TextStyle(color: Color(0xFF858383), fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                enabled: !_sendingMessage,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _sendingMessage ? null : _sendMessage,
            child: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: const Color(0xFF1C1B1B), borderRadius: BorderRadius.circular(12)),
              child: _sendingMessage
                  ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))
                  : const Icon(Icons.send, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

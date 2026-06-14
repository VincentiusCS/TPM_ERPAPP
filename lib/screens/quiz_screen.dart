import 'package:flutter/material.dart';

import '../routes/app_routes.dart';

class _QuizQuestion {
  final String scenario;
  final String question;
  final List<String> options;
  final int correctIndex;
  final String explanation;

  const _QuizQuestion({
    required this.scenario,
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });
}

const _questions = [
  _QuizQuestion(
    scenario: 'Pelanggan menghubungi CS dan berkata:\n"Saya sudah menunggu pesanan saya selama 2 minggu, ini tidak bisa diterima!"',
    question: 'Apa respons terbaik sebagai customer service?',
    options: [
      'Maaf, itu bukan salah kami.',
      'Saya memahami kekecewaan Anda. Izinkan saya segera memeriksa status pesanan Anda.',
      'Pesanan Anda pasti sudah dikirim, coba cek lagi.',
      'Silakan hubungi bagian pengiriman langsung.',
    ],
    correctIndex: 1,
    explanation: 'Empati dulu, lalu tawarkan solusi konkret. Jangan menyalahkan atau mengalihkan tanggung jawab.',
  ),
  _QuizQuestion(
    scenario: 'Pelanggan bertanya:\n"Apakah produk ini tersedia dalam warna biru?"',
    question: 'Stok warna biru sedang kosong. Apa yang sebaiknya Anda lakukan?',
    options: [
      'Bilang "tidak ada" dan akhiri percakapan.',
      'Berbohong bahwa stok akan datang besok.',
      'Informasikan stok kosong, tawarkan alternatif warna lain, dan tawaran notifikasi saat stok tersedia.',
      'Arahkan pelanggan ke toko lain.',
    ],
    correctIndex: 2,
    explanation: 'Jujur soal stok, tapi tetap proaktif menawarkan solusi alternatif agar pelanggan tidak pergi dengan tangan kosong.',
  ),
  _QuizQuestion(
    scenario: 'Di tengah percakapan, pelanggan tiba-tiba marah:\n"Kamu tidak mengerti masalah saya sama sekali!"',
    question: 'Bagaimana cara terbaik merespons situasi ini?',
    options: [
      'Balas dengan nada defensif dan jelaskan bahwa Anda sudah benar.',
      'Diam dan tunggu pelanggan tenang sendiri.',
      'Minta maaf atas ketidaknyamanan, minta pelanggan menjelaskan ulang masalahnya dengan lebih detail.',
      'Langsung transfer ke supervisor tanpa penjelasan.',
    ],
    correctIndex: 2,
    explanation: 'De-eskalasi dengan meminta maaf, lalu beri ruang pelanggan untuk menjelaskan. Ini menunjukkan Anda benar-benar ingin membantu.',
  ),
  _QuizQuestion(
    scenario: 'Pelanggan meminta refund untuk produk yang sudah dipakai selama 3 bulan dengan alasan tidak puas.',
    question: 'Kebijakan refund hanya berlaku 30 hari. Apa respons yang tepat?',
    options: [
      'Tolak langsung tanpa penjelasan.',
      'Setujui refund agar pelanggan senang meski melanggar kebijakan.',
      'Jelaskan kebijakan refund dengan sopan, tawarkan solusi alternatif seperti diskon pembelian berikutnya atau bantuan teknis.',
      'Minta pelanggan membaca syarat dan ketentuan sendiri.',
    ],
    correctIndex: 2,
    explanation: 'Tegakkan kebijakan dengan sopan, tapi selalu sertakan solusi alternatif. Pelanggan perlu merasa tetap dihargai meski permintaannya tidak bisa dipenuhi.',
  ),
  _QuizQuestion(
    scenario: 'Pelanggan mengakhiri percakapan dengan:\n"Terima kasih, masalah saya sudah selesai."',
    question: 'Apa langkah terbaik sebelum menutup percakapan?',
    options: [
      'Langsung tutup chat.',
      'Tanyakan apakah ada hal lain yang bisa dibantu, ucapkan terima kasih, dan doakan hari yang menyenangkan.',
      'Minta pelanggan mengisi survei kepuasan terlebih dahulu.',
      'Kirim promosi produk terbaru.',
    ],
    correctIndex: 1,
    explanation: 'Penutupan yang baik meninggalkan kesan positif. Selalu pastikan tidak ada kebutuhan lain sebelum menutup percakapan.',
  ),
];

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  int _score = 0;
  int? _selectedOption;
  bool _answered = false;
  bool _finished = false;
  late AnimationController _feedbackController;
  late Animation<double> _feedbackAnimation;

  @override
  void initState() {
    super.initState();
    _feedbackController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _feedbackAnimation = CurvedAnimation(parent: _feedbackController, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  void _selectOption(int index) {
    if (_answered) return;
    setState(() {
      _selectedOption = index;
      _answered = true;
      if (index == _questions[_currentIndex].correctIndex) _score++;
    });
    _feedbackController.forward(from: 0);
  }

  void _next() {
    if (_currentIndex < _questions.length - 1) {
      setState(() {
        _currentIndex++;
        _selectedOption = null;
        _answered = false;
      });
      _feedbackController.reset();
    } else {
      setState(() { _finished = true; });
    }
  }

  void _restart() {
    setState(() {
      _currentIndex = 0;
      _score = 0;
      _selectedOption = null;
      _answered = false;
      _finished = false;
    });
    _feedbackController.reset();
  }

  String _getScoreLabel() {
    if (_score == 5) return 'Sempurna! 🏆';
    if (_score >= 4) return 'Luar Biasa! 🌟';
    if (_score >= 3) return 'Bagus! 👍';
    if (_score >= 2) return 'Cukup Baik 📚';
    return 'Perlu Belajar Lagi 💪';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF8F8),
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            Expanded(
              child: _finished ? _buildResultScreen() : _buildQuizContent(),
            ),
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
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back, color: Color(0xFF1C1B1B)),
          ),
          const SizedBox(width: 12),
          const Text('CS Quiz', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Color(0xFF1C1B1B))),
          const Spacer(),
          if (!_finished)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: const Color(0xFF1C1B1B), borderRadius: BorderRadius.circular(20)),
              child: Text(
                '${_currentIndex + 1} / ${_questions.length}',
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQuizContent() {
    final q = _questions[_currentIndex];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (_currentIndex + 1) / _questions.length,
              backgroundColor: const Color(0xFFE8E3E2),
              color: const Color(0xFF1C1B1B),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 20),
          // Score chip
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFFF7F3F2), borderRadius: BorderRadius.circular(20)),
                child: Row(children: [
                  const Icon(Icons.star, size: 14, color: Color(0xFF1C1B1B)),
                  const SizedBox(width: 4),
                  Text('Skor: $_score', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1C1B1B))),
                ]),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Scenario card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1B1B),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('SKENARIO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.8, color: Color(0xFF858383))),
                const SizedBox(height: 8),
                Text(q.scenario, style: const TextStyle(fontSize: 14, color: Colors.white, height: 1.5)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Question
          Text(q.question, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1C1B1B), height: 1.4)),
          const SizedBox(height: 16),
          // Options
          ...List.generate(q.options.length, (i) => _buildOption(i, q)),
          // Feedback
          if (_answered) ...[
            const SizedBox(height: 16),
            FadeTransition(
              opacity: _feedbackAnimation,
              child: _buildFeedback(q),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _next,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1C1B1B),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                ),
                child: Text(
                  _currentIndex < _questions.length - 1 ? 'Soal Berikutnya →' : 'Lihat Hasil',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildOption(int index, _QuizQuestion q) {
    Color bgColor = Colors.white;
    Color borderColor = const Color(0xFFC4C7C7);
    Color textColor = const Color(0xFF1C1B1B);
    Widget? trailingIcon;

    if (_answered) {
      if (index == q.correctIndex) {
        bgColor = const Color(0xFFF0FFF4);
        borderColor = const Color(0xFF2E7D32);
        textColor = const Color(0xFF2E7D32);
        trailingIcon = const Icon(Icons.check_circle, color: Color(0xFF2E7D32), size: 20);
      } else if (index == _selectedOption) {
        bgColor = const Color(0xFFFFF0F0);
        borderColor = const Color(0xFFBA1A1A);
        textColor = const Color(0xFFBA1A1A);
        trailingIcon = const Icon(Icons.cancel, color: Color(0xFFBA1A1A), size: 20);
      } else {
        bgColor = const Color(0xFFF7F3F2);
        borderColor = const Color(0xFFE8E3E2);
        textColor = const Color(0xFF858383);
      }
    }

    return GestureDetector(
      onTap: () => _selectOption(index),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor.withOpacity(0.4)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: _answered ? bgColor : const Color(0xFFF7F3F2),
                shape: BoxShape.circle,
                border: Border.all(color: borderColor.withOpacity(0.4)),
              ),
              child: Center(
                child: Text(
                  String.fromCharCode(65 + index),
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textColor),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(q.options[index], style: TextStyle(fontSize: 14, color: textColor, height: 1.4))),
            if (trailingIcon != null) ...[const SizedBox(width: 8), trailingIcon],
          ],
        ),
      ),
    );
  }

  Widget _buildFeedback(_QuizQuestion q) {
    final isCorrect = _selectedOption == q.correctIndex;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCorrect ? const Color(0xFFF0FFF4) : const Color(0xFFFFF0F0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isCorrect ? const Color(0xFF2E7D32).withOpacity(0.3) : const Color(0xFFBA1A1A).withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(isCorrect ? Icons.check_circle_outline : Icons.info_outline,
              color: isCorrect ? const Color(0xFF2E7D32) : const Color(0xFFBA1A1A), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isCorrect ? 'Benar!' : 'Kurang Tepat',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                        color: isCorrect ? const Color(0xFF2E7D32) : const Color(0xFFBA1A1A))),
                const SizedBox(height: 4),
                Text(q.explanation, style: const TextStyle(fontSize: 13, color: Color(0xFF444748), height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultScreen() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 24),
          // Score circle
          Container(
            width: 140, height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF1C1B1B),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 30, offset: const Offset(0, 10))],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('$_score/${_questions.length}',
                    style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w700, color: Colors.white)),
                const Text('SKOR', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF858383), letterSpacing: 1)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(_getScoreLabel(), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Color(0xFF1C1B1B))),
          const SizedBox(height: 8),
          Text(
            'Kamu menjawab $_score dari ${_questions.length} soal dengan benar.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: Color(0xFF444748)),
          ),
          const SizedBox(height: 32),
          // Score breakdown
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFC4C7C7).withOpacity(0.2)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 4))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('RINGKASAN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.8, color: Color(0xFF444748))),
                const SizedBox(height: 16),
                _buildScoreRow('Jawaban Benar', '$_score', const Color(0xFF2E7D32)),
                const SizedBox(height: 8),
                _buildScoreRow('Jawaban Salah', '${_questions.length - _score}', const Color(0xFFBA1A1A)),
                const SizedBox(height: 8),
                _buildScoreRow('Persentase', '${(_score / _questions.length * 100).toInt()}%', const Color(0xFF1C1B1B)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _restart,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1C1B1B),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 0,
              ),
              child: const Text('Main Lagi', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.pushReplacementNamed(context, AppRoutes.chatbot),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF1C1B1B),
                side: const BorderSide(color: Color(0xFF1C1B1B)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Kembali ke Chatbot', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, color: Color(0xFF444748))),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: valueColor)),
      ],
    );
  }
}

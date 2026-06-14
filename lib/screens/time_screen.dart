import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../utils/timezone_util.dart';
import '../widgets/app_bottom_nav.dart';

class TimeScreen extends StatefulWidget {
  const TimeScreen({super.key});

  @override
  State<TimeScreen> createState() => _TimeScreenState();
}

class _TimeScreenState extends State<TimeScreen> {
  final TextEditingController _timeController = TextEditingController();

  String _fromTz = 'WIB';
  String _toTz = 'WITA';
  TimeOfDay? _selectedTime;
  String? _resultText;
  String? _offsetText;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    TimezoneUtil.initialize();
  }

  @override
  void dispose() {
    _timeController.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
        _timeController.text = _formatTimeOfDay(picked);
        _errorMessage = null;
      });
    }
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  void _convert() {
    final timeText = _timeController.text.trim();
    if (timeText.isEmpty) {
      setState(() { _errorMessage = 'Masukkan waktu terlebih dahulu.'; _resultText = null; _offsetText = null; });
      return;
    }
    final timeParts = timeText.split(':');
    if (timeParts.length != 2) {
      setState(() { _errorMessage = 'Format waktu tidak valid. Gunakan format HH:mm.'; _resultText = null; _offsetText = null; });
      return;
    }
    final hour = int.tryParse(timeParts[0]);
    final minute = int.tryParse(timeParts[1]);
    if (hour == null || minute == null || hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      setState(() { _errorMessage = 'Format waktu tidak valid. Jam harus 00-23 dan menit harus 00-59.'; _resultText = null; _offsetText = null; });
      return;
    }
    if (_fromTz == _toTz) {
      setState(() { _errorMessage = null; _resultText = '$timeText $_toTz'; _offsetText = 'Selisih: 0 jam (zona waktu sama)'; });
      return;
    }
    try {
      final now = DateTime.now();
      final inputDateTime = DateTime(now.year, now.month, now.day, hour, minute);
      final converted = TimezoneUtil.convert(inputDateTime, _fromTz, _toTz);
      final offset = TimezoneUtil.getOffset(_fromTz, _toTz, referenceTime: inputDateTime);
      final convertedTimeStr = DateFormat('HH:mm').format(converted);
      final offsetSign = offset >= 0 ? '+' : '';
      final offsetStr = offset == offset.toInt() ? '${offset.toInt()}' : offset.toStringAsFixed(1);
      setState(() { _errorMessage = null; _resultText = '$convertedTimeStr $_toTz'; _offsetText = 'Selisih: $offsetSign$offsetStr jam'; });
    } catch (e) {
      setState(() { _errorMessage = 'Terjadi kesalahan saat konversi: ${e.toString()}'; _resultText = null; _offsetText = null; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final timezoneNames = TimezoneUtil.timezoneNames;

    return Scaffold(
      backgroundColor: const Color(0xFFFDF8F8),
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    const Text('Time Zone Converter', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: Color(0xFF1C1B1B), letterSpacing: -0.6)),
                    const SizedBox(height: 24),
                    // Conversion card
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFC4C7C7).withOpacity(0.2)),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 4))],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Time input
                          GestureDetector(
                            onTap: _pickTime,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(color: const Color(0xFFF7F3F2), borderRadius: BorderRadius.circular(12)),
                              child: Row(
                                children: [
                                  const Icon(Icons.access_time_outlined, size: 18, color: Color(0xFF444748)),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _timeController.text.isNotEmpty ? _timeController.text : 'Select time (HH:mm)',
                                      style: TextStyle(fontSize: 16, color: _timeController.text.isNotEmpty ? const Color(0xFF1C1B1B) : const Color(0xFF858383)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Source timezone
                          Container(
                            decoration: BoxDecoration(color: const Color(0xFFF7F3F2), borderRadius: BorderRadius.circular(12)),
                            child: DropdownButtonFormField<String>(
                              initialValue: _fromTz,
                              decoration: const InputDecoration(
                                labelText: 'From Timezone',
                                labelStyle: TextStyle(color: Color(0xFF444748), fontSize: 14),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              ),
                              items: timezoneNames.map((tz) => DropdownMenuItem(value: tz, child: Text('$tz (${TimezoneUtil.supportedTimezones[tz]})'))).toList(),
                              onChanged: (value) { if (value != null) setState(() { _fromTz = value; }); },
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Target timezone
                          Container(
                            decoration: BoxDecoration(color: const Color(0xFFF7F3F2), borderRadius: BorderRadius.circular(12)),
                            child: DropdownButtonFormField<String>(
                              initialValue: _toTz,
                              decoration: const InputDecoration(
                                labelText: 'To Timezone',
                                labelStyle: TextStyle(color: Color(0xFF444748), fontSize: 14),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              ),
                              items: timezoneNames.map((tz) => DropdownMenuItem(value: tz, child: Text('$tz (${TimezoneUtil.supportedTimezones[tz]})'))).toList(),
                              onChanged: (value) { if (value != null) setState(() { _toTz = value; }); },
                            ),
                          ),
                          const SizedBox(height: 20),
                          // Convert button
                          SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              onPressed: _convert,
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1C1B1B), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                              child: const Text('Convert', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Error
                    if (_errorMessage != null)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFDF8F8),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFBA1A1A).withOpacity(0.3)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.error_outline, color: Color(0xFFBA1A1A), size: 20),
                          const SizedBox(width: 12),
                          Expanded(child: Text(_errorMessage!, style: const TextStyle(color: Color(0xFFBA1A1A), fontSize: 14))),
                        ]),
                      ),
                    // Result
                    if (_resultText != null) _buildResultCard(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            const AppBottomNav(),
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
          const Text('Admin Portal', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Color(0xFF1C1B1B))),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildResultCard() {
    return Container(
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
          const Text('RESULT', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 0.6, color: Color(0xFF444748))),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Source', style: TextStyle(fontSize: 13, color: Color(0xFF444748))),
              Text('${_timeController.text} $_fromTz', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1C1B1B))),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFF7F3F2), borderRadius: BorderRadius.circular(10)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Converted', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF444748))),
                Text(_resultText!, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1C1B1B))),
              ],
            ),
          ),
          if (_offsetText != null) ...[
            const SizedBox(height: 12),
            Text(_offsetText!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF444748))),
          ],
        ],
      ),
    );
  }
}

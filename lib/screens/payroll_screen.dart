import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:provider/provider.dart';

import '../providers/payroll_provider.dart';
import '../services/push_notification_service.dart';
import '../utils/notification_helper.dart';
import '../utils/timezone_util.dart';
import '../widgets/app_bottom_nav.dart';

/// Supported currencies for payroll invoice display.
const List<Map<String, String>> _supportedCurrencies = [
  {'code': 'IDR', 'symbol': 'Rp', 'name': 'Indonesian Rupiah'},
  {'code': 'USD', 'symbol': '\$', 'name': 'US Dollar'},
  {'code': 'EUR', 'symbol': '€', 'name': 'Euro'},
  {'code': 'GBP', 'symbol': '£', 'name': 'British Pound'},
  {'code': 'JPY', 'symbol': '¥', 'name': 'Japanese Yen'},
  {'code': 'SGD', 'symbol': 'S\$', 'name': 'Singapore Dollar'},
  {'code': 'AUD', 'symbol': 'A\$', 'name': 'Australian Dollar'},
  {'code': 'CNY', 'symbol': '¥', 'name': 'Chinese Yuan'},
  {'code': 'KRW', 'symbol': '₩', 'name': 'South Korean Won'},
  {'code': 'MYR', 'symbol': 'RM', 'name': 'Malaysian Ringgit'},
  {'code': 'THB', 'symbol': '฿', 'name': 'Thai Baht'},
];

class PayrollScreen extends StatefulWidget {
  const PayrollScreen({super.key});

  @override
  State<PayrollScreen> createState() => _PayrollScreenState();
}

class _PayrollScreenState extends State<PayrollScreen> {
  DateTime? _periodStart;
  DateTime? _periodEnd;
  final TextEditingController _searchController = TextEditingController();
  final DateFormat _dateFormat = DateFormat('dd MMM yyyy');
  final NumberFormat _currencyFormat = NumberFormat.decimalPattern('id');

  // Currency and timezone selections for invoice download
  String _selectedCurrency = 'IDR';
  String _selectedTimezone = 'WIB';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatDateApi(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _selectStartDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _periodStart ?? now.subtract(const Duration(days: 30)),
      firstDate: DateTime(now.year - 2),
      lastDate: now,
    );
    if (picked != null && mounted) {
      setState(() {
        _periodStart = picked;
        if (_periodEnd != null && _periodEnd!.isBefore(picked)) {
          _periodEnd = null;
        }
      });
    }
  }

  Future<void> _selectEndDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _periodEnd ?? now,
      firstDate: _periodStart ?? DateTime(now.year - 2),
      lastDate: now,
    );
    if (picked != null && mounted) {
      setState(() {
        _periodEnd = picked;
      });
    }
  }

  Future<void> _calculatePayroll() async {
    if (_periodStart == null || _periodEnd == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih tanggal mulai dan akhir terlebih dahulu.')),
      );
      return;
    }
    final provider = context.read<PayrollProvider>();
    final search = _searchController.text.trim();
    await provider.calculate(
      periodStart: _formatDateApi(_periodStart!),
      periodEnd: _formatDateApi(_periodEnd!),
      search: search.isNotEmpty ? search : null,
    );
  }

  Future<void> _downloadReport() async {
    if (_periodStart == null || _periodEnd == null) return;
    final provider = context.read<PayrollProvider>();
    final dir = Directory.systemTemp;
    final fileName = 'laporan-payroll-${_formatDateApi(_periodStart!)}-sd-${_formatDateApi(_periodEnd!)}.pdf';
    final savePath = '${dir.path}/$fileName';
    final filePath = await provider.downloadReport(
      periodStart: _formatDateApi(_periodStart!),
      periodEnd: _formatDateApi(_periodEnd!),
      savePath: savePath,
      currency: _selectedCurrency,
      timezone: _selectedTimezone,
    );
    if (!mounted) return;
    if (filePath != null) {
      PushNotificationService.show(
        title: 'Download Berhasil',
        body: 'Laporan payroll berhasil diunduh.',
      );
      await OpenFile.open(filePath);
    } else if (provider.errorMessage != null) {
      showErrorPopup(context, 'Gagal mengunduh: ${provider.errorMessage}');
    }
  }

  Future<void> _downloadSlip(int employeeId, String employeeName) async {
    if (_periodStart == null || _periodEnd == null) return;
    final provider = context.read<PayrollProvider>();
    final dir = Directory.systemTemp;
    final fileName = 'slip-gaji-$employeeName-${_formatDateApi(_periodStart!)}-sd-${_formatDateApi(_periodEnd!)}.pdf';
    final savePath = '${dir.path}/$fileName';
    final filePath = await provider.downloadSlip(
      employeeId: employeeId,
      periodStart: _formatDateApi(_periodStart!),
      periodEnd: _formatDateApi(_periodEnd!),
      savePath: savePath,
      currency: _selectedCurrency,
      timezone: _selectedTimezone,
    );
    if (!mounted) return;
    if (filePath != null) {
      PushNotificationService.show(
        title: 'Download Berhasil',
        body: 'Slip gaji $employeeName berhasil diunduh.',
      );
      await OpenFile.open(filePath);
    } else if (provider.errorMessage != null) {
      showErrorPopup(context, 'Gagal mengunduh: ${provider.errorMessage}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PayrollProvider>();
    return Scaffold(
      backgroundColor: const Color(0xFFFDF8F8),
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    const Text('Payroll Calculation', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: Color(0xFF1C1B1B), letterSpacing: -0.6)),
                    const SizedBox(height: 24),
                    _buildPeriodSection(),
                    const SizedBox(height: 16),
                    _buildCurrencyTimezoneSection(),
                    const SizedBox(height: 16),
                    _buildSearchField(),
                    const SizedBox(height: 16),
                    _buildActionRow(provider),
                    const SizedBox(height: 24),
                    if (provider.payrollResults.isNotEmpty) ...[_buildStatsCards(provider), const SizedBox(height: 24)],
                    _buildResultsSection(provider),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            const AppBottomNav(activeIndex: 3),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Container(width: 36, height: 36, decoration: BoxDecoration(color: const Color(0xFF1C1B1B), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.person, color: Colors.white, size: 20)),
          const SizedBox(width: 12),
          const Text('Admin Portal', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Color(0xFF1C1B1B))),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildPeriodSection() {
    return Row(
      children: [
        Expanded(child: _buildDatePicker(_periodStart, 'Start Date', _selectStartDate)),
        const SizedBox(width: 12),
        Expanded(child: _buildDatePicker(_periodEnd, 'End Date', _selectEndDate)),
      ],
    );
  }

  Widget _buildDatePicker(DateTime? date, String placeholder, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(color: const Color(0xFFF7F3F2), borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_outlined, size: 16, color: Color(0xFF444748)),
            const SizedBox(width: 8),
            Expanded(child: Text(date != null ? _dateFormat.format(date) : placeholder, style: TextStyle(fontSize: 14, color: date != null ? const Color(0xFF1C1B1B) : const Color(0xFF858383)))),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrencyTimezoneSection() {
    return Row(
      children: [
        Expanded(child: _buildCurrencyDropdown()),
        const SizedBox(width: 12),
        Expanded(child: _buildTimezoneDropdown()),
      ],
    );
  }

  Widget _buildCurrencyDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(color: const Color(0xFFF7F3F2), borderRadius: BorderRadius.circular(12)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedCurrency,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, size: 20, color: Color(0xFF444748)),
          style: const TextStyle(fontSize: 14, color: Color(0xFF1C1B1B)),
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(12),
          items: _supportedCurrencies.map((c) {
            return DropdownMenuItem<String>(
              value: c['code'],
              child: Text('${c['symbol']} ${c['code']}', style: const TextStyle(fontSize: 14, color: Color(0xFF1C1B1B))),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) setState(() => _selectedCurrency = value);
          },
        ),
      ),
    );
  }

  Widget _buildTimezoneDropdown() {
    final timezones = TimezoneUtil.timezoneNames.where((tz) => tz != 'London').toList();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(color: const Color(0xFFF7F3F2), borderRadius: BorderRadius.circular(12)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedTimezone,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, size: 20, color: Color(0xFF444748)),
          style: const TextStyle(fontSize: 14, color: Color(0xFF1C1B1B)),
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(12),
          items: timezones.map((tz) {
            return DropdownMenuItem<String>(
              value: tz,
              child: Text(tz, style: const TextStyle(fontSize: 14, color: Color(0xFF1C1B1B))),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) setState(() => _selectedTimezone = value);
          },
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFFF7F3F2), borderRadius: BorderRadius.circular(12)),
      child: TextField(
        controller: _searchController,
        decoration: const InputDecoration(hintText: 'Search employee...', hintStyle: TextStyle(color: Color(0xFF858383), fontSize: 14), prefixIcon: Icon(Icons.search, color: Color(0xFF444748)), border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
      ),
    );
  }

  Widget _buildActionRow(PayrollProvider provider) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: provider.isLoading ? null : _calculatePayroll,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1C1B1B), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
              child: const Text('Calculate', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ),
          ),
        ),
        if (provider.payrollResults.isNotEmpty) ...[
          const SizedBox(width: 12),
          SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              onPressed: provider.isLoading ? null : _downloadReport,
              icon: const Icon(Icons.download_outlined, size: 18),
              label: const Text('PDF'),
              style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF1C1B1B), side: const BorderSide(color: Color(0xFFC4C7C7)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStatsCards(PayrollProvider provider) {
    final totalSalary = provider.payrollResults.fold<double>(0, (sum, p) => sum + p.totalSalary);
    final totalEmployees = provider.payrollResults.length;
    return Row(
      children: [
        Expanded(child: _buildStatCard('Total Disbursement', 'Rp${_currencyFormat.format(totalSalary)}', Icons.account_balance_wallet_outlined)),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCard('Employees', '$totalEmployees', Icons.group_outlined)),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFC4C7C7).withOpacity(0.2)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 4))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 20, color: const Color(0xFF444748)),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF444748))),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1C1B1B))),
      ]),
    );
  }

  Widget _buildResultsSection(PayrollProvider provider) {
    if (provider.isLoading) {
      return const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator(color: Color(0xFF1C1B1B))));
    }
    if (provider.errorMessage != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: const Color(0xFFFDF8F8), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFBA1A1A).withOpacity(0.3))),
        child: Row(children: [const Icon(Icons.error_outline, color: Color(0xFFBA1A1A), size: 20), const SizedBox(width: 12), Expanded(child: Text(provider.errorMessage!, style: const TextStyle(color: Color(0xFFBA1A1A), fontSize: 14)))]),
      );
    }
    if (provider.message.isNotEmpty && provider.payrollResults.isEmpty) {
      return Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(children: [const Icon(Icons.info_outline, size: 40, color: Color(0xFF444748)), const SizedBox(height: 12), Text(provider.message, style: const TextStyle(fontSize: 14, color: Color(0xFF444748)), textAlign: TextAlign.center)])));
    }
    if (provider.payrollResults.isEmpty) {
      return Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(children: [const Icon(Icons.payments_outlined, size: 40, color: Color(0xFFC4C7C7)), const SizedBox(height: 12), const Text('Select a period and tap "Calculate" to view payroll data.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF444748), fontSize: 14))])));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('RESULTS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 0.6, color: Color(0xFF444748))),
        const SizedBox(height: 12),
        ...provider.payrollResults.map((payroll) {
          final name = payroll.employeeName ?? 'Karyawan #${payroll.employeeId}';
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFC4C7C7).withOpacity(0.2)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 4))]),
            child: Row(children: [
              Container(width: 40, height: 40, decoration: BoxDecoration(color: const Color(0xFFF1EDEC), borderRadius: BorderRadius.circular(10)), child: Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1C1B1B))))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1C1B1B))), const SizedBox(height: 2), Text('${payroll.totalAttendance} days attended', style: const TextStyle(fontSize: 12, color: Color(0xFF444748)))])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text('Rp${_currencyFormat.format(payroll.totalSalary)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1C1B1B))), const SizedBox(height: 4), GestureDetector(onTap: () => _downloadSlip(payroll.employeeId, name), child: const Icon(Icons.download_outlined, size: 18, color: Color(0xFF444748)))]),
            ]),
          );
        }),
      ],
    );
  }
}


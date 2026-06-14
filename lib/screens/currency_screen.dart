import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/currency_service.dart';
import '../widgets/app_bottom_nav.dart';

class CurrencyScreen extends StatefulWidget {
  final CurrencyService currencyService;
  final int payrollId;

  const CurrencyScreen({
    super.key,
    required this.currencyService,
    this.payrollId = 1,
  });

  @override
  State<CurrencyScreen> createState() => _CurrencyScreenState();
}

class _CurrencyScreenState extends State<CurrencyScreen> {
  final TextEditingController _amountController = TextEditingController();
  final NumberFormat _currencyFormat = NumberFormat.decimalPattern('id');

  String _selectedCurrency = 'USD';
  bool _isLoading = false;
  CurrencyConversionResult? _result;
  String? _errorMessage;

  static const List<String> _supportedCurrencies = ['USD', 'EUR', 'GBP'];

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _convert() async {
    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) {
      setState(() { _errorMessage = 'Masukkan nominal IDR terlebih dahulu.'; _result = null; });
      return;
    }
    final amount = double.tryParse(amountText.replaceAll(',', ''));
    if (amount == null || amount <= 0) {
      setState(() { _errorMessage = 'Nominal IDR harus berupa angka positif.'; _result = null; });
      return;
    }
    setState(() { _isLoading = true; _errorMessage = null; _result = null; });
    try {
      final result = await widget.currencyService.convert(amountIdr: amount, targetCurrency: _selectedCurrency);
      if (mounted) setState(() { _result = result; _isLoading = false; });
    } on CurrencyConversionException catch (e) {
      if (mounted) setState(() { _errorMessage = e.message; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _errorMessage = 'Terjadi kesalahan saat melakukan konversi.'; _isLoading = false; });
    }
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    const Text('Currency Converter', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: Color(0xFF1C1B1B), letterSpacing: -0.6)),
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
                          // Amount input
                          Container(
                            decoration: BoxDecoration(color: const Color(0xFFF7F3F2), borderRadius: BorderRadius.circular(12)),
                            child: TextField(
                              controller: _amountController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: const TextStyle(fontSize: 16, color: Color(0xFF1C1B1B)),
                              decoration: const InputDecoration(
                                labelText: 'Amount (IDR)',
                                labelStyle: TextStyle(color: Color(0xFF444748), fontSize: 14),
                                prefixText: 'Rp ',
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Currency dropdown
                          Container(
                            decoration: BoxDecoration(color: const Color(0xFFF7F3F2), borderRadius: BorderRadius.circular(12)),
                            child: DropdownButtonFormField<String>(
                              initialValue: _selectedCurrency,
                              decoration: const InputDecoration(
                                labelText: 'Target Currency',
                                labelStyle: TextStyle(color: Color(0xFF444748), fontSize: 14),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              ),
                              items: _supportedCurrencies.map((currency) => DropdownMenuItem(value: currency, child: Text(currency))).toList(),
                              onChanged: (value) { if (value != null) setState(() { _selectedCurrency = value; }); },
                            ),
                          ),
                          const SizedBox(height: 20),
                          // Convert button
                          SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _convert,
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1C1B1B), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                              child: _isLoading
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Text('Convert', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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
                    if (_result != null) _buildResultCard(_result!),
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

  Widget _buildResultCard(CurrencyConversionResult result) {
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
          _buildResultRow('Amount (IDR)', 'Rp ${_currencyFormat.format(double.tryParse(_amountController.text.trim().replaceAll(',', '')) ?? 0)}'),
          const SizedBox(height: 8),
          _buildResultRow('Exchange Rate', '${result.sourceCurrency} → ${result.targetCurrency}: ${result.exchangeRate.toStringAsFixed(6)}'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFF7F3F2), borderRadius: BorderRadius.circular(10)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Converted', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF444748))),
                Text('${result.targetCurrency} ${result.convertedAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1C1B1B))),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text('Log ID: ${result.logId}', style: const TextStyle(fontSize: 11, color: Color(0xFF858383))),
        ],
      ),
    );
  }

  Widget _buildResultRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF444748))),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1C1B1B))),
      ],
    );
  }
}

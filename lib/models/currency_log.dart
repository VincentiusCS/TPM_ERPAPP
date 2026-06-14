class CurrencyLog {
  final int id;
  final int payrollId;
  final String currencyType;
  final double exchangeRate;
  final double convertedTotal;

  CurrencyLog({
    required this.id,
    required this.payrollId,
    required this.currencyType,
    required this.exchangeRate,
    required this.convertedTotal,
  });

  factory CurrencyLog.fromJson(Map<String, dynamic> json) {
    return CurrencyLog(
      id: json['id'] as int,
      payrollId: json['payroll_id'] as int,
      currencyType: json['currency_type'] as String,
      exchangeRate: double.parse(json['exchange_rate'].toString()),
      convertedTotal: double.parse(json['converted_total'].toString()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'payroll_id': payrollId,
      'currency_type': currencyType,
      'exchange_rate': exchangeRate,
      'converted_total': convertedTotal,
    };
  }
}

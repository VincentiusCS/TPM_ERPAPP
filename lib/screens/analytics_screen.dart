import 'package:flutter/material.dart';
import '../services/analytics_service.dart';
import '../widgets/app_bottom_nav.dart';

class AnalyticsScreen extends StatefulWidget {
  final AnalyticsService analyticsService;

  const AnalyticsScreen({
    super.key,
    required this.analyticsService,
  });

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;
  String? _error;

  double _averageRate = 0.0;
  Map<String, int> _distribution = {'Baik': 0, 'Cukup': 0, 'Kurang': 0};
  List<dynamic> _employees = [];
  String _algorithm = 'None';
  Map<String, dynamic> _centroids = {};

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAnalytics() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await widget.analyticsService.getPerformanceAnalytics();
      setState(() {
        _averageRate = (data['average_rate'] as num).toDouble();
        
        final dist = data['distribution'] as Map<String, dynamic>;
        _distribution = dist.map((key, value) => MapEntry(key, (value as num).toInt()));
        
        _employees = data['employees'] as List<dynamic>;
        _algorithm = data['algorithm'] as String;
        _centroids = data['centroids'] as Map<String, dynamic>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Gagal memuat analisis: $e';
        _isLoading = false;
      });
    }
  }

  int get _totalEmployees => _employees.length;

  @override
  Widget build(BuildContext context) {
    // Filter employees based on search query
    final query = _searchController.text.toLowerCase();
    final filteredEmployees = _employees.where((emp) {
      final name = (emp['employee_name'] as String).toLowerCase();
      return name.contains(query);
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFFDF8F8),
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadAnalytics,
                color: const Color(0xFF1C1B1B),
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF1C1B1B)))
                    : _error != null
                        ? _buildErrorView()
                        : CustomScrollView(
                            slivers: [
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 20),
                                      const Text(
                                        'AI Performance Analytics',
                                        style: TextStyle(
                                          fontSize: 30,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF1C1B1B),
                                          letterSpacing: -0.6,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Analisis kehadiran karyawan menggunakan K-Means Clustering.',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: const Color(0xFF444748).withOpacity(0.8),
                                        ),
                                      ),
                                      const SizedBox(height: 24),
                                      _buildCompanyAverageCard(),
                                      const SizedBox(height: 24),
                                      _buildDistributionSection(),
                                      const SizedBox(height: 24),
                                      _buildAlgorithmDetailsCard(),
                                      const SizedBox(height: 24),
                                      const Text(
                                        'DAFTAR PERFORMA STAF',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          letterSpacing: 0.6,
                                          color: Color(0xFF444748),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      _buildSearchBar(),
                                      const SizedBox(height: 16),
                                    ],
                                  ),
                                ),
                              ),
                              filteredEmployees.isEmpty
                                  ? const SliverToBoxAdapter(
                                      child: Padding(
                                        padding: EdgeInsets.symmetric(vertical: 40),
                                        child: Center(
                                          child: Text(
                                            'Tidak ada data staf yang cocok.',
                                            style: TextStyle(color: Color(0xFF444748)),
                                          ),
                                        ),
                                      ),
                                    )
                                  : SliverPadding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      sliver: SliverList(
                                        delegate: SliverChildBuilderDelegate(
                                          (context, index) {
                                            return _buildEmployeeCard(filteredEmployees[index]);
                                          },
                                          childCount: filteredEmployees.length,
                                        ),
                                      ),
                                    ),
                              const SliverToBoxAdapter(child: SizedBox(height: 80)),
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
          const Text(
            'Admin Portal',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1C1B1B),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Color(0xFFBA1A1A)),
            const SizedBox(height: 16),
            Text(
              _error ?? 'Terjadi kesalahan sistem.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFBA1A1A), fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadAnalytics,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba Lagi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1C1B1B),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompanyAverageCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1B1B),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'RATA-RATA KEHADIRAN PERUSAHAAN',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF858383),
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tingkat produktivitas absensi staf keseluruhan.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white70,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.insights, size: 14, color: Colors.greenAccent),
                      const SizedBox(width: 6),
                      Text(
                        'Total: $_totalEmployees Karyawan',
                        style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Circular gauge display
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 80,
                height: 80,
                child: CircularProgressIndicator(
                  value: _averageRate / 100.0,
                  backgroundColor: Colors.white.withOpacity(0.12),
                  color: Colors.greenAccent,
                  strokeWidth: 8,
                ),
              ),
              Text(
                '${_averageRate.toStringAsFixed(1)}%',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDistributionSection() {
    final int baikCount = _distribution['Baik'] ?? 0;
    final int cukupCount = _distribution['Cukup'] ?? 0;
    final int kurangCount = _distribution['Kurang'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFC4C7C7).withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'DISTRIBUSI KLASTER PERFORMA',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
              color: Color(0xFF444748),
            ),
          ),
          const SizedBox(height: 16),
          _buildDistributionBar('Baik (Tinggi)', baikCount, const Color(0xFF2E7D32)),
          const SizedBox(height: 14),
          _buildDistributionBar('Cukup (Sedang)', cukupCount, const Color(0xFFE65100)),
          const SizedBox(height: 14),
          _buildDistributionBar('Kurang (Rendah)', kurangCount, const Color(0xFFBA1A1A)),
        ],
      ),
    );
  }

  Widget _buildDistributionBar(String label, int count, Color color) {
    final double percentage = _totalEmployees > 0 ? count / _totalEmployees : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1C1B1B))),
            Text(
              '$count Karyawan (${(percentage * 100).toStringAsFixed(0)}%)',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percentage,
            backgroundColor: const Color(0xFFF1EDEC),
            color: color,
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  Widget _buildAlgorithmDetailsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F3F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFC4C7C7).withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.settings_suggest_outlined, size: 18, color: Color(0xFF1C1B1B)),
              const SizedBox(width: 8),
              const Text(
                'Parameter & Algoritma AI',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1C1B1B)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Metode Analisis: $_algorithm',
            style: const TextStyle(fontSize: 12, color: Color(0xFF444748), fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          const Text(
            'Titik Pusat Klaster Kehadiran (Centroids/Threshold):',
            style: TextStyle(fontSize: 11, color: Color(0xFF444748)),
          ),
          const SizedBox(height: 4),
          Row(
            children: _centroids.entries.map((entry) {
              String val = entry.value.toString();
              if (double.tryParse(val) != null) {
                val = '${double.parse(val).toStringAsFixed(1)}%';
              }
              return Container(
                margin: const EdgeInsets.only(right: 12, top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${entry.key}: $val',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF1C1B1B)),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF7F3F2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (_) => setState(() {}),
        decoration: const InputDecoration(
          hintText: 'Cari staf...',
          hintStyle: TextStyle(color: Color(0xFF858383), fontSize: 14),
          prefixIcon: Icon(Icons.search, color: Color(0xFF444748)),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildEmployeeCard(dynamic employee) {
    final double rate = (employee['attendance_rate'] as num).toDouble();
    final int shifts = (employee['total_shifts'] as num).toInt();
    final int hadir = (employee['hadir_count'] as num).toInt();
    final String label = employee['classification'] as String;

    Color badgeBgColor;
    Color badgeTextColor;

    if (label == 'Baik') {
      badgeBgColor = const Color(0xFFE8F5E9);
      badgeTextColor = const Color(0xFF2E7D32);
    } else if (label == 'Cukup') {
      badgeBgColor = const Color(0xFFFFF3E0);
      badgeTextColor = const Color(0xFFE65100);
    } else {
      badgeBgColor = const Color(0xFFFFEBEE);
      badgeTextColor = const Color(0xFFBA1A1A);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFC4C7C7).withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1EDEC),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    employee['employee_name'].isNotEmpty ? employee['employee_name'][0].toUpperCase() : '?',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1C1B1B),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  employee['employee_name'],
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1C1B1B),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeBgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: badgeTextColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Kehadiran: $hadir / $shifts shift',
                style: const TextStyle(fontSize: 12, color: Color(0xFF444748)),
              ),
              Text(
                '${rate.toStringAsFixed(1)}%',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: badgeTextColor),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: rate / 100.0,
              backgroundColor: const Color(0xFFF1EDEC),
              color: badgeTextColor,
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }
}

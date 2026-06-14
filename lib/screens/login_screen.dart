import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../models/login_step.dart';
import '../providers/auth_provider.dart';
import '../routes/app_routes.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email wajib diisi';
    }
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Format email tidak valid';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password wajib diisi';
    }
    return null;
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    final navigator = Navigator.of(context);

    final success = await authProvider.login(
      _emailController.text.trim(),
      _passwordController.text.trim(),
    );

    if (!mounted) return;

    if (success) {
      navigator.pushReplacementNamed(AppRoutes.dashboard);
    }
  }

  int _stepIndex(LoginStep step) {
    switch (step) {
      case LoginStep.credentials:
        return 0;
      case LoginStep.biometric:
        return 1;
      case LoginStep.location:
        return 2;
      case LoginStep.success:
        return 3;
      default:
        return 0;
    }
  }

  String _getButtonLabel(LoginStep step) {
    switch (step) {
      case LoginStep.idle:
        return 'Login';
      case LoginStep.credentials:
        return 'Verifying...';
      case LoginStep.biometric:
        return 'Scan Biometric';
      case LoginStep.location:
        return 'Verify Location';
      case LoginStep.success:
        return 'Proceeding...';
      case LoginStep.failed:
        return 'Retry';
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final currentStep = authProvider.currentStep;
    final activeIndex = _stepIndex(currentStep);

    return Scaffold(
      backgroundColor: const Color(0xFFFDF8F8),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 32),
                        // Header
                        const Text(
                          'Sistem Informasi KDMP',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                            letterSpacing: -0.24,
                          ),
                        ),
                        const SizedBox(height: 32),
                        // Progress bar (3 segments)
                        _buildProgressBar(currentStep, activeIndex),
                        const SizedBox(height: 8),
                        // Step labels
                        _buildStepLabels(currentStep, activeIndex),
                        const SizedBox(height: 32),
                        // Content area
                        Expanded(
                          child: _buildStepContent(currentStep, authProvider),
                        ),
                        // Action button
                        _buildActionButton(authProvider),
                        const SizedBox(height: 16),
                        // Footer
                        const Center(
                          child: Text(
                            'Presensi v2.4.0 © 2024 Administrative Portal',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0x99444748),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar(LoginStep currentStep, int activeIndex) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 4,
            decoration: BoxDecoration(
              color: activeIndex >= 0 ? Colors.black : const Color(0xFFC4C7C7),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 4,
            decoration: BoxDecoration(
              color: activeIndex >= 1 ? Colors.black : const Color(0xFFC4C7C7),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 4,
            decoration: BoxDecoration(
              color: activeIndex >= 2 ? Colors.black : const Color(0xFFC4C7C7),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStepLabels(LoginStep currentStep, int activeIndex) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Identity',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: activeIndex == 0 ? Colors.black : const Color(0x80444748),
          ),
        ),
        Text(
          'Biometric',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: activeIndex == 1 ? Colors.black : const Color(0x80444748),
          ),
        ),
        Text(
          'Location',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: activeIndex == 2 ? Colors.black : const Color(0x80444748),
          ),
        ),
      ],
    );
  }

  Widget _buildStepContent(LoginStep currentStep, AuthProvider authProvider) {
    // Show credential form for idle, credentials, or failed-at-credentials
    if (currentStep == LoginStep.idle ||
        currentStep == LoginStep.credentials ||
        (currentStep == LoginStep.failed &&
            (authProvider.errorMessage?.contains('Email') == true ||
                authProvider.errorMessage?.contains('password') == true ||
                authProvider.errorMessage?.contains('kesalahan') == true ||
                authProvider.errorMessage?.contains('Login gagal') == true))) {
      return _buildCredentialStep(authProvider);
    }

    if (currentStep == LoginStep.biometric ||
        (currentStep == LoginStep.failed &&
            (authProvider.errorMessage?.contains('biometrik') == true ||
                authProvider.errorMessage?.contains('sidik jari') == true))) {
      return _buildBiometricStep(authProvider);
    }

    if (currentStep == LoginStep.location ||
        currentStep == LoginStep.success ||
        (currentStep == LoginStep.failed &&
            (authProvider.errorMessage?.contains('lokasi') == true ||
                authProvider.errorMessage?.contains('GPS') == true ||
                authProvider.errorMessage?.contains('area') == true ||
                authProvider.errorMessage?.contains('izin') == true))) {
      return _buildLocationStep(authProvider);
    }

    return _buildCredentialStep(authProvider);
  }

  Widget _buildCredentialStep(AuthProvider authProvider) {
    return SingleChildScrollView(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Welcome back',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 24),
            // Email field
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF7F3F2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                validator: _validateEmail,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                style: const TextStyle(fontSize: 14, color: Color(0xFF1C1B1B)),
                decoration: const InputDecoration(
                  labelText: 'Email Address',
                  labelStyle: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF444748),
                  ),
                  floatingLabelStyle: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF444748),
                  ),
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Password field
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF7F3F2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                validator: _validatePassword,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                onFieldSubmitted: (_) => _handleLogin(),
                style: const TextStyle(fontSize: 14, color: Color(0xFF1C1B1B)),
                decoration: InputDecoration(
                  labelText: 'Password',
                  labelStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF444748),
                  ),
                  floatingLabelStyle: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF444748),
                  ),
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: const Color(0xFF444748),
                      size: 20,
                    ),
                    onPressed: () {
                      setState(() => _obscurePassword = !_obscurePassword);
                    },
                  ),
                ),
              ),
            ),
            // Error message for credentials
            if (authProvider.currentStep == LoginStep.failed &&
                authProvider.errorMessage != null &&
                !authProvider.errorMessage!.contains('biometrik') &&
                !authProvider.errorMessage!.contains('lokasi') &&
                !authProvider.errorMessage!.contains('GPS') &&
                !authProvider.errorMessage!.contains('area'))
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  authProvider.errorMessage!,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFBA1A1A),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBiometricStep(AuthProvider authProvider) {
    final isFailed = authProvider.currentStep == LoginStep.failed;
    final isScanning = authProvider.currentStep == LoginStep.biometric;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'Biometric Scan',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Place your finger on the sensor',
          style: TextStyle(fontSize: 14, color: Color(0xFF444748)),
        ),
        const SizedBox(height: 32),
        // Fingerprint icon with pulse rings
        SizedBox(
          width: 160,
          height: 160,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer pulse ring
              if (isScanning)
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _pulseAnimation.value,
                      child: Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.black.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              // Inner ring
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.black.withOpacity(0.1),
                    width: 1,
                  ),
                ),
              ),
              // Icon container
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: isFailed
                      ? const Color(0xFFFFDAD6)
                      : const Color(0xFFEBE7E6),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(
                  Icons.fingerprint,
                  size: 48,
                  color: isFailed
                      ? const Color(0xFFBA1A1A)
                      : Colors.black,
                ),
              ),
            ],
          ),
        ),
        // Error message
        if (isFailed && authProvider.errorMessage != null) ...[
          const SizedBox(height: 24),
          Text(
            authProvider.errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFFBA1A1A),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLocationStep(AuthProvider authProvider) {
    final isFailed = authProvider.currentStep == LoginStep.failed;
    final isChecking = authProvider.currentStep == LoginStep.location;
    final isSuccess = authProvider.currentStep == LoginStep.success;
    final address = authProvider.locationAddress;

    String statusText;
    Color dotColor;

    if (isChecking) {
      statusText = 'Calculating proximity...';
      dotColor = Colors.black;
    } else if (isSuccess) {
      statusText = address ?? 'Location Verified';
      dotColor = Colors.black;
    } else if (isFailed) {
      statusText = address ?? 'Failed: Outside Range';
      dotColor = const Color(0xFFBA1A1A);
    } else {
      statusText = 'Scanning for office signal...';
      dotColor = const Color(0xFF5D5E60);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Proximity Check',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Establishing your LBS coordinates',
          style: TextStyle(fontSize: 14, color: Color(0xFF444748)),
        ),
        const SizedBox(height: 16),
        // Map placeholder
        AspectRatio(
          aspectRatio: 4 / 3,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFE5E2E1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFC4C7C7)),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Grid pattern to simulate map
                Icon(
                  Icons.map_outlined,
                  size: 80,
                  color: Colors.black.withOpacity(0.08),
                ),
                // Dashed circle (geofence)
                Container(
                  width: 128,
                  height: 128,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.black.withOpacity(0.15),
                      width: 2,
                    ),
                  ),
                ),
                // Location pin
                const Icon(
                  Icons.location_on,
                  size: 32,
                  color: Colors.black,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Status indicator
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF1EDEC),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              // Status dot
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  statusText,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF444748),
                  ),
                ),
              ),
              if (isChecking)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.black,
                  ),
                ),
            ],
          ),
        ),
        // Error message
        if (isFailed && authProvider.errorMessage != null) ...[
          const SizedBox(height: 16),
          Text(
            authProvider.errorMessage!,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFFBA1A1A),
            ),
          ),
          if (authProvider.errorMessage ==
              'Aktifkan izin lokasi di pengaturan aplikasi')
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: GestureDetector(
                onTap: () => Geolocator.openAppSettings(),
                child: const Text(
                  'Buka Pengaturan',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.black,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildActionButton(AuthProvider authProvider) {
    final isLoading = authProvider.isLoading;
    final label = _getButtonLabel(authProvider.currentStep);

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: isLoading ? null : _handleLogin,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          disabledBackgroundColor: Colors.black.withOpacity(0.5),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 1,
        ),
        child: isLoading &&
                authProvider.currentStep != LoginStep.biometric &&
                authProvider.currentStep != LoginStep.location
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}

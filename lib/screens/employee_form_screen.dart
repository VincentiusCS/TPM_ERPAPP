import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/employee.dart';
import '../providers/employee_provider.dart';
import '../utils/notification_helper.dart';

class EmployeeFormScreen extends StatefulWidget {
  const EmployeeFormScreen({super.key});

  @override
  State<EmployeeFormScreen> createState() => _EmployeeFormScreenState();
}

class _EmployeeFormScreenState extends State<EmployeeFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  String _status = 'aktif';
  Employee? _currentEmployee;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Employee) {
        _currentEmployee = args;
        _nameController = TextEditingController(
          text: _currentEmployee!.employeeName,
        );
        _phoneController = TextEditingController(text: _currentEmployee!.phone);
        _addressController = TextEditingController(
          text: _currentEmployee!.address,
        );
        _status = _currentEmployee!.status;
      } else {
        _nameController = TextEditingController();
        _phoneController = TextEditingController();
        _addressController = TextEditingController();
      }
      context.read<EmployeeProvider>().clearErrors();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  String? _getFieldError(Map<String, List<String>> fieldErrors, String key) {
    final errors = fieldErrors[key];
    if (errors != null && errors.isNotEmpty) {
      return errors.first;
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final provider = context.read<EmployeeProvider>();
    final navigator = Navigator.of(context);

    final isEditing = _currentEmployee != null;
    final employee = Employee(
      id: _currentEmployee?.id ?? 0,
      employeeName: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      address: _addressController.text.trim(),
      status: _status,
    );

    final success = isEditing
        ? await provider.updateEmployee(employee)
        : await provider.addEmployee(employee);

    if (!mounted) return;

    if (success) {
      showSuccessPopup(
        context,
        isEditing
            ? 'Karyawan berhasil diperbarui.'
            : 'Karyawan berhasil ditambahkan.',
      );
      navigator.pop();
    } else {
      if (provider.fieldErrors.isEmpty && provider.errorMessage != null) {
        showErrorPopup(context, provider.errorMessage!);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EmployeeProvider>();
    final isEditing = _currentEmployee != null;
    final fieldErrors = provider.fieldErrors;

    return Scaffold(
      backgroundColor: const Color(0xFFFDF8F8),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              height: 64,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Color(0xFF1C1B1B)),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isEditing ? 'Edit Employee' : 'Add Employee',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1C1B1B),
                    ),
                  ),
                ],
              ),
            ),
            // Form
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 8),
                      _buildInputField(
                        controller: _nameController,
                        label: 'Nama Karyawan',
                        errorText: _getFieldError(fieldErrors, 'employee_name'),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                                ? 'Nama harus diisi'
                                : null,
                      ),
                      const SizedBox(height: 16),
                      _buildInputField(
                        controller: _phoneController,
                        label: 'Telepon',
                        errorText: _getFieldError(fieldErrors, 'phone'),
                        keyboardType: TextInputType.phone,
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                                ? 'Telepon harus diisi'
                                : null,
                      ),
                      const SizedBox(height: 16),
                      _buildInputField(
                        controller: _addressController,
                        label: 'Alamat',
                        errorText: _getFieldError(fieldErrors, 'address'),
                        maxLines: 3,
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                                ? 'Alamat harus diisi'
                                : null,
                      ),
                      const SizedBox(height: 16),
                      // Status dropdown
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F3F2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: DropdownButtonFormField<String>(
                          initialValue: _status,
                          items: const [
                            DropdownMenuItem(value: 'aktif', child: Text('Aktif')),
                            DropdownMenuItem(value: 'nonaktif', child: Text('Nonaktif')),
                          ],
                          decoration: InputDecoration(
                            labelText: 'Status',
                            labelStyle: const TextStyle(color: Color(0xFF444748), fontSize: 14),
                            errorText: _getFieldError(fieldErrors, 'status'),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _status = value;
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 32),
                      // Submit button
                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: provider.isLoading ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1C1B1B),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: provider.isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  isEditing ? 'Simpan Perubahan' : 'Tambah Karyawan',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    String? errorText,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF7F3F2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: const TextStyle(fontSize: 16, color: Color(0xFF1C1B1B)),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Color(0xFF444748), fontSize: 14),
          errorText: errorText,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        validator: validator,
      ),
    );
  }
}

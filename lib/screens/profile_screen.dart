import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/profile_image_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late TextEditingController _nameController;
  bool _isSaving = false;
  bool _isSaved = false;
  String? _imagePath;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().currentUser;
    _nameController = TextEditingController(text: user?.name ?? '');
    _loadImage();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadImage() async {
    final path = await ProfileImageService.getImagePath();
    if (mounted) setState(() { _imagePath = path; });
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) {
      await ProfileImageService.saveImagePath(picked.path);
      if (mounted) setState(() { _imagePath = picked.path; });
    }
  }

  Future<void> _saveName() async {
    if (_isSaving) return;
    setState(() { _isSaving = true; });

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.updateName(_nameController.text.trim());

    if (!mounted) return;

    if (success) {
      setState(() { _isSaving = false; _isSaved = true; });
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() { _isSaved = false; });
      });
    } else {
      setState(() { _isSaving = false; });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal menyimpan nama. Coba lagi.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final initial = (user?.name ?? 'U').substring(0, 1).toUpperCase();

    return Scaffold(
      backgroundColor: const Color(0xFFFDF8F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFDF8F8),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1C1B1B)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Profile',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF1C1B1B)),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 16),
            // Avatar with edit button
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1B1B),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFE8E3E2), width: 3),
                    ),
                    child: ClipOval(
                      child: _imagePath != null && File(_imagePath!).existsSync()
                          ? Image.file(File(_imagePath!), fit: BoxFit.cover, width: 96, height: 96)
                          : Center(
                              child: Text(
                                initial,
                                style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w600, color: Colors.white),
                              ),
                            ),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFE8E3E2)),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)],
                    ),
                    child: const Icon(Icons.camera_alt, size: 14, color: Color(0xFF1C1B1B)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Tap foto untuk mengubah',
              style: const TextStyle(fontSize: 12, color: Color(0xFF858383)),
            ),
            const SizedBox(height: 24),
            // Info card
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
                  const Text('Email', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF444748))),
                  const SizedBox(height: 4),
                  Text(user?.email ?? '-', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Color(0xFF1C1B1B))),
                  const SizedBox(height: 16),
                  const Text('NIM', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF444748))),
                  const SizedBox(height: 4),
                  Text(user?.nim ?? '-', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Color(0xFF1C1B1B))),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Editable name field
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
                  const Text('Nama', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF444748))),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF7F3F2),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    style: const TextStyle(fontSize: 16, color: Color(0xFF1C1B1B)),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveName,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1C1B1B),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                      ),
                      child: _isSaving
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(_isSaved ? 'Tersimpan ✓' : 'Simpan', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

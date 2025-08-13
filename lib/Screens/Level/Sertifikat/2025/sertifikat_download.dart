import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SertifikatDownloadScreen extends StatefulWidget {
  const SertifikatDownloadScreen({super.key});

  @override
  State<SertifikatDownloadScreen> createState() => _SertifikatDownloadScreenState();
}

class _SertifikatDownloadScreenState extends State<SertifikatDownloadScreen> {
  final _nameController = TextEditingController();
  bool _isLoading = false;
  bool _isConfirmed = false;

  Future<void> _saveNameAndDownload() async {
    final user = FirebaseAuth.instance.currentUser;
    final realName = _nameController.text.trim();
    if (user != null && realName.isNotEmpty && _isConfirmed) {
      setState(() => _isLoading = true);
      await FirebaseFirestore.instance
          .collection('user_progress')
          .doc(user.uid)
          .set({'realName': realName}, SetOptions(merge: true));
      // Simulasi proses download sertifikat (bisa diganti dengan logika download asli)
      await Future.delayed(const Duration(seconds: 2));
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sertifikat berhasil diunduh!')),
        );
        Navigator.pushReplacementNamed(context, '/menu');
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Isi nama asli dan centang konfirmasi!')),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Download Sertifikat",
          style: TextStyle(fontFamily: 'Jua', color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      backgroundColor: Colors.grey[100],
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          child: Card(
            elevation: 6,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.verified, color: Colors.green, size: 60),
                  const SizedBox(height: 12),
                  const Text(
                    "Selamat! Kamu berhak mendapatkan sertifikat.",
                    style: TextStyle(fontFamily: 'Jua', fontSize: 20, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: "Nama Asli (untuk sertifikat)",
                      labelStyle: const TextStyle(fontFamily: 'Jua'),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.blue[50],
                      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    ),
                    style: const TextStyle(fontFamily: 'Jua', fontSize: 18),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Checkbox(
                        value: _isConfirmed,
                        onChanged: (val) {
                          setState(() {
                            _isConfirmed = val ?? false;
                          });
                        },
                        activeColor: Colors.green,
                      ),
                      const Expanded(
                        child: Text(
                          "Saya menyatakan nama di atas benar dan akan tercetak di sertifikat.",
                          style: TextStyle(fontFamily: 'Jua', fontSize: 15),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _saveNameAndDownload,
                      icon: const Icon(Icons.download, size: 22),
                      label: _isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text("Download Sertifikat", style: TextStyle(fontFamily: 'Jua', fontSize: 18)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Setelah download, kamu akan kembali ke menu utama.",
                    style: TextStyle(fontFamily: 'Jua', color: Colors.grey, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
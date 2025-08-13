import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:codecraft_project/Screens/wrapper.dart';

// Halaman intro yang muncul pertama kali saat aplikasi dibuka
class IntroScreen extends StatelessWidget {
  const IntroScreen({super.key});

  // Fungsi untuk melanjutkan ke halaman utama dan menyimpan status intro sudah dilihat
  Future<void> _proceed(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenIntro', true);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const Wrapper()),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Widget utama halaman intro
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center, // Pusatkan secara horizontal
            children: [
              const SizedBox(height: 120),
              // Gambar penguin utama
              Image.asset(
                'assets/penguin1.png',
                width: MediaQuery.of(context).size.width * 0.7, // Lebar responsif
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 16),
              // Teks perkenalan
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  'Halo, namaku Snippy. Aku akan menemanimu belajar coding yayy!!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Jua',
                  ),
                ),
              ),
              const SizedBox(height: 150),
              // Tombol untuk melanjutkan ke aplikasi utama
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: Colors.grey[300],
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: const TextStyle(
                        fontFamily: 'Jua',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    onPressed: () => _proceed(context),
                    child: const Text(
                      'YAY!!!',
                      style: TextStyle(
                        fontFamily: 'Jua',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
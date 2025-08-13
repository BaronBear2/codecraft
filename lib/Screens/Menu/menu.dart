import 'package:flutter/material.dart';
import 'package:codecraft_project/services/auth.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Variabel global untuk menyimpan url foto profil user
String? _photoUrl;

// Halaman utama Welcome/Menu
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  String? _username;
  String? _uid;

  @override
  void initState() {
    super.initState();
    // Inisialisasi animasi untuk teks "Click Anywhere To Start"
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    // Ambil username dan foto profil user dari Firestore
    _fetchUsername();
  }

  // Fungsi untuk mengambil username dan foto profil user dari Firestore
  Future<void> _fetchUsername() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _uid = user.uid;
      final doc = await FirebaseFirestore.instance.collection('user_progress').doc(user.uid).get();
      String? username;
      String? photoUrl;
      if (doc.exists) {
        username = doc.data()?['username'] ?? user.uid;
        photoUrl = doc.data()?['photoUrl'];
      } else {
        username = user.uid;
      }
      if (!mounted) return;
      setState(() {
        _username = username;
        _photoUrl = photoUrl;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Setiap kembali dari halaman profil, refresh username dan foto profil
    _fetchUsername();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Scaffold utama menu
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Area utama yang bisa di-tap untuk mulai ke level selection
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                Navigator.pushNamed(context, '/level_selection');
              },
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Gambar penguin di tengah atas
                  Image.asset(
                    'assets/penguin1.png',
                    width: 300,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 16),
                  // Judul aplikasi
                  Text(
                    'CodeCraft',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Jua',
                          fontSize: 48,
                        ),
                  ),
                  const SizedBox(height: 40),
                  // Animasi teks "Click Anywhere To Start"
                  ScaleTransition(
                    scale: _scaleAnimation,
                    child: Text(
                      'Click Anywhere To Start',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontFamily: 'Jua',
                            fontSize: 10,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Tombol profil di kiri atas
          Positioned(
            top: 40,
            left: 16,
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () async {
                await Navigator.pushNamed(context, '/you');
                // Setelah kembali dari profil, refresh username dan foto profil
                _fetchUsername();
              },
              child: Row(
                children: [
                  // Avatar profil user (foto atau ikon default)
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.grey,
                    backgroundImage: _photoUrl != null ? NetworkImage(_photoUrl!) : null,
                    child: _photoUrl == null ? const Icon(Icons.person, color: Colors.white) : null,
                  ),
                  const SizedBox(width: 8),
                  // Tampilkan username user
                  Text(
                    _username ?? '',
                    style: const TextStyle(
                      color: Colors.black,
                      fontFamily: 'Jua',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Tombol sertifikat di kanan atas
          Positioned(
            top: 40,
            right: 16,
            child: IconButton(
              icon: const Icon(Icons.workspace_premium, color: Colors.amber, size: 36),
              tooltip: "Sertifikat",
              onPressed: () {
                Navigator.pushNamed(context, '/sertifikat_selection');
              },
            ),
          ),
          // Tombol laporan progress di kanan atas (sebelah kiri tombol sertifikat)
          Positioned(
            top: 40,
            right: 70,
            child: IconButton(
              icon: const Icon(Icons.bar_chart, color: Colors.blueAccent, size: 36),
              tooltip: "Laporan Progress",
              onPressed: () {
                Navigator.pushNamed(context, '/laporan_progress');
              },
            ),
          ),
        ],
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:codecraft_project/services/database.dart';
import 'package:codecraft_project/models/user_progress.dart';

// Halaman untuk menampilkan laporan progress user
class LaporanProgressScreen extends StatelessWidget {
  const LaporanProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Ambil user yang sedang login
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // Jika belum login, tampilkan pesan
      return const Scaffold(
        body: Center(child: Text("Not logged in")),
      );
    }

    // Scaffold utama laporan progress
    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan Progress', style: TextStyle(fontFamily: 'Jua', color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      backgroundColor: Colors.white,
      body: Center(
        // StreamBuilder untuk mengambil data progress user secara realtime
        child: StreamBuilder<UserProgress>(
          stream: DatabaseService(uid: user.uid).userProgress,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              // Tampilkan loading jika data belum ada
              return const CircularProgressIndicator();
            }
            final progress = snapshot.data!;
            final totalSeconds = progress.totalTimeSpent;
            // Konversi detik ke jam, menit, detik
            final hours = totalSeconds ~/ 3600;
            final minutes = (totalSeconds % 3600) ~/ 60;
            final seconds = totalSeconds % 60;
            // Ambil username dari displayName/email user jika tidak ada di progress
            final username = user.displayName ?? user.email ?? "User";
            // Tampilkan card laporan progress
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              elevation: 8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.bar_chart, size: 64, color: Colors.blueAccent),
                    const SizedBox(height: 16),
                    // Tampilkan username di atas card
                    Text(
                      username,
                      style: const TextStyle(fontFamily: 'Jua', fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const Divider(height: 32, thickness: 1.5),
                    // Tampilkan level tertinggi
                    _progressRow(Icons.star, "Highest Level", "${progress.highestLevel}"),
                    const SizedBox(height: 16),
                    // Tampilkan waktu yang dihabiskan dalam format Xh Ym Zs
                    _progressRow(Icons.timer, "Time Spent", "${hours}h ${minutes}m ${seconds}s"),
                    const SizedBox(height: 16),
                    // Tampilkan total percobaan
                    _progressRow(Icons.refresh, "Total Attempt", "${progress.totalAttempt}"),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // Widget untuk menampilkan satu baris progress (ikon, label, nilai)
  static Widget _progressRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.blueAccent, size: 28),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontFamily: 'Jua', fontSize: 18),
          ),
        ),
        Text(
          value,
          style: const TextStyle(fontFamily: 'Jua', fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SertifikatSelectionScreen extends StatefulWidget {
  const SertifikatSelectionScreen({super.key});
  @override
  State<SertifikatSelectionScreen> createState() => _SertifikatSelectionScreenState();
}

class _SertifikatSelectionScreenState extends State<SertifikatSelectionScreen> {
  bool isUnlocked = false; 
  bool showNameDialog = false;
  String realName = '';
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkUnlocked();
  }

  Future<void> _checkUnlocked() async {
    // Cek apakah user sudah menyelesaikan level tertentu (misal highestLevel > 8)
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('user_progress').doc(user.uid).get();
      final highest = doc.exists ? (doc.data()?['highestLevel'] ?? 1) : 1;
      setState(() {
        isUnlocked = highest > 5; // unlock sertifikat jika highestLevel > 8
      });
    }
  }

  Future<void> _saveNameAndGo() async {
    setState(() => isLoading = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && realName.trim().isNotEmpty) {
      await FirebaseFirestore.instance.collection('user_progress').doc(user.uid).set(
        {'realName': realName.trim()},
        SetOptions(merge: true),
      );
      setState(() => isLoading = false);
      Navigator.pop(context); 
      Navigator.pushNamed(context, '/sertifikat2025_1');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "SERTIFIKAT",
          style: TextStyle(
            color: Colors.black,
            fontFamily: 'Jua',
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: isUnlocked
                  ? () {
                      Navigator.pushNamed(context, '/sertifikat2025_1');
                    }
                  : null,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: isUnlocked ? Colors.blue[200] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(60),
                  border: Border.all(
                    color: isUnlocked ? Colors.blue : Colors.grey,
                    width: 4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (isUnlocked ? Colors.blue : Colors.grey).withOpacity(0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    isUnlocked ? Icons.star : Icons.lock,
                    color: isUnlocked ? Colors.yellow[700] : Colors.grey[600],
                    size: 64,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isUnlocked
                  ? "Klik untuk mengikuti ujian sertifikat!"
                  : "Selesaikan minimal 5 level untuk membuka sertifikat.",
              style: TextStyle(
                fontFamily: 'Jua',
                fontSize: 16,
                color: isUnlocked ? Colors.blue : Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
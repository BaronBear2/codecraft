import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:codecraft_project/services/auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

String? photoUrl;
// Halaman profil pengguna
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Variabel untuk menyimpan data pengguna
  String? username;
  String? email;
  String? role = "New";
  int highestLevel = 1;
  File? _profileImage;
  final _usernameController = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _loadUserData(); // Memuat data pengguna saat widget dibuat
  }

  // Fungsi untuk mengambil data pengguna dari Firebase Auth dan Firestore
  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    if (user != null) {
      setState(() {
        email = user.email ?? '';
        username = user.displayName ?? user.uid;
        _usernameController.text = username ?? '';
      });
      final doc = await FirebaseFirestore.instance.collection('user_progress').doc(user.uid).get();
      if (doc.exists) {
        int level = doc.data()?['highestLevel'] ?? 1;
        setState(() {
          highestLevel = level;
          photoUrl = doc.data()?['photoUrl'];
          // Menentukan role berdasarkan highestLevel
          if (level < 3) {
            role = "New";
          } else if (3 <= level && level < 8) {
            role = "Intermediate";
          } else if (7 < level && level < 11) {
            role = "Pro";
          } else {
            role = "Master";
          }
          if (doc.data()?['username'] != null) {
            username = doc.data()?['username'];
            _usernameController.text = username!;
          }
        });
      }
    }
  }

  

  // Fungsi untuk menyimpan username baru ke Firebase Auth dan Firestore
  Future<void> _saveUsername() async {
    final user = _auth.currentUser;
    final newUsername = _usernameController.text.trim();
    if (user != null && newUsername.isNotEmpty) {
      await user.updateDisplayName(newUsername);
      await FirebaseFirestore.instance
          .collection('user_progress')
          .doc(user.uid)
          .set({'username': newUsername}, SetOptions(merge: true));
      setState(() {
        username = newUsername;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Username saved!', style: TextStyle(fontFamily: 'Jua'))),
      );
    }
  }

  // Fungsi untuk memilih gambar profil dari galeri
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _profileImage = File(picked.path);
      });
      final user = _auth.currentUser;
      if (user != null) {
        // Upload to Firebase Storage
        final ref = FirebaseStorage.instance.ref().child('profile_photos/${user.uid}.jpg');
        await ref.putFile(_profileImage!);
        final url = await ref.getDownloadURL();
        // Save URL to Firestore
        await FirebaseFirestore.instance
            .collection('user_progress')
            .doc(user.uid)
            .set({'photoUrl': url}, SetOptions(merge: true));
        setState(() {}); // Refresh UI
      }
    }
  }

  // Fungsi untuk logout dari aplikasi
  Future<void> _logout() async {
    await AuthService().signOut();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Widget utama halaman profil
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Profile', style: TextStyle(fontFamily: 'Jua', color: Colors.black)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar profil dengan border dan shadow
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blueAccent.withOpacity(0.2),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                  border: Border.all(color: Colors.blueAccent, width: 3),
                ),
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.blue[50],
                      backgroundImage: _profileImage != null
                          ? FileImage(_profileImage!)
                          : (photoUrl != null ? NetworkImage(photoUrl!) : null) as ImageProvider?,
                      child: (_profileImage == null && photoUrl == null)
                          ? const Icon(Icons.person, size: 60, color: Colors.blueAccent)
                          : null,
                    ),
                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: InkWell(
                        onTap: _pickImage,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.blueAccent, width: 2),
                          ),
                          child: const Icon(Icons.edit, size: 20, color: Colors.blueAccent),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              // Form username dengan tombol simpan
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: TextFormField(
                      controller: _usernameController,
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        labelText: 'Username',
                        labelStyle: const TextStyle(fontFamily: 'Jua'),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        filled: true,
                        fillColor: Colors.blue[50],
                      ),
                      style: const TextStyle(fontFamily: 'Jua', fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _saveUsername,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                      textStyle: const TextStyle(fontFamily: 'Jua', fontWeight: FontWeight.bold),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                    ),
                    child: const Icon(Icons.save, size: 22),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Menampilkan email pengguna
              Text(
                email ?? 'No Email',
                style: const TextStyle(fontFamily: 'Jua', color: Colors.grey, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              // Menampilkan role dan level tertinggi pengguna
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Chip(
                    label: Text(
                      role ?? 'New',
                      style: const TextStyle(fontFamily: 'Jua', color: Colors.white),
                    ),
                    backgroundColor: const Color.fromARGB(255, 254, 105, 105),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  ),
                  const SizedBox(width: 12),
                  Chip(
                    avatar: const Icon(Icons.star, color: Colors.amber, size: 20),
                    label: Text(
                      'Level $highestLevel',
                      style: const TextStyle(fontFamily: 'Jua', fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    backgroundColor: Colors.yellow[100],
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Garis pembatas
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Divider(
                  color: Colors.blue[100],
                  thickness: 2,
                  indent: 40,
                  endIndent: 40,
                ),
              ),
              // Tombol untuk ganti password
              ListTile(
                leading: const Icon(Icons.lock_reset, color: Colors.blueAccent),
                title: const Text('Change Password', style: TextStyle(fontFamily: 'Jua', fontWeight: FontWeight.bold)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.blueAccent),
                onTap: () {
                  Navigator.of(context).pushNamed('/change_password');
                },
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                tileColor: Colors.blue[50],
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              ),
              const SizedBox(height: 12),
              // Tombol logout
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text('Logout', style: TextStyle(fontFamily: 'Jua', fontWeight: FontWeight.bold)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.red),
                onTap: _logout,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                tileColor: Colors.red[50],
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              ),
              const SizedBox(height: 32),
              // Informasi aplikasi
              Text(
                "CodeCraft v1.0.0",
                style: TextStyle(fontFamily: 'Jua', color: Colors.grey[400], fontSize: 14),
              ),
              const SizedBox(height: 8),
              const Text(
                "",
                style: TextStyle(fontFamily: 'Jua', color: Colors.grey, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
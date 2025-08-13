// register.dart
import 'package:flutter/material.dart';
import 'package:codecraft_project/services/auth.dart';

class Register extends StatefulWidget {
  final VoidCallback toggleView;
  const Register({super.key, required this.toggleView});

  @override
  State<Register> createState() => _RegisterState();
}

class _RegisterState extends State<Register> {
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  final _formKey = GlobalKey<FormState>();
  String email = '';
  String password = '';
  String confirmPassword = '';
  String error = '';

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      setState(() {});
      final result = await AuthService().registerWithAnEmailAndPassword(email, password);
      if (result == null) {
        setState(() {
          error = "Registration failed";
        });
      }
      // REMOVE navigation to WelcomeScreen here!
      // The Wrapper will handle navigation based on auth state.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 64.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "REGISTER",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                fontFamily: 'Jua',
              ),
            ),
            const SizedBox(height: 32),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Email',
                    ),
                    validator: (val) {
                      if (val == null || val.isEmpty) return 'Enter an email';
                      if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(val)) {
                        return 'Enter a valid email';
                      }
                      return null;
                    },
                    onChanged: (val) => email = val,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      hintText: 'Password',
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    validator: (val) {
                      if (val == null || val.isEmpty) return 'Enter a password';
                      if (val.length < 6) return 'Password must be at least 6 characters';
                      if (!RegExp(r'^(?=.*[A-Za-z])(?=.*\d)[A-Za-z\d]+$').hasMatch(val)) {
                        return 'Password must contain letters and numbers';
                      }
                      return null;
                    },
                    onChanged: (val) => password = val,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    obscureText: _obscureConfirm,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      hintText: 'Confirm Password',
                      suffixIcon: IconButton(
                        icon: Icon(_obscureConfirm ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                      ),
                    ),
                    validator: (val) {
                      if (val == null || val.isEmpty) return 'Confirm your password';
                      if (val != password) return 'Passwords do not match';
                      return null;
                    },
                    onChanged: (val) => confirmPassword = val,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[300],
                      minimumSize: const Size.fromHeight(48),
                      textStyle: const TextStyle(fontFamily: 'Jua'),
                    ),
                    child: const Text('Register', style: TextStyle(color: Colors.black, fontFamily: 'Jua')),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "OR",
              style: TextStyle(
                fontSize: 14,
                fontFamily: 'Jua',
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () async {
                final user = await AuthService().signInWithGoogle();
                if (user == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Google sign-in failed')),
                  );
                }
                // No need to navigate, Wrapper will handle it
              },
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                textStyle: const TextStyle(fontFamily: 'Jua'),
              ),
              child: const Text("GOOGLE", style: TextStyle(fontFamily: 'Jua')),
            ),
            const SizedBox(height: 20),
            Image.asset('assets/penguin3.png', height: 100),
            const SizedBox(height: 10),
            const Text(
              "Daftar untuk mulai menggunakan CodeCraft!",
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Jua'),
            ),
            const SizedBox(height: 8),
            const Opacity(
              opacity: 0.5,
              child: Text(
                'Sudah punya akun?',
                style: TextStyle(
                  fontFamily: 'Jua', // <-- add this
                ),
              ),
            ),
            const SizedBox(height: 4),
            ElevatedButton(
              onPressed: widget.toggleView,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[300],
                minimumSize: const Size(100, 36),
                textStyle: const TextStyle(fontFamily: 'Jua'),
              ),
              child: const Text('login', style: TextStyle(color: Colors.black, fontFamily: 'Jua')),
            ),
          ],
        ),
      ),
    );
  }
}

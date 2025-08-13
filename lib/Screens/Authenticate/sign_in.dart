import 'package:flutter/material.dart';
import 'package:codecraft_project/services/auth.dart';

class SignIn extends StatefulWidget {
  final VoidCallback toggleView; // <-- changed from onToggle to toggleView
  const SignIn({super.key, required this.toggleView}); // <-- changed

  @override
  State<SignIn> createState() => _SignInState();
}

class _SignInState extends State<SignIn> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _obscurePassword = true;

  String email = '';
  String password = '';
  String error = '';

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      final result = await AuthService().signInWithAnEmailAndPassword(email, password);
      setState(() => _isLoading = false);
      if (result == null) {
        setState(() {
          error = "Email or password is wrong";
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 64.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'LOGIN',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Jua', // <-- add this
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
                          decoration: InputDecoration(
                            border: const OutlineInputBorder(),
                            hintText: 'Password',
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility : Icons.visibility_off,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                          ),
                          obscureText: _obscurePassword,
                          validator: (val) {
                            if (val == null || val.isEmpty) {
                              return 'Enter a password';
                            }
                            return null;
                          },
                          onChanged: (val) => password = val,
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[300],
                            minimumSize: const Size.fromHeight(48),
                          ),
                          child: const Text('Login', style: TextStyle(color: Colors.black)),
                        ),
                        if (error.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              error,
                              style: const TextStyle(color: Colors.red, fontFamily: 'Jua'),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'OR',
                    style: TextStyle(
                      fontSize: 14,
                      fontFamily: 'Jua', // <-- add this
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
                    'Sepertinya kamu belum login.\nBuruan login dulu!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Jua', // <-- add this
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Opacity(
                    opacity: 0.5,
                    child: Text(
                      'Tidak punya akun?',
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
                      textStyle: const TextStyle(fontFamily: 'Jua'), // <-- add this
                    ),
                    child: const Text('register', style: TextStyle(color: Colors.black, fontFamily: 'Jua')), // <-- add fontFamily
                  )
                ],
              ),
            ),
    );
  }
}
